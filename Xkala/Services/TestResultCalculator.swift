import Foundation

/// Calculadora pura de resultados de ejercicios Test (sin persistencia).
///
/// Reglas de selección del mejor set por sesión:
/// - `.reps` + `loadAllowed`: prioridad → mayor carga; empate → mayor reps.
/// - `.reps` + `!loadAllowed`: mayor reps.
/// - `.seconds` + `loadAllowed`: prioridad → mayor carga; empate → mayor duración.
/// - `.seconds` + `!loadAllowed`: mayor duración.
/// - Hangboard intermitente: mayor carga → mayor rondas → mayor tiempo.
struct TestResultCalculator {

    // MARK: - Public API

    static func snapshot(for entry: WorkoutEntry, in workouts: [WorkoutDay]) -> ExerciseTestSnapshot {
        let exercise = entry.exercise
        let mode = exercise.modeEnum
        let loadAllowed = exercise.loadAllowed
        let isIntermittent = exercise.isIntermittentHangboardExercise

        let sessions = buildSessions(
            for: exercise,
            mode: mode,
            loadAllowed: loadAllowed,
            isIntermittent: isIntermittent,
            in: workouts
        )

        guard let last = sessions.first else { return .empty }

        let best = sessions.reduce(last) { currentBest, session in
            isGreater(session.bestSet, than: currentBest.bestSet,
                      mode: mode, loadAllowed: loadAllowed, isIntermittent: isIntermittent)
                ? session
                : currentBest
        }

        let previous = sessions.dropFirst().first

        let lastText = formatResult(last.bestSet, mode: mode, loadAllowed: loadAllowed, isIntermittent: isIntermittent)
        let bestText = formatResult(best.bestSet, mode: mode, loadAllowed: loadAllowed, isIntermittent: isIntermittent)
        let (deltaText, improving) = deltaInfo(
            last: last.bestSet,
            previous: previous?.bestSet,
            mode: mode,
            loadAllowed: loadAllowed,
            isIntermittent: isIntermittent
        )

        return ExerciseTestSnapshot(
            hasData: true,
            lastResultText: lastText,
            bestResultText: bestText,
            deltaText: deltaText,
            isImproving: improving
        )
    }

    // MARK: - Session building

    private struct TestSet {
        let reps: Int?
        let seconds: Int?
        let loadKg: Double?
    }

    private struct TestSession {
        let workoutDate: Date
        let bestSet: TestSet
    }

    private static func buildSessions(
        for exercise: Exercise,
        mode: ExerciseMode,
        loadAllowed: Bool,
        isIntermittent: Bool,
        in workouts: [WorkoutDay]
    ) -> [TestSession] {
        let sorted = workouts.sorted { $0.date > $1.date }
        var sessions: [TestSession] = []

        for workout in sorted {
            for entry in workout.entries {
                guard entry.isDone else { continue }
                guard isSameExercise(entry, exercise: exercise) else { continue }
                guard let best = bestSetInEntry(
                    entry, mode: mode, loadAllowed: loadAllowed, isIntermittent: isIntermittent
                ) else { continue }

                sessions.append(TestSession(workoutDate: workout.date, bestSet: best))
            }
        }

        return sessions
    }

    // MARK: - Best set selection

    private static func bestSetInEntry(
        _ entry: WorkoutEntry,
        mode: ExerciseMode,
        loadAllowed: Bool,
        isIntermittent: Bool
    ) -> TestSet? {
        var current: TestSet?
        for set in entry.sets {
            guard let candidate = validTestSet(set, mode: mode, loadAllowed: loadAllowed, isIntermittent: isIntermittent)
            else { continue }

            if let existing = current {
                if isGreater(candidate, than: existing, mode: mode, loadAllowed: loadAllowed, isIntermittent: isIntermittent) {
                    current = candidate
                }
            } else {
                current = candidate
            }
        }
        return current
    }

    private static func validTestSet(
        _ set: SetRecord,
        mode: ExerciseMode,
        loadAllowed: Bool,
        isIntermittent: Bool
    ) -> TestSet? {
        if isIntermittent {
            guard let seconds = set.seconds, seconds > 0 else { return nil }
            guard let reps = set.reps, reps > 0 else { return nil }
            return TestSet(reps: reps, seconds: seconds, loadKg: loadAllowed ? set.loadKg : nil)
        }
        switch mode {
        case .reps:
            guard let reps = set.reps, reps > 0 else { return nil }
            return TestSet(reps: reps, seconds: nil, loadKg: loadAllowed ? set.loadKg : nil)
        case .seconds:
            guard let seconds = set.seconds, seconds > 0 else { return nil }
            return TestSet(reps: nil, seconds: seconds, loadKg: loadAllowed ? set.loadKg : nil)
        }
    }

    // MARK: - Comparison

    private static func isGreater(
        _ a: TestSet,
        than b: TestSet,
        mode: ExerciseMode,
        loadAllowed: Bool,
        isIntermittent: Bool
    ) -> Bool {
        if isIntermittent {
            return compareIntermittent(a, b, loadAllowed: loadAllowed) == .orderedDescending
        }
        if loadAllowed {
            let aLoad = a.loadKg ?? 0
            let bLoad = b.loadKg ?? 0
            let loadDiff = aLoad - bLoad
            if abs(loadDiff) > 0.0001 { return loadDiff > 0 }
        }
        switch mode {
        case .reps:
            return (a.reps ?? 0) > (b.reps ?? 0)
        case .seconds:
            return (a.seconds ?? 0) > (b.seconds ?? 0)
        }
    }

