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
    /// Diferencia numérica: entrenos últimos 30 días − entrenos de los 30 días anteriores (derivada; no persistida).
    let workoutsLast30DaysDelta: Int
    let totalCompletedExercises: Int
    let favoriteCategory: String
    let totalTrainingTime: TimeInterval
    let recentRecords: [RecentRecordSnapshot]
    /// Suma de `sessionLoad` (min × RPE) en los últimos 7 días; `nil` si no hay sesiones con carga.
    let sessionLoadLast7Days: Int?
    /// Suma de `sessionLoad` en los últimos 30 días; `nil` si no hay sesiones con carga.
    let sessionLoadLast30Days: Int?
    /// Diferencia: carga últimos 30 días − carga de los 30 días anteriores; `nil` si no hay carga actual.
    let sessionLoadLast30DaysDelta: Int?
    /// Objetivo de la sesión válida más reciente con `trainingMethod`; `nil` si no hay ninguno.
    let lastTrainingMethod: TrainingMethod?
    /// Bloques y travesías; `nil` si no hay ninguno registrado.
    let climbingStats: ClimbingStatsSnapshot?

    static let empty = GlobalStatsSnapshot(
        totalWorkouts: 0,
        workoutsLast30Days: 0,
        workoutsLast30DaysDelta: 0,
        totalCompletedExercises: 0,
        favoriteCategory: "Sin datos",
        totalTrainingTime: 0,
        recentRecords: [],
        sessionLoadLast7Days: nil,
        sessionLoadLast30Days: nil,
        sessionLoadLast30DaysDelta: nil,
        lastTrainingMethod: nil,
        climbingStats: nil
    )
}
