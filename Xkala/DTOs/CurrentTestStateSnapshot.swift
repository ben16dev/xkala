import Foundation

/// Snapshot derivado con el estado actual del usuario en Tests, agrupado por capacidad física.
struct CurrentTestStateSnapshot {
    /// Resultados por capacidad: capacidad → (nombre del test, último resultado formateado).
    /// Solo contiene capacidades con al menos un Test registrado.
    let resultsByCapacity: [TestCapacity: TestCapacityResult]
    
    struct TestCapacityResult {
        let testName: String
        let resultText: String
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
