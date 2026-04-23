import Foundation
import SwiftData

// MARK: - WorkoutDay

@Model
final class WorkoutDay {

    /// Fecha y hora de la sesión.
    /// Permite múltiples sesiones el mismo día.
    var date: Date

    /// Fecha/hora real de inicio del entrenamiento (timer persistente).
    /// Si está en curso: `startedAt != nil && endedAt == nil`.
    var startedAt: Date?

    /// Fecha/hora real de finalización del entrenamiento (timer persistente).
    /// Si está finalizado: `startedAt != nil && endedAt != nil`.
    var endedAt: Date?

    /// Nombre editable para diferenciar entrenamientos.
    /// Default vacío para evitar problemas de migración.
    var name: String = ""

    /// Notas generales del día.
    var notes: String

    /// Entries asociados a la sesión.
    @Relationship(deleteRule: .cascade)
    var entries: [WorkoutEntry]

    init(
        date: Date = Date(),
        name: String = "",
        notes: String = "",
        entries: [WorkoutEntry] = [],
        startedAt: Date? = nil,
        endedAt: Date? = nil
    ) {
        self.date = date
        self.name = name
        self.notes = notes
        self.entries = entries
        self.startedAt = startedAt
        self.endedAt = endedAt
    }

    /// Clave de día (inicio del día) útil para agrupar en estadísticas futuras.
    var dayKey: Date {
        Calendar.current.startOfDay(for: date)
    }
}


// MARK: - Exercise

@Model
final class Exercise {

    var name: String
    var category: String

    /// Solo puede ser "reps" o "seconds"
    var mode: String

    /// Si false, loadKg debe permanecer nil en los SetRecord
    var loadAllowed: Bool

    var notes: String
    var isArchived: Bool

    init(
        name: String,
        category: String,
        mode: String,
        loadAllowed: Bool,
        notes: String = "",
        isArchived: Bool = false
    ) {
        self.name = name
        self.category = category
        self.mode = mode
        self.loadAllowed = loadAllowed
        self.notes = notes
        self.isArchived = isArchived
    }
}


// MARK: - WorkoutEntry

@Model
final class WorkoutEntry {

    var exercise: Exercise
    var intensity: Int
    var isDone: Bool
    var entryNotes: String

    // MARK: - Bloques y Travesías (fase base)
    // Opcionales para no romper persistencia existente.
    var climbKind: String?
    var climbIdentifier: String?
    var climbGradeColor: String?
    /// `nil` = sin marcar todavía.  `true` = encadenado/completado con éxito.  `false` = intentado sin completar.
    /// Solo relevante cuando `isBlock || isTraverse`.
    var climbSuccess: Bool?

    @Relationship(deleteRule: .cascade)
    var sets: [SetRecord]

    init(
        exercise: Exercise,
        intensity: Int = 1,
        isDone: Bool = false,
        entryNotes: String = "",
        sets: [SetRecord] = [],
        climbKind: String? = nil,
        climbIdentifier: String? = nil,
        climbGradeColor: String? = nil,
        climbSuccess: Bool? = nil
    ) {
        self.exercise = exercise
        self.intensity = intensity
        self.isDone = isDone
        self.entryNotes = entryNotes
        self.sets = sets
        self.climbKind = climbKind
        self.climbIdentifier = climbIdentifier
        self.climbGradeColor = climbGradeColor
        self.climbSuccess = climbSuccess
    }
}

extension WorkoutEntry {
    /// Helpers simples para identificar Bloques/Travesías sin tocar lógica de UI.
    var isBlock: Bool {
        if let kind = climbKindNormalized, kind == "block" { return true }
        return exerciseNameNormalized == "bloque"
    }

    var isTraverse: Bool {
        if let kind = climbKindNormalized, kind == "traverse" { return true }
        return exerciseNameNormalized == "travesia"
    }

    // MARK: - Editores especiales (semántica centralizada; la vista no heurística inline)

    /// Misma semántica que `isBlock`: UI de bloque (identificador, color, intentos).
    var usesBlockEditor: Bool { isBlock }

    /// Misma semántica que `isTraverse`: UI de travesía (letra, intentos).
    var usesTraverseEditor: Bool { isTraverse }

    /// Ejercicios tipo “Vuelta …”: un solo set, reps = nº vueltas (heurística por nombre).
    var usesVueltaEditor: Bool { exercise.isVueltaStyleExercise }

    /// `Suspensiones intermitentes` y `Test de Suspensiones intermitentes` en Hangboard.
    var usesIntermittentHangboardEditor: Bool { exercise.isIntermittentHangboardExercise }

