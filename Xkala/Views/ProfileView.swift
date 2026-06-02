import SwiftUI
import SwiftData
import UIKit

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.name, order: .forward) private var profiles: [UserProfile]
    @Query(sort: \WorkoutDay.date, order: .reverse) private var workouts: [WorkoutDay]

    var body: some View {
        Group {
            if let profile = profiles.first {
                UserProfileFormContent(profile: profile, workouts: workouts)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Perfil")
        .navigationBarTitleDisplayMode(.inline)
        .xkalaScreenBackground(.calendar)
        .onAppear(perform: ensureProfileExistsIfNeeded)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { hideKeyboard() }
            }
        }
    }

    /// Si no hay ningún perfil, crea uno. Con varios perfiles existentes se usa `profiles.first`
    /// (consulta ordenada); la deduplicación queda para otra fase si hace falta.
    private func ensureProfileExistsIfNeeded() {
        let descriptor = FetchDescriptor<UserProfile>()
        guard let count = try? context.fetchCount(descriptor), count == 0 else { return }
        context.insert(UserProfile())
        try? context.save()
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Formulario

private struct UserProfileFormContent: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var profile: UserProfile
    let workouts: [WorkoutDay]
    @State private var moodRefreshDate = Date()
    @State private var showBirthDateSheet = false
    @State private var showingAvatarPicker = false
    @AppStorage("selectedAvatarKind") private var selectedAvatarKindRawValue = AvatarKind.salamander.rawValue
    @FocusState private var focusedField: ProfileField?

    /// Identificador de los campos editables de la tarjeta para `@FocusState` único.
    private enum ProfileField: Hashable {
        case name
        case height
        case weight
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    profileAvatarSection
                    profileInfoCard
                }

                InsightsView(isEmbedded: true)
                    .padding(.bottom, 24)
            }
        }
        .scrollClipDisabled(true)
        .sheet(isPresented: $showBirthDateSheet) {
            birthDateEditSheet
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                moodRefreshDate = Date()
            }
        }
    }

    private var profileAvatarMood: AvatarMood {
        let _ = moodRefreshDate
        return AvatarMoodCalculator.mood(for: workouts)
    }

    /// Mascota + halos; la tarjeta va debajo con separación para que no tape el personaje.
    private var profileAvatarSection: some View {
        let mood = profileAvatarMood
        let glowColor: Color = mood == .strong
            ? Color.yellow.opacity(0.18)
            : XkalaTheme.mint.opacity(0.08)
        let avatarDisplaySize: CGFloat = 190
        let avatarContainerSize: CGFloat = 220
        /// Glow interior escalado desde el layout anterior (132 @ contenedor 176).
        let innerGlowDiameter: CGFloat = 132 * (avatarContainerSize / 176)
        return ZStack(alignment: .topTrailing) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 120
                        )
                    )
                    .frame(width: avatarContainerSize, height: avatarContainerSize)

                Circle()
                    .fill(XkalaTheme.bg.opacity(0.55))
                    .frame(width: innerGlowDiameter, height: innerGlowDiameter)
                    .blur(radius: 22)

                Circle()
                    .fill(glowColor)
                    .frame(width: avatarContainerSize, height: avatarContainerSize)
                    .blur(radius: 20)

                ZStack(alignment: .bottom) {
                    AvatarView(size: avatarDisplaySize, mood: mood)
                        .shadow(color: .black.opacity(0.25), radius: 14, x: 0, y: 10)
                }
                .frame(width: avatarContainerSize, height: avatarContainerSize)
            }

            Button {
                showingAvatarPicker = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.primary.opacity(0.72))
                    .frame(width: 34, height: 34)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            .padding(.trailing, 8)
            .accessibilityLabel("Elegir avatar")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Avatar de perfil")
        .confirmationDialog("Elegir avatar", isPresented: $showingAvatarPicker, titleVisibility: .visible) {
            ForEach(AvatarKind.allCases) { avatar in
                Button(avatar.displayName) {
                    selectedAvatarKindRawValue = avatar.rawValue
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }

    private var profileInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ProfileEditableRow(
                title: "Nombre",
                trailingIcon: "pencil",
                trailingAccessibilityLabel: "Editar nombre",
                trailingAction: { focusedField = .name }
            ) {
                TextField("", text: $profile.name, prompt: Text("Introduce tu nombre"))
                    .multilineTextAlignment(.leading)
                    .focused($focusedField, equals: .name)
            }

            ProfileEditableRow(
                title: "Altura",
                trailingIcon: "ruler",
                trailingAccessibilityLabel: "Editar altura",
                trailingAction: { focusedField = .height }
            ) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    TextField("—", text: heightMetersBinding)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .height)
                        .fixedSize(horizontal: true, vertical: false)
                    if profile.heightCm != nil {
                        Text("m")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ProfileEditableRow(
                title: "Peso",
                trailingIcon: "scalemass",
                trailingAccessibilityLabel: "Editar peso",
                trailingAction: { focusedField = .weight }
            ) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    TextField("—", text: weightKilogramsBinding)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .weight)
                        .fixedSize(horizontal: true, vertical: false)
                    if profile.weightKg != nil {
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            ProfileInfoRow(
                title: "Nacimiento",
                value: birthDateDisplay,
                isPlaceholder: profile.birthDate == nil,
                trailingIcon: "calendar",
                accessibilityLabel: "Editar fecha de nacimiento",
                action: { showBirthDateSheet = true }
            )

            ProfileInfoRow(
                title: nil,
                value: genderDisplay,
                isPlaceholder: false,
                trailingIcon: "figure.climbing",
                accessibilityLabel: "Cambiar género",
                action: toggleGender
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .xkalaCard()
        .padding(.horizontal, 16)
    }

    private var birthDateDisplay: String {
        guard let birth = profile.birthDate else {
            return "Añadir fecha de nacimiento"
        }
        return Self.birthDateDisplayFormatter.string(from: birth)
    }

    private var genderDisplay: String {
        profile.gender == "escaladora" ? "Escaladora" : "Escalador"
    }

    private func toggleGender() {
        profile.gender = profile.gender == "escaladora" ? "escalador" : "escaladora"
    }

    private static let birthDateDisplayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    /// Altura en el campo: vacío si no hay dato; si hay, metros con 2 decimales y coma decimal (ej. 1,82).
    private var heightMetersBinding: Binding<String> {
        Binding(
            get: {
                guard let h = profile.heightCm else { return "" }
                return formatMetersForDisplay(h / 100.0)
            },
            set: { text in
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "m", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else {
                    profile.heightCm = nil
                    return
                }
                let normalized = t.replacingOccurrences(of: ",", with: ".")
                guard let meters = Double(normalized), meters > 0 else { return }
                profile.heightCm = meters * 100.0
            }
        )
    }

    /// Peso en el campo: vacío si no hay dato; si hay, kilos con 1 decimal y coma decimal (ej. 65,0).
    private var weightKilogramsBinding: Binding<String> {
        Binding(
            get: {
                guard let kg = profile.weightKg else { return "" }
                return formatKilogramsForDisplay(kg)
            },
            set: { text in
                let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "kg", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !t.isEmpty else {
                    profile.weightKg = nil
                    return
                }
                let normalized = t.replacingOccurrences(of: ",", with: ".")
                guard let kg = Double(normalized), kg > 0 else { return }
                profile.weightKg = kg
            }
        )
    }

    private func formatMetersForDisplay(_ meters: Double) -> String {
        String(format: "%.2f", meters).replacingOccurrences(of: ".", with: ",")
    }

    private func formatKilogramsForDisplay(_ kg: Double) -> String {
        String(format: "%.1f", kg).replacingOccurrences(of: ".", with: ",")
    }

    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { profile.birthDate ?? Date() },
            set: { profile.birthDate = $0 }
        )
    }

    private var birthDateEditSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                DatePicker(
                    "",
                    selection: birthDateBinding,
                    displayedComponents: [.date]
                )
                .labelsHidden()
                .datePickerStyle(.graphical)

                Button("Quitar fecha de nacimiento") {
                    profile.birthDate = nil
                }
                .foregroundStyle(.secondary)
                .disabled(profile.birthDate == nil)

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Fecha de nacimiento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { showBirthDateSheet = false }
                }
            }
        }
    }
}

