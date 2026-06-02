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

    /// Porcentaje entero de bloques con `climbSuccess == true`; `nil` si no hay bloques.
    var blockSuccessRateText: String? {
        successRateText(success: blocksSuccess, total: blocksTotal)
    }

    /// Porcentaje entero de travesías con `climbSuccess == true`; `nil` si no hay travesías.
    var traverseSuccessRateText: String? {
        successRateText(success: traversesSuccess, total: traversesTotal)
    }

    private func successRateText(success: Int, total: Int) -> String? {
        guard total > 0 else { return nil }
        let percent = Int((Double(success) / Double(total) * 100).rounded())
        return "\(percent)%"
    }
}