    private var climbKindNormalized: String? {
        climbKind?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private var exerciseNameNormalized: String {
        exercise.exerciseNameKeyForSemantics
    }
}

// MARK: - WorkoutDay display naming (sin tocar persistencia)
extension WorkoutDay {
    /// Nombre alternativo para la UI cuando `name` está vacío.
    /// Genera un string a partir de categorías únicas presentes en `entries`.
    ///
    /// Regla:
    /// - Unique: categorías únicas de `entry.exercise.category`
    /// - Orden: alfabético
    /// - Join: " · "
    /// - Si no hay categorías válidas: devuelve `nil` (para que la UI use su fallback discreto).
    var categoriesBasedName: String? {
        let categories = Set(
            entries.compactMap { entry in
                let trimmed = entry.exercise.category
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
        )

        guard !categories.isEmpty else { return nil }

        let sorted = categories.sorted { a, b in
            a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }

        return sorted.joined(separator: " · ")
    }
}

// MARK: - UserProfile

/// Perfil local único (sin login). Solo debe existir una instancia en el store.
@Model
final class UserProfile {
    var name: String
    var heightCm: Double?
    var birthDate: Date?

    init(
        name: String = "",
        heightCm: Double? = nil,
        birthDate: Date? = nil
    ) {
        self.name = name
        self.heightCm = heightCm
        self.birthDate = birthDate
    }
}

// MARK: - SetRecord

@Model
final class SetRecord {

    /// Solo usar si exercise.mode == "reps"
    var reps: Int?

    /// Solo usar si exercise.mode == "seconds"
    /// Guardado en segundos totales (UI lo muestra mm:ss)
    var seconds: Int?

    /// Solo válido si exercise.loadAllowed == true
    var loadKg: Double?

    init(
        reps: Int? = nil,
        seconds: Int? = nil,
        loadKg: Double? = nil
    ) {
        self.reps = reps
        self.seconds = seconds
        self.loadKg = loadKg
    }
}

import Foundation

enum ExerciseMode: String, CaseIterable {
    case reps
    case seconds
}

extension Exercise {
    /// Acceso seguro a mode sin "strings mágicos".
    /// Si por cualquier razón mode contiene un valor inválido, hacemos fallback a .reps.
    var modeEnum: ExerciseMode {
        get { ExerciseMode(rawValue: mode) ?? .reps }
        set { mode = newValue.rawValue }
    }

    // MARK: - Semántica de ejercicio (sin persistencia nueva; evolución futura a campo explícito)

    /// Nombres canónicos de producto para reglas que no deben dispersarse en vistas.
    enum SemanticExerciseNames {
        static let suspensionesIntermitentes = "Suspensiones intermitentes"
        static let testDeSuspensionesIntermitentes = "Test de Suspensiones intermitentes"
    }

    /// Clave estable para comparar nombre (trim, diacríticos, minúsculas).
    var exerciseNameKeyForSemantics: String {
        Self.normalizedKeyForSemanticMatching(name)
    }

    /// Clave estable para categoría.
    var exerciseCategoryKeyForSemantics: String {
        Self.normalizedKeyForSemanticMatching(category)
    }

    /// Heurística por nombre: ejercicios “Vuelta …” en catálogo (contiene subcadena `vuelta`).
    var isVueltaStyleExercise: Bool {
        exerciseNameKeyForSemantics.contains("vuelta")
    }

    /// Intermitentes en regleta: canónico o variante Test; misma UX que el editor paramétrico.
    var isIntermittentHangboardExercise: Bool {
        guard exerciseCategoryKeyForSemantics == "hangboard" else { return false }
        let n = exerciseNameKeyForSemantics
        return n == Self.normalizedKeyForSemanticMatching(SemanticExerciseNames.suspensionesIntermitentes)
            || n == Self.normalizedKeyForSemanticMatching(SemanticExerciseNames.testDeSuspensionesIntermitentes)
    }

    /// Derivados del catálogo con prefijo `Test de `.
    var isTestExercise: Bool {
        exerciseNameKeyForSemantics.hasPrefix("test de ")
    }

    private static func normalizedKeyForSemanticMatching(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
}

extension SetRecord {
    /// Crea un set consistente con el modo del ejercicio.
    static func make(for exercise: Exercise) -> SetRecord {
        switch exercise.modeEnum {
        case .reps:
            return SetRecord(reps: 0, seconds: nil, loadKg: nil)
        case .seconds:
            return SetRecord(reps: nil, seconds: 0, loadKg: nil)
        }
    }
}
