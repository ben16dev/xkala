import Foundation

/// Conclusión semántica única sobre la actividad reciente (derivada; sin persistencia).
/// El texto y el estilo se resuelven en la capa de presentación, no aquí.
enum ActivityInsight: Equatable {
    /// Días desde la última sesión real completada (>= umbral de inactividad).
    case inactive(days: Int)
    case loadIncreased
    case loadDecreased
    case workoutsIncreased
    case workoutsDecreased
    case stable
}
