import Foundation

/// Interpreta las métricas globales ya calculadas en un único insight de actividad reciente.
///
/// Puro y determinista: consume exactamente `GlobalStatsSnapshot` para las comparativas
/// (mismos números que "Actividad reciente") y `daysSinceLastRealSession` para la inactividad.
/// No recalcula métricas, no accede a persistencia y no construye texto de presentación.
enum ActivityInsightResolver {

    private enum Thresholds {
        static let inactivityDays = 7
        static let loadAbsolute = 10
        static let loadRelative = 0.25
        static let workoutsAbsolute = 2
    }

    static func resolve(
        snapshot: GlobalStatsSnapshot,
        daysSinceLastRealSession: Int
    ) -> ActivityInsight? {
        // 1. Inactividad: solo si hay una sesión real previa (Int.max = ninguna) y supera el umbral.
        if daysSinceLastRealSession != Int.max,
           daysSinceLastRealSession >= Thresholds.inactivityDays {
            return .inactive(days: daysSinceLastRealSession)
        }

        // 2. Cambio notable de carga (requiere carga actual y anterior positivas).
        if let currentLoad = snapshot.sessionLoadLast30Days {
            let delta = snapshot.sessionLoadLast30DaysDelta ?? 0
            let previousLoad = currentLoad - delta
            if previousLoad > 0 {
                let absoluteDelta = abs(delta)
                let relativeDelta = Double(absoluteDelta) / Double(previousLoad)
                if absoluteDelta >= Thresholds.loadAbsolute,
                   relativeDelta >= Thresholds.loadRelative {
                    return delta > 0 ? .loadIncreased : .loadDecreased
                }
            }
        }

        // 3. Cambio de frecuencia de entrenos.
        let workoutsDelta = snapshot.workoutsLast30DaysDelta
        if workoutsDelta >= Thresholds.workoutsAbsolute {
            return .workoutsIncreased
        }
        if workoutsDelta <= -Thresholds.workoutsAbsolute {
            return .workoutsDecreased
        }

        // 4. Estable: solo con actividad comparable en ambos periodos.
        let currentWorkouts = snapshot.workoutsLast30Days
        let previousWorkouts = currentWorkouts - workoutsDelta
        if currentWorkouts > 0, previousWorkouts > 0 {
            return .stable
        }

        // 5. Sin base fiable.
        return nil
    }
}
