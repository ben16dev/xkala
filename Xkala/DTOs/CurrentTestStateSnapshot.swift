import Foundation

/// Snapshot derivado con el estado actual del usuario en Tests, agrupado por capacidad física.
struct CurrentTestStateSnapshot {
    /// Resultados por capacidad: capacidad → (nombre del test, último resultado formateado, fecha).
    /// Solo contiene capacidades con al menos un Test registrado.
    let resultsByCapacity: [TestCapacity: TestCapacityResult]

    struct TestCapacityResult {
        let testName: String
        let resultText: String
        /// Fecha del último resultado válido de la capacidad (derivada; no persistida).
        let lastTestDate: Date

        /// Antigüedad compacta respecto a `now` (día calendario).
        /// - Hoy
        /// - Hace X días / 1 día
        /// - Hace X semanas / 1 semana
        /// - Hace X meses / 1 mes
        func ageText(relativeTo now: Date = Date(), calendar: Calendar = .current) -> String {
            let startLast = calendar.startOfDay(for: lastTestDate)
            let startNow = calendar.startOfDay(for: now)
            let dayDiff = calendar.dateComponents([.day], from: startLast, to: startNow).day ?? 0

            if dayDiff <= 0 {
                return "Hoy"
            }
            if dayDiff < 7 {
                return dayDiff == 1 ? "Hace 1 día" : "Hace \(dayDiff) días"
            }
            if dayDiff < 30 {
                let weeks = dayDiff / 7
                return weeks == 1 ? "Hace 1 semana" : "Hace \(weeks) semanas"
            }
            let months = max(1, calendar.dateComponents([.month], from: startLast, to: startNow).month ?? 1)
            return months == 1 ? "Hace 1 mes" : "Hace \(months) meses"
        }
    }

    /// `true` si hay al menos una capacidad evaluada.
    var hasData: Bool {
        !resultsByCapacity.isEmpty
    }

    /// Capacidades ordenadas para UI (orden lógico: fuerza → resistencia).
    var orderedCapacities: [TestCapacity] {
        let order: [TestCapacity] = [
            .pullingStrength,
            .pullingEndurance,
            .fingerStrength,
            .fingerEndurance,
            .pushingStrength,
            .shoulderStrength,
            .accessoryStrength,
            .unknown
        ]
        return order.filter { resultsByCapacity[$0] != nil }
    }

    static let empty = CurrentTestStateSnapshot(resultsByCapacity: [:])
}