// MARK: - Filas de la tarjeta

/// Fila editable: `Label:` a la izquierda + contenido (TextField + unidad) a la derecha.
/// Acepta opcionalmente un icono trailing tappable, alineado igual que `ProfileInfoRow`.
private struct ProfileEditableRow<Content: View>: View {
    let title: String
    let trailingIcon: String?
    let trailingAccessibilityLabel: String?
    let trailingAction: (() -> Void)?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        trailingIcon: String? = nil,
        trailingAccessibilityLabel: String? = nil,
        trailingAction: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.trailingIcon = trailingIcon
        self.trailingAccessibilityLabel = trailingAccessibilityLabel
        self.trailingAction = trailingAction
        self.content = content
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(title):")
                .foregroundStyle(.secondary)
            content()
            Spacer(minLength: 0)
            if let trailingIcon, let trailingAction {
                Button(action: trailingAction) {
                    Image(systemName: trailingIcon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(XkalaTheme.accent)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(trailingAccessibilityLabel ?? "Editar")
            }
        }
    }
}

/// Fila informativa con valor formateado y un icono trailing tappable.
/// Si `title` es nil, se muestra solo el valor (ej. "Escalador" / "Escaladora").
private struct ProfileInfoRow: View {
    let title: String?
    let value: String
    let isPlaceholder: Bool
    let trailingIcon: String
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            if let title {
                Text("\(title):")
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .foregroundStyle(isPlaceholder ? Color.secondary : Color.primary)
            Spacer(minLength: 0)
            Button(action: action) {
                Image(systemName: trailingIcon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(XkalaTheme.accent)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel)
        }
    }
}