    private static func compareIntermittent(
        _ a: TestSet,
        _ b: TestSet,
        loadAllowed: Bool
    ) -> ComparisonResult {
        if loadAllowed {
            let aLoad = a.loadKg ?? 0
            let bLoad = b.loadKg ?? 0
            if abs(aLoad - bLoad) > 0.0001 {
                return aLoad > bLoad ? .orderedDescending : .orderedAscending
            }
        }
        let aReps = a.reps ?? 0
        let bReps = b.reps ?? 0
        if aReps != bReps { return aReps > bReps ? .orderedDescending : .orderedAscending }

        let aSeconds = a.seconds ?? 0
        let bSeconds = b.seconds ?? 0
        if aSeconds != bSeconds { return aSeconds > bSeconds ? .orderedDescending : .orderedAscending }

        return .orderedSame
    }

    // MARK: - Delta

    private static func deltaInfo(
        last: TestSet,
        previous: TestSet?,
        mode: ExerciseMode,
        loadAllowed: Bool,
        isIntermittent: Bool
    ) -> (text: String, isImproving: Bool) {
        guard let previous else { return ("", false) }

        if isIntermittent {
            return intermittentDelta(last: last, previous: previous, loadAllowed: loadAllowed)
        }

        if loadAllowed {
            let lastLoad = last.loadKg ?? 0
            let prevLoad = previous.loadKg ?? 0
            let diff = lastLoad - prevLoad
            if abs(diff) > 0.0001 {
                let sign = diff > 0 ? "↑" : "↓"
                let improving = diff > 0
                return ("\(sign) \(formatSignedKg(diff)) kg", improving)
            }
        }

        switch mode {
        case .reps:
            let diff = (last.reps ?? 0) - (previous.reps ?? 0)
            if diff == 0 { return ("→ Sin cambio", false) }
            let sign = diff > 0 ? "↑" : "↓"
            return ("\(sign) \(diff > 0 ? "+" : "")\(diff) reps", diff > 0)

        case .seconds:
            let diff = (last.seconds ?? 0) - (previous.seconds ?? 0)
            if diff == 0 { return ("→ Sin cambio", false) }
            let sign = diff > 0 ? "↑" : "↓"
            return ("\(sign) \(diff > 0 ? "+" : "")\(diff) s", diff > 0)
        }
    }

    private static func intermittentDelta(
        last: TestSet,
        previous: TestSet,
        loadAllowed: Bool
    ) -> (text: String, isImproving: Bool) {
        if loadAllowed {
            let lastLoad = last.loadKg ?? 0
            let prevLoad = previous.loadKg ?? 0
            let diff = lastLoad - prevLoad
            if abs(diff) > 0.0001 {
                let sign = diff > 0 ? "↑" : "↓"
                return ("\(sign) \(formatSignedKg(diff)) kg", diff > 0)
            }
        }
        let roundsDiff = (last.reps ?? 0) - (previous.reps ?? 0)
        if roundsDiff != 0 {
            let sign = roundsDiff > 0 ? "↑" : "↓"
            return ("\(sign) \(roundsDiff > 0 ? "+" : "")\(roundsDiff) rondas", roundsDiff > 0)
        }
        let secsDiff = (last.seconds ?? 0) - (previous.seconds ?? 0)
        if secsDiff != 0 {
            let sign = secsDiff > 0 ? "↑" : "↓"
            return ("\(sign) \(secsDiff > 0 ? "+" : "")\(secsDiff) s", secsDiff > 0)
        }
        return ("→ Sin cambio", false)
    }

    // MARK: - Formatting

    private static func formatResult(
        _ set: TestSet,
        mode: ExerciseMode,
        loadAllowed: Bool,
        isIntermittent: Bool
    ) -> String {
        if isIntermittent {
            let rounds = set.reps ?? 0
            let workSecs = set.seconds ?? 0
            var parts = "\(rounds) rondas · \(formatSeconds(workSecs))"
            if loadAllowed, let load = set.loadKg, abs(load) > 0.0001 {
                parts += " @ \(formatSignedKg(load)) kg"
            }
            return parts
        }

        switch mode {
        case .reps:
            let reps = set.reps ?? 0
            if loadAllowed, let load = set.loadKg, abs(load) > 0.0001 {
                return "\(formatSignedKg(load)) kg × \(reps) reps"
            }
            return "\(reps) reps"

        case .seconds:
            let secs = set.seconds ?? 0
            if loadAllowed, let load = set.loadKg, abs(load) > 0.0001 {
                return "\(formatSignedKg(load)) kg · \(formatSeconds(secs))"
            }
            return formatSeconds(secs)
        }
    }

    private static func formatSeconds(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        if s < 60 { return "\(s) s" }
        let m = s / 60
        let r = s % 60
        return "\(m):" + String(format: "%02d", r)
    }

    private static func formatSignedKg(_ kg: Double) -> String {
        let sign = kg >= 0 ? "+" : "-"
        let absKg = abs(kg)
        let isWhole = abs(absKg - absKg.rounded()) < 0.0001
        if isWhole { return "\(sign)\(Int(absKg.rounded()))" }
        let formatted = String(format: "%.1f", absKg)
        return "\(sign)\(formatted)"
    }

    // MARK: - Helpers

    private static func isSameExercise(_ entry: WorkoutEntry, exercise: Exercise) -> Bool {
        entry.exercise === exercise
            || (entry.exercise.name == exercise.name && entry.exercise.category == exercise.category)
    }
}
