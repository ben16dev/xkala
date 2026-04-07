import SwiftUI
import SwiftData
import UIKit

struct ProfileView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \UserProfile.name, order: .forward) private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first {
                UserProfileFormContent(profile: profile)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Perfil")
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
    @Bindable var profile: UserProfile
    @State private var showBirthDateSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                photoPlaceholder
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nombre")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        TextField("", text: $profile.name, prompt: Text("Introduce tu nombre"))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Altura")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            TextField("", text: heightMetersBinding, prompt: Text("Introduce tu altura"))
                                .keyboardType(.decimalPad)
                            if profile.heightCm != nil {
                                Text("m")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    HStack(alignment: .center) {
                        Text(agePrimaryLabel)
                        Spacer()
                        Button {
                            showBirthDateSheet = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(XkalaTheme.accent)
                                .frame(width: 28, height: 28)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Editar fecha de nacimiento")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .xkalaCard()
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .sheet(isPresented: $showBirthDateSheet) {
            birthDateEditSheet
        }
    }

    private var photoPlaceholder: some View {
        ZStack {
            Circle()
                .fill(XkalaTheme.card)
                .overlay(
                    Circle()
                        .stroke(XkalaTheme.stroke, lineWidth: 1)
                )
            Text("Foto aquí")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(width: 120, height: 120)
        .frame(maxWidth: .infinity)
    }

    private var agePrimaryLabel: String {
        guard let birth = profile.birthDate else {
            return "Añadir fecha de nacimiento"
        }
        let years = Calendar.current.dateComponents([.year], from: birth, to: Date()).year ?? 0
        return "Edad: \(years) años"
    }

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

    private func formatMetersForDisplay(_ meters: Double) -> String {
        String(format: "%.2f", meters).replacingOccurrences(of: ".", with: ",")
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
