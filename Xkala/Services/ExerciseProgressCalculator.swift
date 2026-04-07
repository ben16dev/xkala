import Foundation

/// DTO simple y listo para UI (sin lógica de presentación).
struct ExerciseProgressSnapshot: Equatable {
    let bestMarkText: String
    let lastSessionText: String
    let comparisonText: String
    let trend: ProgressTrend
    let hasEnoughData: Bool
}

/// Estadísticas básicas: mismos criterios de inclusión que `snapshot` (`buildSessions`), sin texto de presentación.
struct ExerciseBasicStatsSnapshot: Equatable {
    /// Número de veces que el ejercicio ha sido completado con al menos un set válido.
    /// No representa días únicos, sino sesiones históricas totales del ejercicio.
    let sessionsCount: Int
    let lastSessionDate: Date?
}

enum ProgressTrend: Equatable {
    case up
    case flat
    case down
    case none
}

/// Calculadora pura: deriva métricas de progreso desde el historial existente (sin persistir nada).
struct ExerciseProgressCalculator {
    static func snapshot(for exercise: Exercise, in workouts: [WorkoutDay]) -> ExerciseProgressSnapshot {
        let mode = exercise.modeEnum
        let loadAllowed = exercise.loadAllowed

        let sessions = buildSessions(for: exercise, mode: mode, loadAllowed: loadAllowed, workouts: workouts)

        guard let lastSession = sessions.first, !sessions.isEmpty else {
            return ExerciseProgressSnapshot(
                bestMarkText: "",
                lastSessionText: "",
                comparisonText: "Sin datos suficientes",
                trend: .none,
                hasEnoughData: false
            )
        }

        let bestHistorical = sessions.map(\.bestSet).reduce(lastSession.bestSet) { currentBest, candidate in
            isGreater(candidate, than: currentBest, mode: mode, loadAllowed: loadAllowed) ? candidate : currentBest
        }

        let previousSession = sessions.count >= 2 ? sessions[1] : nil

        let comparison: (text: String, trend: ProgressTrend) = {
            guard let previousSession else {
                return ("Primera sesión registrada", .none)
            }
            let cmp = compare(lastSession.bestSet, previousSession.bestSet, mode: mode, loadAllowed: loadAllowed)
            switch cmp {
            case .orderedDescending:
                return ("↑ mejor que la anterior", .up)
            case .orderedSame:
                return ("→ igual que la anterior", .flat)
            case .orderedAscending:
                return ("↓ peor que la anterior", .down)
            }
        }()

        return ExerciseProgressSnapshot(
            bestMarkText: formatBestSet(bestHistorical, mode: mode, loadAllowed: loadAllowed),
            lastSessionText: formatBestSet(lastSession.bestSet, mode: mode, loadAllowed: loadAllowed),
            comparisonText: comparison.text,
            trend: comparison.trend,
            hasEnoughData: true
        )
    }

    /// Misma base que `snapshot`: sesiones con `isDone`, mismo ejercicio, y al menos un set válido.
    static func basicStats(for exercise: Exercise, in workouts: [WorkoutDay]) -> ExerciseBasicStatsSnapshot {
        let mode = exercise.modeEnum
        let loadAllowed = exercise.loadAllowed
        let sessions = buildSessions(for: exercise, mode: mode, loadAllowed: loadAllowed, workouts: workouts)
        return ExerciseBasicStatsSnapshot(
            sessionsCount: sessions.count,
            lastSessionDate: sessions.first?.workoutDate
        )
    }

    private struct CandidateSet {
        let reps: Int?
        let seconds: Int?
        let loadKg: Double?
    }

    private struct SessionBest {
        let workoutDate: Date
        let bestSet: CandidateSet
    }

    private static func buildSessions(
        for exercise: Exercise,
        mode: ExerciseMode,
        loadAllowed: Bool,
        workouts: [WorkoutDay]
    ) -> [SessionBest] {
        // Nota: queremos "última sesión" y "anterior" en términos cronológicos.
        // La vista ya entrega workouts en orden .reverse, pero aquí ordenamos por seguridad.
        let workoutsSortedDesc = workouts.sorted { $0.date > $1.date }

        var sessions: [SessionBest] = []
        for workout in workoutsSortedDesc {
            for entry in workout.entries {
                // Mantener el significado actual de "progreso": solo ejercicios completados cuentan.
                guard entry.isDone else { continue }

                guard isSameExercise(entry, exercise: exercise) else { continue }

                if let bestSet = bestSetInEntry(entry, mode: mode, loadAllowed: loadAllowed) {
                    sessions.append(SessionBest(workoutDate: workout.date, bestSet: bestSet))
                }
            }
        }

        return sessions
    }

    private static func bestSetInEntry(
        _ entry: WorkoutEntry,
        mode: ExerciseMode,
        loadAllowed: Bool
    ) -> CandidateSet? {
        var currentBest: CandidateSet?
        for set in entry.sets {
            guard let candidate = validCandidate(set, mode: mode, loadAllowed: loadAllowed) else { continue }

            if let existingBest = currentBest {
                if isGreater(candidate, than: existingBest, mode: mode, loadAllowed: loadAllowed) {
                    currentBest = candidate
                }
            } else {
                currentBest = candidate
            }
        }
        return currentBest
    }

