import Foundation

enum AvatarMood {
    case idle
    case happy
    case tired
    case strong
}

/// Deriva el mood del avatar solo desde actividad reciente real (sin persistir estado).
enum AvatarMoodResolver {

    private enum Constants {
        static let strongRetentionHours: TimeInterval = 24
        static let inactivityDaysForTired = 4
        static let minHappySessions = 2
        static let minStrongSessionsIn3Days = 2
        static let strongRecentWindowDays = 3
        static let happyWindowDays = 7
        static let longSessionMinutes = 60
    }

    static func mood(
        for workouts: [WorkoutDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AvatarMood {
        let real = realCompletedWorkouts(from: workouts, now: now, calendar: calendar)
        let today = sessionsToday(in: real, now: now, calendar: calendar)

        let resolved: AvatarMood
        if qualifiesForStrong(real: real, now: now, calendar: calendar) {
            resolved = .strong
        } else if qualifiesForHappy(real: real, now: now, calendar: calendar) {
            resolved = .happy
        } else if qualifiesForTired(real: real, now: now, calendar: calendar) {
            resolved = .tired
        } else {
            resolved = .idle
        }

        #if DEBUG
        print(
            "[AvatarMoodDebug] workouts=\(workouts.count) valid=\(real.count) " +
            "today=\(today.count) mood=\(resolved)"
        )
        debugLogMoodInput(workouts: workouts, now: now, calendar: calendar)
        #endif

        return resolved
    }

    // MARK: - Mood rules

    private static func qualifiesForStrong(
        real: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard let signal = strongSignalDate(real: real, now: now, calendar: calendar) else {
            return false
        }
        return isWithinStrongRetention(signalDate: signal, now: now)
    }

    private static func qualifiesForHappy(
        real: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let recent = recentSessions(in: real, days: Constants.happyWindowDays, now: now, calendar: calendar)
        return recent.count >= Constants.minHappySessions
    }

    private static func qualifiesForTired(
        real: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) -> Bool {
        daysSinceLastRealSession(in: real, now: now, calendar: calendar) >= Constants.inactivityDaysForTired
    }

    // MARK: - Strong

    /// Fecha de la última señal `strong` válida (sesión de referencia).
    static func strongSignalDate(
        real: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) -> Date? {
        if let today = primaryTodaySession(in: real, now: now, calendar: calendar),
           meetsStrongConditions(todaySession: today, real: real, referenceNow: now, calendar: calendar) {
            return sessionReferenceDate(today)
        }

        let sorted = real.sorted { sessionReferenceDate($0) > sessionReferenceDate($1) }
        for workout in sorted {
            let ref = sessionReferenceDate(workout)
            let elapsed = now.timeIntervalSince(ref)
            guard elapsed >= 0, elapsed <= Constants.strongRetentionHours * 3600 else { continue }
            if meetsStrongConditions(todaySession: workout, real: real, referenceNow: ref, calendar: calendar) {
                return ref
            }
        }

        return nil
    }

    private static func meetsStrongConditions(
        todaySession: WorkoutDay,
        real: [WorkoutDay],
        referenceNow: Date,
        calendar: Calendar
    ) -> Bool {
        guard calendar.isDate(sessionReferenceDate(todaySession), inSameDayAs: referenceNow) else {
            return false
        }

        let last3Days = recentSessions(in: real, days: Constants.strongRecentWindowDays, now: referenceNow, calendar: calendar)
        if last3Days.count >= Constants.minStrongSessionsIn3Days {
            return true
        }

        return hasLongSessionToday(in: real, now: referenceNow, calendar: calendar)
    }

    /// Alguna sesión real válida hoy supera el umbral largo (`effectiveDurationMinutes`, no solo el timer).
    private static func hasLongSessionToday(
        in real: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) -> Bool {
        sessionsToday(in: real, now: now, calendar: calendar)
            .contains { ($0.effectiveDurationMinutes ?? 0) > Constants.longSessionMinutes }
    }

    private static func primaryTodaySession(
        in real: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) -> WorkoutDay? {
        sessionsToday(in: real, now: now, calendar: calendar).max { lhs, rhs in
            (lhs.effectiveDurationMinutes ?? 0) < (rhs.effectiveDurationMinutes ?? 0)
        }
    }

    static func sessionsToday(
        in real: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) -> [WorkoutDay] {
        real.filter { calendar.isDate(sessionReferenceDate($0), inSameDayAs: now) }
    }

    private static func isWithinStrongRetention(signalDate: Date, now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(signalDate)
        return elapsed >= 0 && elapsed <= Constants.strongRetentionHours * 3600
    }

    // MARK: - Sessions

    static func realCompletedWorkouts(
        from workouts: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) -> [WorkoutDay] {
        workouts.filter { isRealCompletedWorkout($0, now: now, calendar: calendar) }
    }

    static func isRealCompletedWorkout(
        _ workout: WorkoutDay,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        // Cronómetro en curso: no cuenta como sesión completada.
        if workout.startedAt != nil && workout.endedAt == nil {
            #if DEBUG
            debugReject(workout, reason: "timer en curso sin endedAt")
            #endif
            return false
        }

        guard let minutes = workout.effectiveDurationMinutes, minutes > 0 else {
            #if DEBUG
            debugReject(workout, reason: "duración inválida (effectiveDurationMinutes=\(workout.effectiveDurationMinutes.map(String.init) ?? "nil"))")
            #endif
            return false
        }
        if isImportedSession(workout) {
            #if DEBUG
            debugReject(workout, reason: "importada [IMPORT:…]")
            #endif
            return false
        }

        if workout.date > now {
            #if DEBUG
            debugReject(workout, reason: "date posterior a now")
            #endif
            return false
        }

        let todayStart = calendar.startOfDay(for: now)
        let sessionDayStart = calendar.startOfDay(for: sessionReferenceDate(workout))
        if sessionDayStart > todayStart {
            #if DEBUG
            debugReject(workout, reason: "día de sesión futuro respecto a now")
            #endif
            return false
        }

        if let endedAt = workout.endedAt, endedAt > now {
            #if DEBUG
            debugReject(workout, reason: "endedAt posterior a now")
            #endif
            return false
        }

        return true
    }

    #if DEBUG
    private static func debugLogMoodInput(
        workouts: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) {
        let real = realCompletedWorkouts(from: workouts, now: now, calendar: calendar)
        let today = sessionsToday(in: real, now: now, calendar: calendar)
        print("[AvatarMood] workouts=\(workouts.count) válidas=\(real.count) hoy=\(today.count) now=\(now)")
        for w in workouts {
            let ref = sessionReferenceDate(w)
            print(
                "[AvatarMood] id=\(w.id) type=\(w.sessionType) date=\(w.date) ref=\(ref) " +
                "started=\(w.startedAt.map(String.init(describing:)) ?? "nil") " +
                "ended=\(w.endedAt.map(String.init(describing:)) ?? "nil") " +
                "dur=\(w.durationMinutes.map(String.init) ?? "nil") eff=\(w.effectiveDurationMinutes.map(String.init) ?? "nil") " +
                "válida=\(isRealCompletedWorkout(w, now: now, calendar: calendar))"
            )
        }
    }

    private static func debugReject(_ workout: WorkoutDay, reason: String) {
        print("[AvatarMood] descartada id=\(workout.id) type=\(workout.sessionType): \(reason)")
    }
    #endif

    static func isImportedSession(_ workout: WorkoutDay) -> Bool {
        WorkoutImportBatchNotes.extractImportBatchId(from: workout.notes) != nil
    }

    static func recentSessions(
        in real: [WorkoutDay],
        days: Int,
        now: Date,
        calendar: Calendar
    ) -> [WorkoutDay] {
        guard days > 0,
              let windowStart = calendar.date(
                byAdding: .day,
                value: -(days - 1),
                to: calendar.startOfDay(for: now)
              )
        else {
            return []
        }

        return real.filter { workout in
            let ref = sessionReferenceDate(workout)
            return ref >= windowStart && ref <= now
        }
    }

    /// Días naturales desde la última sesión real completada.
    ///
    /// Mide desde `WorkoutDay.date` (fecha de sesión que muestra el calendario y que usa
    /// `GlobalStatsSnapshot`), no desde `endedAt`. Así la inactividad es coherente con lo que ve el
    /// usuario y no depende de cuándo se cerró el cronómetro (elimina la discrepancia manual vs timer,
    /// donde una sesión con fecha pasada pero `endedAt` reciente reportaba menos días de los reales).
    static func daysSinceLastRealSession(
        in real: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard let last = real.max(by: { $0.date < $1.date }) else {
            return Int.max
        }

        let todayStart = calendar.startOfDay(for: now)
        let lastStart = calendar.startOfDay(for: last.date)
        return calendar.dateComponents([.day], from: lastStart, to: todayStart).day ?? 0
    }

    static func sessionReferenceDate(_ workout: WorkoutDay) -> Date {
        workout.endedAt ?? workout.date
    }
}
