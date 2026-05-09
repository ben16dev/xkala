import Foundation

enum AvatarKind: String, CaseIterable, Identifiable {
    case chimp
    case goat
    case salamander
    case snowleopard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chimp: return "Dyno"
        case .goat: return "Canto"
        case .snowleopard: return "Cumbre"
        case .salamander: return "Beta"
        }
    }

    var folderName: String {
        switch self {
        case .chimp: return "avatar_chimp"
        case .goat: return "avatar_goat"
        case .salamander: return "avatar_salamander"
        case .snowleopard: return "avatar_snowleopard"
        }
    }

    /// Nombre del asset en el catálogo (imageset único: `chimp_default`, etc.).
    func assetName(for mood: AvatarMood) -> String {
        let suffix: String
        switch mood {
        case .happy:
            suffix = "happy"
        case .tired:
            suffix = "tired"
        case .strong:
            suffix = "strong"
        case .idle:
            suffix = "default"
        }
        return "\(rawValue)_\(suffix)"
    }
}

extension AvatarKind {
    /// Escala base por avatar (ajusta proporciones sin editar PNG).
    var imageScale: CGFloat {
        switch self {
        case .chimp: return 1.00
        case .goat: return 1.00
        case .snowleopard: return 1.00
        case .salamander: return 1.00
        }
    }

    /// Desplazamiento vertical relativo al `size` del `AvatarView` (pies alineados).
    /// Valores pequeños: ~-0.06 sube, ~0.06 baja.
    var imageYOffset: CGFloat {
        switch self {
        case .chimp: return 0
        case .goat: return 0
        case .snowleopard: return 0
        case .salamander: return 0
        }
    }
}
