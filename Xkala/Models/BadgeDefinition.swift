import Foundation
import SwiftData

enum BadgeTier: String {
    case wood
}

enum BadgeCategory: String {
    case sessions
    case climbing
    case consistency
}

/// Definición pura de una chapa. No persiste; solo describe el logro.
enum BadgeDefinition: String, CaseIterable, Identifiable, Hashable {
    case woodTrainingSessions
    case woodRockSessions
    case woodBlocksCheck
    case woodTraveCheck
    case woodSessionsInWeek

    var id: String { assetName }

    var assetName: String {
        switch self {
        case .woodTrainingSessions: return "wood_training_sessions"
        case .woodRockSessions: return "wood_rock_sessions"
        case .woodBlocksCheck: return "wood_blocks_check"
        case .woodTraveCheck: return "wood_trave_check"
        case .woodSessionsInWeek: return "wood_sessions_in_week"
        }
    }

    var title: String {
        switch self {
        case .woodTrainingSessions: return "Primera sesión de rocódromo"
        case .woodRockSessions: return "Primera sesión de roca"
        case .woodBlocksCheck: return "Primer bloque encadenado"
        case .woodTraveCheck: return "Primera travesía completada"
        case .woodSessionsInWeek: return "Tres sesiones en una semana"
        }
    }

    var subtitle: String {
        switch self {
        case .woodTrainingSessions: return "Completaste tu primera sesión en el rocódromo."
        case .woodRockSessions: return "Completaste tu primera sesión en roca."
        case .woodBlocksCheck: return "Encadenaste tu primer bloque con éxito."
        case .woodTraveCheck: return "Completaste tu primera travesía con éxito."
        case .woodSessionsInWeek: return "Registraste tres sesiones reales en la misma semana."
        }
    }

    var tier: BadgeTier { .wood }

    var category: BadgeCategory {
        switch self {
        case .woodTrainingSessions, .woodRockSessions: return .sessions
        case .woodBlocksCheck, .woodTraveCheck: return .climbing
        case .woodSessionsInWeek: return .consistency
        }
    }

    var unlockCongratulations: String {
        switch self {
        case .woodTrainingSessions: return "¡Buen trabajo! Cada sesión cuenta para tu evolución."
        case .woodRockSessions: return "¡La roca te esperaba! Sigue sumando experiencia."
        case .woodBlocksCheck: return "¡Encadenado! Un bloque menos en la lista."
        case .woodTraveCheck: return "¡Travesía completada! Sigue explorando líneas."
        case .woodSessionsInWeek: return "¡Constancia! Tres sesiones en una semana es un gran ritmo."
        }
    }

    static func from(badgeId: String) -> BadgeDefinition? {
        allCases.first { $0.id == badgeId }
    }
}

/// Resultado de evaluación: chapa desbloqueada y sesión que la originó.
struct BadgeUnlock: Equatable, Identifiable {
    let badge: BadgeDefinition
    let sourceWorkout: WorkoutDay

    var id: String {
        "\(badge.id)-\(ObjectIdentifier(sourceWorkout))"
    }

    static func == (lhs: BadgeUnlock, rhs: BadgeUnlock) -> Bool {
        lhs.badge == rhs.badge && lhs.sourceWorkout === rhs.sourceWorkout
    }
}
