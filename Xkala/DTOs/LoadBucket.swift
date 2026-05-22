import Foundation

/// Punto temporal de carga acumulada (duración × RPE); sin persistencia.
struct LoadBucket: Equatable, Identifiable {
    /// Inicio del bucket (día, lunes de semana o mes).
    let date: Date
    /// Suma de `sessionLoad` en el bucket.
    let totalLoad: Int

    var id: TimeInterval { date.timeIntervalSinceReferenceDate }
}
