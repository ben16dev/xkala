import Foundation

/// Rango temporal reutilizable para estadísticas e insights (UI + calculadoras puras).
enum StatsRange: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1A"

    var id: String { rawValue }

    /// Etiqueta corta para el selector (p. ej. Strava).
    var shortLabel: String { rawValue }
}