    private static func validCandidate(_ set: SetRecord, mode: ExerciseMode, loadAllowed: Bool) -> CandidateSet? {
        switch mode {
        case .reps:
            guard let reps = set.reps, isValidRepsValue(reps) else { return nil }
            let loadKg = loadAllowed ? set.loadKg : nil
            return CandidateSet(reps: reps, seconds: nil, loadKg: loadKg)

        case .seconds:
            guard let seconds = set.seconds, isValidSecondsValue(seconds) else { return nil }
            let loadKg = loadAllowed ? set.loadKg : nil
            return CandidateSet(reps: nil, seconds: seconds, loadKg: loadKg)
        }
    }

    private static func isValidRepsValue(_ reps: Int) -> Bool {
        // 0 reps suele representar valores placeholders en la UI.
        (1...2000).contains(reps)
    }

    private static func isValidSecondsValue(_ seconds: Int) -> Bool {
        // Conservador para evitar valores corruptos.
        (1...86400).contains(seconds) // <= 24h
    }

    private static func isSameExercise(_ entry: WorkoutEntry, exercise: Exercise) -> Bool {
        // Preferimos identidad por referencia (misma instancia SwiftData),
        // con fallback por clave lógica para evitar falsos negativos.
        entry.exercise === exercise
            || (entry.exercise.name == exercise.name && entry.exercise.category == exercise.category)
    }

    private static func compare(
        _ a: CandidateSet,
        _ b: CandidateSet,
        mode: ExerciseMode,
        loadAllowed: Bool
    ) -> ComparisonResult {
        // Regla pedida: si loadAllowed == true, priorizamos loadKg.
        // Para poder comparar casos “uno tiene carga y el otro no”, tratamos nil como 0.
        if loadAllowed {
            let aLoad = a.loadKg ?? 0
            let bLoad = b.loadKg ?? 0
            let cmpLoad = aLoad.compare(b: bLoad)
            if cmpLoad != .orderedSame {
                return cmpLoad
            }
        }

        return compareBaseMetric(a, b, mode: mode)
    }

    private static func isGreater(
        _ a: CandidateSet,
        than b: CandidateSet,
        mode: ExerciseMode,
        loadAllowed: Bool
    ) -> Bool {
        compare(a, b, mode: mode, loadAllowed: loadAllowed) == .orderedDescending
    }

    private static func compareBaseMetric(_ a: CandidateSet, _ b: CandidateSet, mode: ExerciseMode) -> ComparisonResult {
        switch mode {
        case .reps:
            return compareInts(a.reps ?? 0, b.reps ?? 0)
        case .seconds:
            return compareInts(a.seconds ?? 0, b.seconds ?? 0)
        }
    }

    private static func compareInts(_ a: Int, _ b: Int) -> ComparisonResult {
        if a == b { return .orderedSame }
        return a > b ? .orderedDescending : .orderedAscending
    }

    private static func formatBestSet(_ set: CandidateSet, mode: ExerciseMode, loadAllowed: Bool) -> String {
        switch mode {
        case .reps:
            let reps = set.reps ?? 0
            var text = "\(reps) reps"
            if loadAllowed, shouldShowLoadKg(set.loadKg) {
                let loadKg = set.loadKg! // safe: shouldShowLoadKg ya valida que no es nil
                text += " @ \(formatSignedKg(loadKg)) kg"
            }
            return text

        case .seconds:
            let seconds = set.seconds ?? 0
            var text = formatMMSS(seconds)
            if loadAllowed, shouldShowLoadKg(set.loadKg) {
                let loadKg = set.loadKg! // safe: shouldShowLoadKg ya valida que no es nil
                text += " @ \(formatSignedKg(loadKg)) kg"
            }
            return text
        }
    }

    private static func shouldShowLoadKg(_ loadKg: Double?) -> Bool {
        guard let loadKg else { return false }
        // Omite “@ +0 kg” (y valores casi cero).
        return abs(loadKg) > 0.0001
    }

    private static func formatSignedKg(_ kg: Double) -> String {
        let sign = kg >= 0 ? "+" : "-"
        let absKg = abs(kg)

        let isWhole = abs(absKg - absKg.rounded()) < 0.0001
        if isWhole {
            return "\(sign)\(Int(absKg.rounded()))"
        }

        // La UI edita con decimales de 0.5 (y muestra 1 decimal), así que mostramos 1 decimal.
        let formatted = String(format: "%.1f", absKg)
        return "\(sign)\(formatted.replacingOccurrences(of: ".0", with: ""))"
    }

    private static func formatMMSS(_ totalSeconds: Int) -> String {
        let s = max(0, totalSeconds)
        let m = s / 60
        let r = s % 60
        return "\(m):" + String(format: "%02d", r)
    }
}

private extension Double {
    /// Comparación tolerante para Double (evita empates raros por precisión).
    func compare(b: Double, epsilon: Double = 0.0001) -> ComparisonResult {
        let diff = self - b
        if abs(diff) <= epsilon { return .orderedSame }
        return diff > 0 ? .orderedDescending : .orderedAscending
    }
}
