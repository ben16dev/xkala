import Foundation

/// Punto temporal agregado para gráficos globales (sin persistencia).
struct InsightsBucket: Identifiable, Equatable {
    let id: String
    /// Posición en el eje X del gráfico: 0…n−1 en orden cronológico ascendente (`intervalStart`).
    let chronologicalIndex: Int
    /// Inicio del bucket (día, semana o mes); clave de orden real, no el texto del eje.
    let intervalStart: Date
    /// Texto del eje X (día, SEM n, mes…); solo presentación.
    let axisLabel: String

    /// Suma de duraciones de sesiones válidas en el bucket (`endedAt - startedAt`).
    let trainingTimeSeconds: TimeInterval
    /// Número de sesiones válidas en el bucket.
    let sessionCount: Int

    /// Tiempo en sesiones `sessionType == training` (rocódromo / entreno).
    let trainingTypeTimeSeconds: TimeInterval
    /// Tiempo en sesiones `sessionType == climbing` (roca).
    let climbingTypeTimeSeconds: TimeInterval

    /// Sesiones con `sessionType == training`.
    let trainingSessions: Int
    /// Sesiones con `sessionType == climbing`.
    let climbingSessions: Int
}

/// Snapshot derivado para `InsightsView`.
struct InsightsSnapshot: Equatable {
    let range: StatsRange
    let buckets: [InsightsBucket]
}
