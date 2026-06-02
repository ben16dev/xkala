import SwiftUI
import SwiftData

/// Campos de planificación / cierre de sesión (objetivo, RPE, sensaciones).
struct WorkoutSessionPlanningSection: View {
    @Environment(\.modelContext) private var context
    @Bindable var workout: WorkoutDay
    var showsTrainingObjective: Bool = true

    @State private var suggestedMethod: TrainingMethod?
    @State private var showSuggestion = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            durationRow

            optionalScaleRow(
                title: "¿Cómo de dura fue la sesión?",
                subtitle: "RPE 1–10",
                value: optionalIntBinding(\.rpe)
            )

            if showsTrainingObjective {
                trainingMethodPicker
            }

            optionalScaleRow(
                title: "Fatiga percibida",
                subtitle: "1–10",
                value: optionalIntBinding(\.perceivedFatigue)
            )

            optionalScaleRow(
                title: "Sensación de dedos",
                subtitle: "1–10 · 10 = dedos perfectos, sin molestias",
                value: optionalIntBinding(\.fingerSensation)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Notas")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextField("Opcional", text: painNotesBinding, axis: .vertical)
                    .lineLimit(2...4)
            }

            if let load = workout.sessionLoad {
                HStack {
                    Text("Carga de sesión")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(load)")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            workout.normalizePlanningScalars()
            if showsTrainingObjective {
                refreshSuggestion()
            }
            save()
        }
        .onChange(of: workout.entries.count) { _, _ in
            guard showsTrainingObjective else { return }
            refreshSuggestion()
        }
        .onChange(of: workout.trainingMethodRawValue) { _, _ in
            if workout.trainingMethod != nil {
                showSuggestion = false
            }
        }
    }

    // MARK: - Duración

    private var durationRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Duración")
                    .font(.subheadline)
                Text("Desde la sesión · minutos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(durationDisplayText)
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(durationDisplayText == "—" ? .secondary : .primary)
        }
        .onAppear {
            workout.syncDurationMinutesFromSessionTimer()
        }
    }

    private var durationDisplayText: String {
        guard let minutes = workout.effectiveDurationMinutes else { return "—" }
        return "\(minutes)"
    }

    // MARK: - Objetivo

    private var methodGridColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 8),
            GridItem(.flexible(), spacing: 8),
        ]
    }

    private var trainingMethodPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Objetivo")
                .font(.subheadline.weight(.semibold))

            if showSuggestion,
               workout.trainingMethod == nil,
               let suggested = suggestedMethod {
                suggestionBanner(suggested)
            }

            LazyVGrid(columns: methodGridColumns, spacing: 8) {
                ForEach(TrainingMethod.allCases) { method in
                    methodCard(method)
                }
            }

            if let selected = workout.trainingMethod {
                Text(selected.helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func suggestionBanner(_ method: TrainingMethod) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sugerencia")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(method.displayName)
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            Button("Usar") {
                workout.trainingMethod = method
                showSuggestion = false
                save()
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(.plain)
            .foregroundStyle(XkalaTheme.accent)

            Button {
                showSuggestion = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(XkalaTheme.card.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func methodCard(_ method: TrainingMethod) -> some View {
        let isSelected = workout.trainingMethod == method
        return Button {
            if isSelected {
                workout.trainingMethod = nil
                showSuggestion = suggestedMethod != nil
            } else {
                workout.trainingMethod = method
                showSuggestion = false
            }
            save()
        } label: {
            Text(method.displayName)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? XkalaTheme.accent : XkalaTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isSelected ? Color.clear : XkalaTheme.stroke, lineWidth: 1)
                )
                .foregroundStyle(isSelected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bindings

    private func optionalIntBinding(
        _ keyPath: ReferenceWritableKeyPath<WorkoutDay, Int?>,
        upperBound: Int = 10
    ) -> Binding<Int?> {
        Binding(
            get: { workout[keyPath: keyPath] },
            set: { newValue in
                if let v = newValue {
                    workout[keyPath: keyPath] = min(max(v, 1), upperBound)
                } else {
                    workout[keyPath: keyPath] = nil
                }
                save()
            }
        )
    }

    private var painNotesBinding: Binding<String> {
        Binding(
            get: { workout.painNotes ?? "" },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespacesAndNewlines)
                workout.painNotes = trimmed.isEmpty ? nil : trimmed
                save()
            }
        )
    }

    private func optionalScaleRow(title: String, subtitle: String, value: Binding<Int?>) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SessionScaleControl(
                value: value,
                range: 1...10,
                step: 1,
                placeholder: "—"
            )
        }
    }

    private func refreshSuggestion() {
        suggestedMethod = TrainingGoalSuggester.suggest(for: workout)
        if workout.trainingMethod != nil {
            showSuggestion = false
        }
    }

    private func save() {
        try? context.save()
    }
}

// MARK: - Control numérico compacto

private struct SessionScaleControl: View {
    @Binding var value: Int?
    let range: ClosedRange<Int>
    let step: Int
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Button {
                adjust(by: -step)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(canDecrement ? XkalaTheme.accent : .secondary.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(!canDecrement)

            Text(displayText)
                .font(.body.weight(.semibold).monospacedDigit())
                .frame(minWidth: 36)

            Button {
                adjust(by: step)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(canIncrement ? XkalaTheme.accent : .secondary.opacity(0.35))
            }
            .buttonStyle(.plain)
            .disabled(!canIncrement)
        }
    }

    private var displayText: String {
        guard let value else { return placeholder }
        return "\(value)"
    }

    private var canDecrement: Bool {
        guard let value else { return true }
        return value - step >= range.lowerBound
    }

    private var canIncrement: Bool {
        guard let value else { return true }
        return value + step <= range.upperBound
    }

    private func adjust(by delta: Int) {
        if let current = value {
            let next = min(max(current + delta, range.lowerBound), range.upperBound)
            value = next
        } else {
            let seed = delta > 0 ? range.lowerBound : range.upperBound
            value = seed
        }
    }
}
