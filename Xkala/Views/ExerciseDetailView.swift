import SwiftUI
import SwiftData
import UIKit

struct ExerciseDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var entry: WorkoutEntry

    @Query(sort: \WorkoutDay.date, order: .reverse) private var workouts: [WorkoutDay]

    @State private var completionPulse = false

    var body: some View {
        let progressSnapshot = ExerciseProgressCalculator.snapshot(for: entry.exercise, in: workouts)
        let basicStats = ExerciseProgressCalculator.basicStats(for: entry.exercise, in: workouts)

        List {
            if !entry.exercise.notes.isEmpty {
                Section("Cómo se hace") {
                    Text(entry.exercise.notes)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .xkalaCard()
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            Section("Estado") {
                VStack(spacing: 12) {
                    Toggle(
                        "Ejercicio completado",
                        isOn: Binding(
                            get: { entry.isDone },
                            set: { newValue in
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                                    entry.isDone = newValue
                                    if newValue { triggerCompletionFeedback() }
                                }
                            }
                        )
                    )

                    if entry.isDone {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(XkalaTheme.mint)
                            Text("Completado")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .scaleEffect(completionPulse ? 1.03 : 1.0)
                        .opacity(completionPulse ? 1.0 : 0.92)
                        .onAppear {
                            completionPulse = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    completionPulse = false
                                }
                            }
                        }
                    }

                    if !entry.isBlock && !entry.isTraverse {
                        IntControlRow(
                            title: "Intensidad",
                            value: $entry.intensity,
                            range: 1...3,
                            step: 1
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .xkalaCard()
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Registro") {
                VStack(spacing: 12) {
                    if entry.isBlock {
                        BlockEntryEditorView(entry: entry)
                    } else if entry.isTraverse {
                        TraverseEntryEditorView(entry: entry)
                    } else {
                        if entry.sets.isEmpty {
                            Text("Creando registro…")
                                .foregroundStyle(.secondary)
                                .onAppear { ensureAtLeastOneSet() }
                        }

                        if isVuelta {
                            IntControlRow(
                                title: "Nº vueltas",
                                value: Binding(
                                    get: { entry.sets.first?.reps ?? 2 },
                                    set: { newValue in
                                        ensureSingleSetForVuelta()
                                        entry.sets.first?.reps = newValue
                                        entry.sets.first?.seconds = nil
                                        entry.sets.first?.loadKg = nil
                                    }
                                ),
                                range: 0...20,
                                step: 1
                            )
                        } else {
                            IntControlRow(
                                title: "Series",
                                value: Binding(
                                    get: { max(entry.sets.count, 1) },
                                    set: { newCount in
                                        resizeSets(to: max(newCount, 1))
                                    }
                                ),
                                range: 1...30,
                                step: 1
                            )

                            if entry.exercise.modeEnum == .reps {
                                IntControlRow(
                                    title: repsTitle,
                                    value: Binding(
                                        get: { entry.sets.first?.reps ?? 0 },
                                        set: { newValue in
                                            applyRepsToAll(newValue)
                                        }
                                    ),
                                    range: 0...200,
                                    step: 1
                                )
                            } else {
                                TimeControlRow(
                                    title: "Tiempo",
                                    seconds: Binding(
                                        get: { entry.sets.first?.seconds ?? 0 },
                                        set: { newValue in
                                            applySecondsToAll(newValue)
                                        }
                                    ),
                                    range: 0...3600,
                                    stepSeconds: 5
                                )
                            }

                            if entry.exercise.loadAllowed {
                                DoubleControlRow(
                                    title: "Carga",
                                    suffix: "kg",
                                    value: Binding(
                                        get: { entry.sets.first?.loadKg ?? 0 },
                                        set: { newValue in
                                            applyLoadToAll(newValue)
                                        }
                                    ),
                                    range: -50...150,
                                    step: 0.5,
                                    decimals: 1
                                )
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .xkalaCard()
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Estadísticas") {
                ExerciseBasicStatsSectionView(snapshot: basicStats)
            }

            Section("Progreso") {
                ExerciseProgressSectionView(
                    snapshot: progressSnapshot
                )
            }

            Section("Notas") {
                TextField("Notas del ejercicio…", text: $entry.entryNotes, axis: .vertical)
                    .lineLimit(3...8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .xkalaCard()
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .navigationTitle(entry.exercise.name)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("OK") { hideKeyboard() }
            }
        }
        .onAppear {
            ensureAtLeastOneSet()
            normalizeSetsToExerciseRules()
            if entry.isBlock || entry.isTraverse {
                ensureSingleSetForClimb()
            }
            if isVuelta { ensureSingleSetForVuelta() }
        }
        .onChange(of: entry.isDone) { _, newValue in
            if newValue { triggerCompletionFeedback() }
        }
    }

    // MARK: - Animación + Haptic

    private func triggerCompletionFeedback() {
        completionPulse = true
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.25)) {
                completionPulse = false
            }
        }
    }

    // MARK: - Caso especial "Vuelta"

    private var isVuelta: Bool {
        entry.exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .contains("vuelta")
    }

    private func ensureSingleSetForVuelta() {
        ensureAtLeastOneSet()

        while entry.sets.count > 1 {
            if let last = entry.sets.last {
                context.delete(last)
                entry.sets.removeLast()
            } else {
                break
            }
        }

        entry.sets.first?.seconds = nil
        entry.sets.first?.loadKg = nil

        if entry.sets.first?.reps == nil {
            entry.sets.first?.reps = 2
        }
    }

    private func ensureSingleSetForClimb() {
        ensureAtLeastOneSet()

        while entry.sets.count > 1 {
            if let last = entry.sets.last {
                context.delete(last)
                entry.sets.removeLast()
            } else {
                break
            }
        }

        entry.sets.first?.seconds = nil
        entry.sets.first?.loadKg = nil
    }

    // MARK: - Texto

    private var repsTitle: String {
        let name = entry.exercise.name.lowercased()
        let cat = entry.exercise.category.lowercased()
        if cat.contains("campus") || name.contains("campus") {
            return "Repeticiones"
        }
        return "Reps"
    }

    // MARK: - Bloques / Travesías editors

    private struct BlockEntryEditorView: View {
        @Bindable var entry: WorkoutEntry

        private var attemptsBinding: Binding<Int> {
            Binding(
                get: { entry.sets.first?.reps ?? 0 },
                set: { newValue in
                    if entry.sets.isEmpty { entry.sets.append(SetRecord.make(for: entry.exercise)) }
                    entry.sets.first?.reps = newValue
                    entry.sets.first?.seconds = nil
                    entry.sets.first?.loadKg = nil
                }
            )
        }

        private var identifierBinding: Binding<String> {
            Binding(
                get: { entry.climbIdentifier ?? "" },
                set: { newValue in
                    let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    entry.climbIdentifier = trimmed.isEmpty ? nil : trimmed
                }
            )
        }

        private let gradeOptions: [(String, Color)] = [
            ("green", .green),
            ("yellow", .yellow),
            ("orange", .orange),
            ("purple", .purple)
        ]

        var body: some View {
            VStack(spacing: 12) {
                TextField("Identificador", text: identifierBinding)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled(true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 14) {
                    ForEach(gradeOptions.indices, id: \.self) { idx in
                        let option = gradeOptions[idx]
                        let isSelected = entry.climbGradeColor == option.0
                        Button {
                            entry.climbGradeColor = option.0
                        } label: {
                            Circle()
                                .fill(option.1)
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if isSelected {
                                        Circle().stroke(Color.primary, lineWidth: 2)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }

                IntControlRow(
                    title: "Intentos",
                    value: attemptsBinding,
                    range: 0...200,
                    step: 1
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private struct TraverseEntryEditorView: View {
        @Bindable var entry: WorkoutEntry

        private var attemptsBinding: Binding<Int> {
            Binding(
                get: { entry.sets.first?.reps ?? 0 },
                set: { newValue in
                    if entry.sets.isEmpty { entry.sets.append(SetRecord.make(for: entry.exercise)) }
                    entry.sets.first?.reps = newValue
                    entry.sets.first?.seconds = nil
                    entry.sets.first?.loadKg = nil
                }
            )
        }

        private var identifierBinding: Binding<String> {
            Binding(
                get: { entry.climbIdentifier ?? "" },
                set: { newValue in
                    let upper = newValue.uppercased()
                    let firstLetter = upper.unicodeScalars.first(where: { scalar in
                        let v = scalar.value
                        return v >= 65 && v <= 90 // A-Z
                    })

                    if let firstLetter {
                        entry.climbIdentifier = String(UnicodeScalar(firstLetter.value)!)
                    } else {
                        entry.climbIdentifier = nil
                    }
                }
            )
        }

        var body: some View {
            VStack(spacing: 12) {
                TextField("Letra", text: identifierBinding)
                    .keyboardType(.alphabet)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.characters)
                    .frame(maxWidth: .infinity, alignment: .leading)

                IntControlRow(
                    title: "Intentos",
                    value: attemptsBinding,
                    range: 0...200,
                    step: 1
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Lógica de sets (uniforme)

    private func ensureAtLeastOneSet() {
        if entry.sets.isEmpty {
            entry.sets.append(SetRecord.make(for: entry.exercise))
        }
    }

    private func resizeSets(to targetCount: Int) {
        ensureAtLeastOneSet()

        let current = entry.sets.count
        guard targetCount != current else { return }

        if targetCount > current {
            let prototype = entry.sets.first ?? SetRecord.make(for: entry.exercise)
            let extra = targetCount - current
            for _ in 0..<extra {
                entry.sets.append(cloneSet(prototype))
            }
        } else {
            let removeCount = current - targetCount
            guard removeCount > 0 else { return }
            for _ in 0..<removeCount {
                if let last = entry.sets.last {
                    context.delete(last)
                    entry.sets.removeLast()
                }
            }
        }

        normalizeSetsToExerciseRules()
    }

    private func applyRepsToAll(_ reps: Int) {
        ensureAtLeastOneSet()
        for s in entry.sets {
            s.reps = reps
            s.seconds = nil
        }
        if !entry.exercise.loadAllowed {
            for s in entry.sets { s.loadKg = nil }
        }
    }

    private func applySecondsToAll(_ seconds: Int) {
        ensureAtLeastOneSet()
        for s in entry.sets {
            s.seconds = seconds
            s.reps = nil
        }
        if !entry.exercise.loadAllowed {
            for s in entry.sets { s.loadKg = nil }
        }
    }

    private func applyLoadToAll(_ load: Double) {
        ensureAtLeastOneSet()
        guard entry.exercise.loadAllowed else {
            for s in entry.sets { s.loadKg = nil }
            return
        }
        for s in entry.sets {
            s.loadKg = load
        }
    }

    private func normalizeSetsToExerciseRules() {
        ensureAtLeastOneSet()

        if entry.exercise.modeEnum == .reps {
            for s in entry.sets { s.seconds = nil }
        } else {
            for s in entry.sets { s.reps = nil }
        }

        if !entry.exercise.loadAllowed {
            for s in entry.sets { s.loadKg = nil }
        }
    }

    private func cloneSet(_ set: SetRecord) -> SetRecord {
        SetRecord(
            reps: set.reps,
            seconds: set.seconds,
            loadKg: set.loadKg
        )
    }

    // MARK: - Keyboard

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}

// MARK: - Controles

private struct IntControlRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()

            EditableControlPill(
                text: Binding(
                    get: { text.isEmpty ? "\(value)" : text },
                    set: { text = $0 }
                ),
                suffix: nil,
                keyboard: .numberPad,
                canDecrement: value - step >= range.lowerBound,
                canIncrement: value + step <= range.upperBound,
                decrement: { value = max(value - step, range.lowerBound) },
                increment: { value = min(value + step, range.upperBound) },
                onCommit: {
                    let digits = text.filter { $0.isNumber || $0 == "-" }
                    let parsed = Int(digits) ?? value
                    value = min(max(parsed, range.lowerBound), range.upperBound)
                    text = ""
                },
                focused: $focused
            )
        }
    }
}

private struct DoubleControlRow: View {
    let title: String
    let suffix: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let decimals: Int

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()

            let formatted = String(format: "%.\(decimals)f", value)

            EditableControlPill(
                text: Binding(
                    get: { text.isEmpty ? formatted : text },
                    set: { text = $0 }
                ),
                suffix: suffix,
                keyboard: .decimalPad,
                canDecrement: value - step >= range.lowerBound - 0.0001,
                canIncrement: value + step <= range.upperBound + 0.0001,
                decrement: { value = max(value - step, range.lowerBound) },
                increment: { value = min(value + step, range.upperBound) },
                onCommit: {
                    let cleaned = text
                        .replacingOccurrences(of: ",", with: ".")
                        .filter { $0.isNumber || $0 == "." || $0 == "-" }

                    let parsed = Double(cleaned) ?? value
                    value = min(max(parsed, range.lowerBound), range.upperBound)
                    text = ""
                },
                focused: $focused
            )
        }
    }
}

private struct TimeControlRow: View {
    let title: String
    @Binding var seconds: Int
    let range: ClosedRange<Int>
    let stepSeconds: Int

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer()

            let display = formatMMSS(seconds)

            EditableControlPill(
                text: Binding(
                    get: { text.isEmpty ? display : text },
                    set: { text = $0 }
                ),
                suffix: "min",
                keyboard: .numbersAndPunctuation,
                canDecrement: seconds - stepSeconds >= range.lowerBound,
                canIncrement: seconds + stepSeconds <= range.upperBound,
                decrement: { seconds = max(seconds - stepSeconds, range.lowerBound) },
                increment: { seconds = min(seconds + stepSeconds, range.upperBound) },
                onCommit: {
                    let parsed = parseMMSS(text) ?? seconds
                    seconds = min(max(parsed, range.lowerBound), range.upperBound)
                    text = ""
                },
                focused: $focused
            )
        }
    }

    private func formatMMSS(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        let m = s / 60
        let r = s % 60
        return "\(m):" + String(format: "%02d", r)
    }

    private func parseMMSS(_ input: String) -> Int? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }

        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
            guard parts.count == 2 else { return nil }
            let mStr = parts[0].filter(\.isNumber)
            let sStr = parts[1].filter(\.isNumber)
            let m = Int(mStr) ?? 0
            let s = Int(sStr) ?? 0
            return max(0, m * 60 + min(s, 59))
        }

        let digits = trimmed.filter { $0.isNumber }
        return Int(digits)
    }
}

private struct EditableControlPill: View {
    @Binding var text: String
    let suffix: String?
    let keyboard: UIKeyboardType

    let canDecrement: Bool
    let canIncrement: Bool
    let decrement: () -> Void
    let increment: () -> Void

    let onCommit: () -> Void
    @FocusState.Binding var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Button(action: decrement) {
                Image(systemName: "minus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(!canDecrement)

            HStack(spacing: 6) {
                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .focused($focused)
                    .multilineTextAlignment(.center)
                    .font(.system(.body, design: .rounded))
                    .monospacedDigit()
                    .frame(minWidth: 70)
                    .onSubmit { commitAndDismiss() }
                    .onChange(of: focused) { _, isFocused in
                        if !isFocused { onCommit() }
                    }

                if let suffix {
                    Text(suffix)
                        .foregroundStyle(.secondary)
                        .font(.system(.footnote, design: .rounded))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { focused = true }

            Button(action: increment) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.borderless)
            .disabled(!canIncrement)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .clipShape(Capsule())
    }

    private func commitAndDismiss() {
        onCommit()
        focused = false
    }
}
