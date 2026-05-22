import Foundation

/// Etiquetas cortas para UI compacta (p. ej. picker de categoría en Progreso).
enum ProgressCategoryAbbreviation {
    private static let fixedAbbreviations: [String: String] = [
        "fuerza maxima": "FM",
        "fuerza general": "FG",
        "resistencia": "RE",
        "acondicionamiento": "AC",
        "recuperacion": "RP",
        "tecnica": "TC",
        "hangboard": "HB",
        "campus": "CP",
        "movilidad": "MO",
        "calentamiento": "CL",
        "core": "CR",
        "bloques": "BL",
        "bloque": "BL",
        "travesia": "TV",
        "test": "TE",
        "otros": "OT"
    ]

    static func normalizedKey(from displayLabel: String) -> String {
        displayLabel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }

    static func shortLabel(for displayLabel: String) -> String {
        let key = normalizedKey(from: displayLabel)
        if let fixed = fixedAbbreviations[key] {
            return fixed
        }
        return initialsFromFirstTwoWords(displayLabel)
    }

    private static func initialsFromFirstTwoWords(_ label: String) -> String {
        let words = label
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }

        guard let first = words.first else { return "?" }

        if words.count == 1 {
            return String(first.prefix(2)).uppercased()
        }

        let firstInitial = first.first.map { String($0).uppercased() } ?? ""
        let secondInitial = words[1].first.map { String($0).uppercased() } ?? ""
        let combined = firstInitial + secondInitial
        return combined.isEmpty ? "?" : combined
    }
}
