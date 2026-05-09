import Foundation

enum AvatarMood {
    case idle
    case happy
    case tired
    case strong
}

struct AvatarMoodCalculator {
    /// Sesión de roca (`sessionType == climbing`): siempre cuenta como actividad completada para el mood.
    private static func isRockSession(_ workout: WorkoutDay) -> Bool {
        workout.sessionTypeEnum == .climbing
    }

    /// Actividad “real” para el mood del avatar (no reutilizar en estadísticas conservadoras).
    /// Rocódromo: al menos un entry con `isDone`. Roca: siempre, sin mirar reps ni bloque/travesía.
    private static func hasCompletedActivity(_ workout: WorkoutDay) -> Bool {
        if isRockSession(workout) {
            return true
        }
        return workout.entries.contains { $0.isDone }
    }

    private static func completedWorkouts(from workouts: [WorkoutDay]) -> [WorkoutDay] {
        workouts.filter { hasCompletedActivity($0) }
    }

    static func mood(
        for workouts: [WorkoutDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AvatarMood {
        let todayStart = calendar.startOfDay(for: now)

        let completed = completedWorkouts(from: workouts)

        // Sesiones (no días únicos) en los últimos 7 días naturales,
        // contando todo el día actual hasta el día -6.
        let windowStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let recentCompleted = completed.filter { workout in
            let dayStart = calendar.startOfDay(for: workout.date)
            return dayStart >= windowStart && dayStart <= todayStart
        }

        // strong > happy > tired > idle
        if recentCompleted.count >= 3 {
            return .strong
        }

        let hasCompletedToday = completed.contains { workout in
            calendar.startOfDay(for: workout.date) == todayStart
        }
        if hasCompletedToday {
            return .happy
        }

        guard let lastCompletedDate = completed.map({ $0.date }).max() else {
            return .idle
        }

        let lastCompletedStart = calendar.startOfDay(for: lastCompletedDate)

        let daysSinceLastCompleted = calendar.dateComponents(
            [.day],
            from: lastCompletedStart,
            to: todayStart
        ).day ?? 0

        if daysSinceLastCompleted >= 5 {
            return .tired
        }

        return .idle
    }
}
