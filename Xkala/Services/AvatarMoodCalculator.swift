import Foundation

/// Compatibilidad con llamadas existentes; delega en `AvatarMoodResolver`.
struct AvatarMoodCalculator {
    static func mood(
        for workouts: [WorkoutDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> AvatarMood {
        AvatarMoodResolver.mood(for: workouts, now: now, calendar: calendar)
    }
}
