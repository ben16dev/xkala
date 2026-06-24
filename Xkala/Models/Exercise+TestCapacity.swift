import Foundation

// MARK: - TestCapacity

/// Capacidad física evaluada por un ejercicio de Test.
/// Solo relevante cuando `exercise.isTestExercise == true`.
enum TestCapacity: Hashable {
    case pullingStrength
    case pullingEndurance
    case fingerStrength
    case fingerEndurance
    case pushingStrength
    case shoulderStrength
    case accessoryStrength
    case unknown
    
    /// Nombre visible en UI.
    var displayName: String {
        switch self {
        case .pullingStrength: return "Fuerza de tracción"
        case .pullingEndurance: return "Resistencia de tracción"
        case .fingerStrength: return "Fuerza de dedos"
        case .fingerEndurance: return "Resistencia de dedos"
        case .pushingStrength: return "Fuerza de empuje"
        case .shoulderStrength: return "Fuerza de hombro"
        case .accessoryStrength: return "Fuerza accesoria"
        case .unknown: return "Test"
        }
    }
}

// MARK: - Exercise + TestCapacity

extension Exercise {
    /// Capacidad física evaluada por este ejercicio de Test.
    /// Derivado del nombre; no persistido.
    var testCapacity: TestCapacity {
        guard isTestExercise else { return .unknown }
        
        let key = exerciseNameKeyForSemantics
        
        // Mapeo por nombre normalizado
        switch key {
        case "test de dominadas con lastre":
            return .pullingStrength
        case "test de dominadas con lastre negativo":
            return .pullingStrength
        case "test de dominadas libres":
            return .pullingEndurance
        case "test de hangboard con lastre":
            return .fingerStrength
        case "test de hangboard peso negativo":
            return .fingerEndurance
        case "test de suspensiones intermitentes":
            return .fingerEndurance
        case "test de press banca":
            return .pushingStrength
        case "test de hombro":
            return .shoulderStrength
        case "test de biceps":
            return .accessoryStrength
        default:
            return .unknown
        }
    }
}
