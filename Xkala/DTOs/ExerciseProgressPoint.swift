import Foundation

/// Punto de serie temporal para gráficos de progreso (siempre derivado, no persistido).
struct ExerciseProgressPoint: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    /// Valor en el eje Y; prioridad alineada con `ExerciseProgressCalculator` (carga, reps, segundos, intentos).
    let value: Double
    /// Descripción de la mejor marca de la sesión (p. ej. accesibilidad).
    let valueLabel: String
}

/// Serie + metadatos mínimos para un gráfico de evolución en `ExerciseDetailView`.
struct ExerciseProgressChartModel: Equatable, Sendable {
    let points: [ExerciseProgressPoint]
    let yAxisTitle: String
    /// `true` en bloque/travesía: menos intentos es mejor.
    let lowerIsBetter: Bool
    /// Mejor valor dentro de la serie mostrada (mínimo si `lowerIsBetter`, máximo si no). `nil` sin puntos.
    let bestInSeries: Double?
}
