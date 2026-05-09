import Foundation
import SwiftData

struct RecentRecordSnapshot: Identifiable {
    let id: String
    let exerciseName: String
    let bestMark: String
    /// Fecha de la sesión en la que se batió la marca (derivada).
    let recordDate: Date
    let workout: WorkoutDay
    let entry: WorkoutEntry
}

/// DTO de métricas globales derivadas, desacoplado de SwiftData salvo anclas de navegación en récords recientes.
struct GlobalStatsSnapshot {
    let totalWorkouts: Int
    let workoutsLast30Days: Int
    let totalCompletedExercises: Int
    let currentWeekWorkouts: Int
    let favoriteCategory: String
    let totalTrainingTime: TimeInterval
    let recentRecords: [RecentRecordSnapshot]

    static let empty = GlobalStatsSnapshot(
        totalWorkouts: 0,
        workoutsLast30Days: 0,
        totalCompletedExercises: 0,
        currentWeekWorkouts: 0,
        favoriteCategory: "Sin datos",
        totalTrainingTime: 0,
        recentRecords: []
    )
}
