import Foundation

/// Objetivo de la sesión (planificación). Persistido en `WorkoutDay.trainingMethodRawValue` (`rawValue` sin cambios).
enum TrainingMethod: String, CaseIterable, Codable, Identifiable {
    case strength
    case endurance
    case continuity
    case boulder
    case technique
    case explosive
    case mobilityCore
    case recovery

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: return "Fuerza máxima"
        case .endurance: return "Resistencia"
        case .continuity: return "Continuidad"
        case .boulder: return "Bloque"
        case .technique: return "Técnica"
        case .explosive: return "Explosividad"
        case .mobilityCore: return "Movilidad"
        case .recovery: return "Recuperación"
        }
    }

    var helpText: String {
        switch self {
        case .strength:
            return "Pocas repeticiones, mucha intensidad, descansos amplios."
        case .endurance:
            return "Esfuerzos duros mantenidos o repetidos, fatiga alta."
        case .continuity:
            return "Mucho volumen, intensidad controlada, ritmo fluido."
        case .boulder:
            return "Pasos cortos, duros, con bastante descanso."
        case .technique:
            return "Pies, lectura, equilibrio, fluidez, eficiencia."
        case .explosive:
            return "Campus, dinámicos, movimientos rápidos."
        case .mobilityCore:
            return "Preparación física, estabilidad y rango de movimiento."
        case .recovery:
            return "Sesión suave, descarga o vuelta progresiva."
        }
    }
}
