import Foundation

/// Métricas de bloques y travesías derivadas de `WorkoutDay.entries` (sin persistencia).
struct ClimbingStatsSnapshot: Equatable {
    let blocksTotal: Int
    let blocksSuccess: Int
    let traversesTotal: Int
    let traversesSuccess: Int

    var isEmpty: Bool {
        blocksTotal == 0 && traversesTotal == 0
    }
}
