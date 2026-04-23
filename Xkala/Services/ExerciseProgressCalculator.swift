import Foundation

/// DTO simple y listo para UI (sin lógica de presentación).
struct ExerciseProgressSnapshot: Equatable {
    let bestMarkText: String
    let lastSessionText: String
    let comparisonText: String
    let trend: ProgressTrend
    let hasEnoughData: Bool
    /// Texto "última vs mejor histórico". Vacío si no hay datos suficientes.
    let vsBestText: String
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
        snapshot(for: exercise, contextEntry: nil, in: workouts)
    }

    static func snapshot(for entry: WorkoutEntry, in workouts: [WorkoutDay]) -> ExerciseProgressSnapshot {
        // Bloques y travesías necesitan anclar la "última sesión" al entry concreto que se está viendo,
        // no al más reciente cronológico del ejercicio base (que podría ser un bloque diferente).
        guard entry.isBlock || entry.isTraverse else {
            return snapshot(for: entry.exercise, contextEntry: entry, in: workouts)
        }
        return snapshotForClimbEntry(entry, in: workouts)
    }

    private static func snapshot(
        for exercise: Exercise,
        contextEntry: WorkoutEntry?,
        in workouts: [WorkoutDay]
    ) -> ExerciseProgressSnapshot {
        let mode = exercise.modeEnum
        let loadAllowed = exercise.loadAllowed
        let intermittentHangboard = exercise.isIntermittentHangboardExercise

        let sessions = buildSessions(
            for: exercise,
            contextEntry: contextEntry,
            mode: mode,
            loadAllowed: loadAllowed,
            intermittentHangboard: intermittentHangboard,
            workouts: workouts
        )

        guard let lastSession = sessions.first else {
            return ExerciseProgressSnapshot(
                bestMarkText: "",
                lastSessionText: "",
                comparisonText: "Sin datos suficientes",
                trend: .none,
                hasEnoughData: false,
                vsBestText: ""
            )
        }

        // Mejor histórico:
        // - standard: máximo de todas las sesiones (como antes).
        // - lowerIsBetter: mínimo de sesiones EXITOSAS con misma clave.
        //   Nil si no hay ninguna sesión exitosa comparable.
        let bestHistorical: CandidateSet? = {
            switch lastSession.comparisonKind {
            case .standard:
                return sessions.map(\.bestSet).reduce(lastSession.bestSet) { current, candidate in
                    isGreater(candidate, than: current,
                              mode: mode, loadAllowed: loadAllowed,
                              intermittentHangboard: intermittentHangboard, kind: .standard)
                        ? candidate : current
                }

            case .lowerIsBetter:
                let pool = sessions
                    .filter { $0.isClimbSuccess && sameComparableRoute(lastSession, $0) }
                    .map(\.bestSet)
                if pool.isEmpty {
                    // Sin historial exitoso: si la sesión actual es exitosa, ella misma es la marca.
                    return lastSession.isClimbSuccess ? lastSession.bestSet : nil
                }
                return pool.reduce(pool[0]) { current, candidate in
                    isGreater(candidate, than: current,
                              mode: mode, loadAllowed: loadAllowed,
                              intermittentHangboard: intermittentHangboard, kind: .lowerIsBetter)
                        ? candidate : current
                }
            }
        }()

        // Buscamos la sesión previa comparable más reciente, no simplemente sessions[1].
        // Si la segunda sesión cronológica es un bloque/ruta diferente, tomar sessions[1]
        // haría que areComparable devolviera false y se mostrara "Sesión no comparable"
        // aunque exista una sesión anterior exactamente comparable más atrás en el historial.
        let previousComparableSession = sessions.dropFirst().first(where: { areComparable(lastSession, $0) })

        let comparison: (text: String, trend: ProgressTrend) = {
            guard let previousComparableSession else {
                return ("Primera sesión registrada", .none)
            }
            // previousComparableSession ya cumple areComparable: misma clave + mismo estado éxito/fallo.
            let cmp = compare(
                lastSession.bestSet,
                previousComparableSession.bestSet,
                mode: mode,
                loadAllowed: loadAllowed,
                intermittentHangboard: intermittentHangboard,
                kind: lastSession.comparisonKind
            )
            switch cmp {
            case .orderedDescending: return ("↑ mejor que la anterior", .up)
            case .orderedSame:       return ("→ igual que la anterior", .flat)
            case .orderedAscending:  return ("↓ peor que la anterior", .down)
            }
        }()

        let vsBestText: String = {
            // Los fallos nunca disparan "🔥 mejor marca" aunque tengan pocos intentos.
            if lastSession.comparisonKind == .lowerIsBetter && !lastSession.isClimbSuccess {
                return bestHistorical != nil ? "por debajo de tu mejor" : ""
            }
            guard let best = bestHistorical else {
                // Primera sesión exitosa sin historial previo.
                return "🔥 mejor marca"
            }
            let cmp = compare(
                lastSession.bestSet, best,
                mode: mode, loadAllowed: loadAllowed,
                intermittentHangboard: intermittentHangboard,
                kind: lastSession.comparisonKind
            )
            // .orderedDescending no debería ocurrir (best ya incluye lastSession),
            // pero lo tratamos igual que .orderedSame por robustez.
            guard cmp == .orderedAscending else {
                return "🔥 mejor marca"
            }
            // lowerIsBetter: sin cálculo de proximidad (intentos son discretos).
            guard lastSession.comparisonKind == .standard else {
                return "por debajo de tu mejor"
            }
            guard !loadAllowed else { return "por debajo de tu mejor" }
            let lastBase: Int
            let bestBase: Int
            switch mode {
            case .reps:
                lastBase = lastSession.bestSet.reps ?? 0
                bestBase = best.reps ?? 0
            case .seconds:
                lastBase = lastSession.bestSet.seconds ?? 0
                bestBase = best.seconds ?? 0
            }
            guard bestBase > 0 else { return "por debajo de tu mejor" }
            return Double(lastBase) / Double(bestBase) >= 0.9
                ? "cerca de tu mejor"
                : "por debajo de tu mejor"
        }()

        return ExerciseProgressSnapshot(
            bestMarkText: bestHistorical.map {
                formatBestSet($0, mode: mode, loadAllowed: loadAllowed, kind: lastSession.comparisonKind)
            } ?? "",
            lastSessionText: formatBestSet(
                lastSession.bestSet, mode: mode, loadAllowed: loadAllowed, kind: lastSession.comparisonKind
            ),
            comparisonText: comparison.text,
            trend: comparison.trend,
            hasEnoughData: true,
            vsBestText: vsBestText
        )
    }

    /// Misma base que `snapshot`: sesiones con `isDone`, mismo ejercicio, y al menos un set válido.
    static func basicStats(for exercise: Exercise, in workouts: [WorkoutDay]) -> ExerciseBasicStatsSnapshot {
        basicStats(for: exercise, contextEntry: nil, in: workouts)
    }

    static func basicStats(for entry: WorkoutEntry, in workouts: [WorkoutDay]) -> ExerciseBasicStatsSnapshot {
        guard entry.isBlock || entry.isTraverse else {
            return basicStats(for: entry.exercise, contextEntry: entry, in: workouts)
        }
        // Para bloques/travesías, contar solo las sesiones de la misma ruta (misma clave).
        let exercise = entry.exercise
        let mode = exercise.modeEnum
        let loadAllowed = exercise.loadAllowed
        let intermittentHangboard = exercise.isIntermittentHangboardExercise
        let (_, routeKey) = comparisonInfo(for: entry)
        let allSessions = buildSessions(
            for: exercise, contextEntry: entry,
            mode: mode, loadAllowed: loadAllowed,
            intermittentHangboard: intermittentHangboard, workouts: workouts
        )
        let routeSessions = routeKey.map { key in allSessions.filter { $0.comparisonKey == key } } ?? allSessions
        return ExerciseBasicStatsSnapshot(
            sessionsCount: routeSessions.count,
            lastSessionDate: routeSessions.first?.workoutDate
        )
    }

    private static func basicStats(
        for exercise: Exercise,
        contextEntry: WorkoutEntry?,
        in workouts: [WorkoutDay]
    ) -> ExerciseBasicStatsSnapshot {
        let mode = exercise.modeEnum
        let loadAllowed = exercise.loadAllowed
        let intermittentHangboard = exercise.isIntermittentHangboardExercise
        let sessions = buildSessions(
            for: exercise,
            contextEntry: contextEntry,
            mode: mode,
            loadAllowed: loadAllowed,
            intermittentHangboard: intermittentHangboard,
            workouts: workouts
        )
        return ExerciseBasicStatsSnapshot(
            sessionsCount: sessions.count,
            lastSessionDate: sessions.first?.workoutDate
        )
    }

    // MARK: - Private types

    /// Semántica de comparación entre sesiones.
    private enum ComparisonKind: Equatable {
        /// Ejercicios normales: más reps/segundos (y carga) = mejor.
        case standard
        /// Bloques y travesías: menos intentos = mejor. La carga se ignora.
        case lowerIsBetter
    }

    private struct CandidateSet {
        let reps: Int?
        let seconds: Int?
        let loadKg: Double?
    }

    private struct SessionBest {
        let workoutDate: Date
        let bestSet: CandidateSet
        /// Semántica de comparación derivada del tipo de entrada.
        let comparisonKind: ComparisonKind
        /// Clave que debe coincidir para que dos sesiones sean del mismo bloque/ruta.
        /// - bloque:   "color|identifier" (nil si falta alguno)
        /// - travesía: "identifier"        (nil si falta)
        /// - normal:   nil (siempre comparable)
        let comparisonKey: String?
        /// Solo relevante para `.lowerIsBetter`. Para `.standard` siempre es `true`.
        let isClimbSuccess: Bool
    }

    // MARK: - buildSessions

    private static func buildSessions(
        for exercise: Exercise,
        contextEntry: WorkoutEntry?,
        excludeEntry: WorkoutEntry? = nil,
        mode: ExerciseMode,
        loadAllowed: Bool,
        intermittentHangboard: Bool,
        workouts: [WorkoutDay]
    ) -> [SessionBest] {
        // La vista ya entrega workouts en orden .reverse, pero aquí ordenamos por seguridad.
        let workoutsSortedDesc = workouts.sorted { $0.date > $1.date }

        var sessions: [SessionBest] = []
        for workout in workoutsSortedDesc {
            for entry in workout.entries {
                guard entry.isDone else { continue }
                // Excluir el entry anclado cuando se pide, para que no aparezca en el historial.
                if let exclude = excludeEntry, entry === exclude { continue }
                guard isSameExercise(entry, exercise: exercise) else { continue }
                guard matchesContext(entry, contextEntry: contextEntry) else { continue }

                let (kind, key) = comparisonInfo(for: entry)
                // Tanto sesiones exitosas como fallidas se guardan.
                // El éxito/fallo afecta a bestHistorical y areComparable, no a si la sesión existe.
                let climbSuccess = kind == .lowerIsBetter ? isSuccessfulClimbEntry(entry) : true

                if let bestSet = bestSetInEntry(
                    entry,
                    mode: mode,
                    loadAllowed: loadAllowed,
                    intermittentHangboard: intermittentHangboard,
                    kind: kind
                ) {
                    sessions.append(SessionBest(
                        workoutDate: workout.date,
                        bestSet: bestSet,
                        comparisonKind: kind,
                        comparisonKey: key,
                        isClimbSuccess: climbSuccess
                    ))
                }
            }
        }

        return sessions
    }

    // MARK: - Climb success

    /// Indica si un bloque o travesía fue completado con éxito (encadenado/pegado).
    ///
    /// ── Conectar campo real ─────────────────────────────────────────────────
    /// `climbSuccess: Bool?` ya está persistido en `WorkoutEntry` (Models.swift).
    /// Esta función ya lo lee: `nil` (entradas antiguas sin marcar) → fallback `true`
    /// para no ocultar datos previos al migrar.
    /// ────────────────────────────────────────────────────────────────────────
    private static func isSuccessfulClimbEntry(_ entry: WorkoutEntry) -> Bool {
        if let succeeded = entry.climbSuccess { return succeeded }
        return true  // fallback conservador: entradas antiguas sin campo se tratan como éxito
    }

    /// Deriva el tipo de comparación y la clave de comparabilidad a partir de una entrada.
    private static func comparisonInfo(for entry: WorkoutEntry) -> (kind: ComparisonKind, key: String?) {
        if entry.isBlock {
            let color = normalizedString(entry.climbGradeColor)
            let id    = normalizedString(entry.climbIdentifier)
            if let c = color, let i = id {
                return (.lowerIsBetter, "\(c)|\(i)")
            }
            return (.lowerIsBetter, nil)
        }
        if entry.isTraverse {
            if let id = normalizedString(entry.climbIdentifier) {
                return (.lowerIsBetter, id)
            }
            return (.lowerIsBetter, nil)
        }
        return (.standard, nil)
    }

    // MARK: - Comparability

    /// Dos sesiones son del mismo bloque/ruta (ignora estado de éxito).
    /// Usado para filtrar el pool de `bestHistorical`.
    private static func sameComparableRoute(_ a: SessionBest, _ b: SessionBest) -> Bool {
        guard a.comparisonKind == b.comparisonKind else { return false }
        switch a.comparisonKind {
        case .standard:
            return true
        case .lowerIsBetter:
            guard let keyA = a.comparisonKey, let keyB = b.comparisonKey else { return false }
            return keyA == keyB
        }
    }

    /// Dos sesiones son comparables para progreso si:
    /// - pertenecen al mismo bloque/ruta (`sameComparableRoute`), y
    /// - para `lowerIsBetter`: tienen el mismo estado de éxito (éxito con éxito, fallo con fallo).
    ///
    /// Conservador: ante la duda, devuelve `false`.
    private static func areComparable(_ a: SessionBest, _ b: SessionBest) -> Bool {
        guard sameComparableRoute(a, b) else { return false }
        if a.comparisonKind == .lowerIsBetter {
            return a.isClimbSuccess == b.isClimbSuccess
        }
        return true
    }

    // MARK: - matchesContext

    /// Filtra por tipo de entrada (bloque / travesía / normal) según el contexto.
    /// La coincidencia exacta de clave y estado de éxito se delega a `areComparable` en `snapshot`.
    private static func matchesContext(_ candidate: WorkoutEntry, contextEntry: WorkoutEntry?) -> Bool {
        guard let contextEntry else { return true }
        if contextEntry.isBlock    { return candidate.isBlock }
        if contextEntry.isTraverse { return candidate.isTraverse }
        return true
    }

    // MARK: - bestSetInEntry

    private static func bestSetInEntry(
        _ entry: WorkoutEntry,
        mode: ExerciseMode,
        loadAllowed: Bool,
        intermittentHangboard: Bool,
        kind: ComparisonKind
    ) -> CandidateSet? {
        var currentBest: CandidateSet?
        for set in entry.sets {
            guard let candidate = validCandidate(
                set,
                mode: mode,
                loadAllowed: loadAllowed,
                intermittentHangboard: intermittentHangboard
            ) else { continue }

            if let existingBest = currentBest {
                if isGreater(
                    candidate,
                    than: existingBest,
                    mode: mode,
                    loadAllowed: loadAllowed,
                    intermittentHangboard: intermittentHangboard,
                    kind: kind
                ) {
                    currentBest = candidate
                }
            } else {
                currentBest = candidate
            }
        }
        return currentBest
    }

    private static func validCandidate(
        _ set: SetRecord,
        mode: ExerciseMode,
        loadAllowed: Bool,
        intermittentHangboard: Bool
    ) -> CandidateSet? {
        if intermittentHangboard, mode == .seconds {
            guard let seconds = set.seconds, isValidSecondsValue(seconds) else { return nil }
            guard let reps = set.reps, isValidRepsValue(reps) else { return nil }
            let loadKg = loadAllowed ? set.loadKg : nil
            return CandidateSet(reps: reps, seconds: seconds, loadKg: loadKg)
        }

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
        // 0 reps suele representar valores placeholder en la UI.
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

    // MARK: - String normalization

    private static func normalizedString(_ s: String?) -> String? {
        let result = s?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard let r = result, !r.isEmpty else { return nil }
        return r
    }

    // MARK: - Comparison

    private static func compare(
        _ a: CandidateSet,
        _ b: CandidateSet,
        mode: ExerciseMode,
        loadAllowed: Bool,
        intermittentHangboard: Bool,
        kind: ComparisonKind
    ) -> ComparisonResult {
        switch kind {
        case .lowerIsBetter:
            // Ignorar carga. Menos reps/segundos = mejor → orderedDescending.
            return compareBaseMetricReversed(a, b, mode: mode)

        case .standard:
            if intermittentHangboard {
                return compareIntermittent(a, b, loadAllowed: loadAllowed)
            }
            // Regla: si loadAllowed == true, priorizamos loadKg.
            // nil se trata como 0 para poder comparar casos "uno tiene carga y el otro no".
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
    }

    /// Intermitentes: carga → rondas (`reps`) → tiempo (`seconds`). `nil` en carga se trata como 0.
    /// Convención: `.orderedDescending` ⇒ A mejor que B; `.orderedAscending` ⇒ A peor que B.
    private static func compareIntermittent(
        _ a: CandidateSet,
        _ b: CandidateSet,
        loadAllowed: Bool
    ) -> ComparisonResult {
        let loadEpsilon = 0.0001

        if loadAllowed {
            let aLoad = a.loadKg ?? 0
            let bLoad = b.loadKg ?? 0
            if abs(aLoad - bLoad) > loadEpsilon {
                return aLoad > bLoad ? .orderedDescending : .orderedAscending
            }
        }

        let aReps = a.reps ?? 0
        let bReps = b.reps ?? 0
        if aReps != bReps {
            return aReps > bReps ? .orderedDescending : .orderedAscending
        }

        let aSeconds = a.seconds ?? 0
        let bSeconds = b.seconds ?? 0
        if aSeconds != bSeconds {
            return aSeconds > bSeconds ? .orderedDescending : .orderedAscending
        }

        return .orderedSame
    }

    private static func isGreater(
        _ a: CandidateSet,
        than b: CandidateSet,
        mode: ExerciseMode,
        loadAllowed: Bool,
        intermittentHangboard: Bool,
        kind: ComparisonKind
    ) -> Bool {
        compare(
            a, b,
            mode: mode,
            loadAllowed: loadAllowed,
            intermittentHangboard: intermittentHangboard,
            kind: kind
        ) == .orderedDescending
    }

    private static func compareBaseMetric(_ a: CandidateSet, _ b: CandidateSet, mode: ExerciseMode) -> ComparisonResult {
        switch mode {
        case .reps:    return compareInts(a.reps ?? 0, b.reps ?? 0)
        case .seconds: return compareInts(a.seconds ?? 0, b.seconds ?? 0)
        }
    }

    /// Versión invertida: menos reps/segundos = mejor → orderedDescending.
    /// `nil` se penaliza con `Int.max` (considerado el peor resultado posible).
    private static func compareBaseMetricReversed(_ a: CandidateSet, _ b: CandidateSet, mode: ExerciseMode) -> ComparisonResult {
        switch mode {
        case .reps:
            let aVal = a.reps ?? Int.max
            let bVal = b.reps ?? Int.max
            if aVal == bVal { return .orderedSame }
            return aVal < bVal ? .orderedDescending : .orderedAscending
        case .seconds:
            let aVal = a.seconds ?? Int.max
            let bVal = b.seconds ?? Int.max
            if aVal == bVal { return .orderedSame }
            return aVal < bVal ? .orderedDescending : .orderedAscending
        }
    }

    private static func compareInts(_ a: Int, _ b: Int) -> ComparisonResult {
        if a == b { return .orderedSame }
        return a > b ? .orderedDescending : .orderedAscending
    }

    // MARK: - Formatting

    /// Formatea el mejor set para mostrar en UI.
    /// Para `lowerIsBetter` usa "intentos" en lugar de "reps" y omite la carga (siempre ignorada).
    private static func formatBestSet(
        _ set: CandidateSet,
        mode: ExerciseMode,
        loadAllowed: Bool,
        kind: ComparisonKind
    ) -> String {
        switch mode {
        case .reps:
            let reps = set.reps ?? 0
            let unit = kind == .lowerIsBetter ? "intentos" : "reps"
            var text = "\(reps) \(unit)"
            if kind == .standard, loadAllowed, shouldShowLoadKg(set.loadKg) {
                let loadKg = set.loadKg! // safe: shouldShowLoadKg ya valida que no es nil
                text += " @ \(formatSignedKg(loadKg)) kg"
            }
            return text

        case .seconds:
            let seconds = set.seconds ?? 0
            var text = formatMMSS(seconds)
            if kind == .standard, loadAllowed, shouldShowLoadKg(set.loadKg) {
                let loadKg = set.loadKg! // safe: shouldShowLoadKg ya valida que no es nil
                text += " @ \(formatSignedKg(loadKg)) kg"
            }
            return text
        }
    }

    private static func shouldShowLoadKg(_ loadKg: Double?) -> Bool {
        guard let loadKg else { return false }
        // Omite "@ +0 kg" (y valores casi cero).
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

    // MARK: - Climb entry snapshot

    /// Snapshot para un bloque o travesía concreto.
    ///
    /// A diferencia del flujo general, aquí el `contextEntry` es SIEMPRE la "última sesión",
    /// independientemente de qué sesión sea cronológicamente la más reciente en el historial
    /// del ejercicio base. Esto evita que un bloque diferente (ej: naranja/FR) ocupe sessions[0]
    /// y "robe" el rol de última sesión al bloque que el usuario está viendo (ej: verde/FR).
    ///
    /// El historial se construye excluyendo el `contextEntry` para que la comparación siempre
    /// sea contra una sesión distinta, no contra sí mismo.
    private static func snapshotForClimbEntry(
        _ contextEntry: WorkoutEntry,
        in workouts: [WorkoutDay]
    ) -> ExerciseProgressSnapshot {
        let exercise = contextEntry.exercise
        let mode = exercise.modeEnum
        let loadAllowed = exercise.loadAllowed
        let intermittentHangboard = exercise.isIntermittentHangboardExercise

        let (kind, currentKey) = comparisonInfo(for: contextEntry)
        let currentSuccess = isSuccessfulClimbEntry(contextEntry)

        // Fecha del workout que contiene este entry específico.
        let currentWorkoutDate = workouts
            .first(where: { $0.entries.contains { $0 === contextEntry } })?
            .date ?? Date()

        // Si el entry no tiene un set válido (ej: 0 intentos), no hay datos que mostrar.
        guard let currentBestSet = bestSetInEntry(
            contextEntry, mode: mode, loadAllowed: loadAllowed,
            intermittentHangboard: intermittentHangboard, kind: kind
        ) else {
            return ExerciseProgressSnapshot(
                bestMarkText: "", lastSessionText: "",
                comparisonText: "Sin datos suficientes", trend: .none,
                hasEnoughData: false, vsBestText: ""
            )
        }

        let lastSession = SessionBest(
            workoutDate: currentWorkoutDate,
            bestSet: currentBestSet,
            comparisonKind: kind,
            comparisonKey: currentKey,
            isClimbSuccess: currentSuccess
        )

        // Historial: todos los entries del mismo tipo (bloque/travesía), excluyendo el actual.
        // areComparable/sameComparableRoute se encargan de filtrar por ruta y estado de éxito.
        let historical = buildSessions(
            for: exercise,
            contextEntry: contextEntry,
            excludeEntry: contextEntry,
            mode: mode,
            loadAllowed: loadAllowed,
            intermittentHangboard: intermittentHangboard,
            workouts: workouts
        )

        // Mejor histórico: mínimo de intentos entre sesiones exitosas de la misma ruta.
        // Se incluye el entry actual en el pool si también es exitoso.
        let bestHistorical: CandidateSet? = {
            var pool = historical
                .filter { $0.isClimbSuccess && sameComparableRoute(lastSession, $0) }
                .map(\.bestSet)
            if lastSession.isClimbSuccess { pool.append(lastSession.bestSet) }
            guard !pool.isEmpty else { return nil }
            return pool.reduce(pool[0]) { current, candidate in
                isGreater(candidate, than: current,
                          mode: mode, loadAllowed: loadAllowed,
                          intermittentHangboard: intermittentHangboard, kind: .lowerIsBetter)
                    ? candidate : current
            }
        }()

        // Sesión previa comparable: la más reciente del historial (ya excluye el entry actual)
        // con la misma ruta y el mismo estado de éxito.
        let previousComparableSession = historical.first(where: { areComparable(lastSession, $0) })

        let comparison: (text: String, trend: ProgressTrend) = {
            guard let prev = previousComparableSession else {
                return ("Primera sesión registrada", .none)
            }
            let cmp = compare(
                lastSession.bestSet, prev.bestSet,
                mode: mode, loadAllowed: loadAllowed,
                intermittentHangboard: intermittentHangboard, kind: .lowerIsBetter
            )
            switch cmp {
            case .orderedDescending: return ("↑ mejor que la anterior", .up)
            case .orderedSame:       return ("→ igual que la anterior", .flat)
            case .orderedAscending:  return ("↓ peor que la anterior", .down)
            }
        }()

        let vsBestText: String = {
            // Los fallos nunca disparan "🔥 mejor marca".
            if !lastSession.isClimbSuccess {
                return bestHistorical != nil ? "por debajo de tu mejor" : ""
            }
            guard let best = bestHistorical else { return "🔥 mejor marca" }
            let cmp = compare(
                lastSession.bestSet, best,
                mode: mode, loadAllowed: loadAllowed,
                intermittentHangboard: intermittentHangboard, kind: .lowerIsBetter
            )
            return cmp == .orderedAscending ? "por debajo de tu mejor" : "🔥 mejor marca"
        }()

        return ExerciseProgressSnapshot(
            bestMarkText: bestHistorical.map {
                formatBestSet($0, mode: mode, loadAllowed: loadAllowed, kind: .lowerIsBetter)
            } ?? "",
            lastSessionText: formatBestSet(
                lastSession.bestSet, mode: mode, loadAllowed: loadAllowed, kind: .lowerIsBetter
            ),
            comparisonText: comparison.text,
            trend: comparison.trend,
            hasEnoughData: true,
            vsBestText: vsBestText
        )
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
