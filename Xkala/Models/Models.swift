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

    /// Tipo de sesión. Valores válidos: "training" | "climbing".
    /// Default "training" para compatibilidad con datos existentes.
    var sessionType: String = "training"

    /// Datos específicos de sesión de roca. Solo presente cuando sessionType == "climbing".
    @Relationship(deleteRule: .cascade)
    var climbingData: ClimbingSessionData?

    /// Entries asociados a la sesión.
    @Relationship(deleteRule: .cascade)
    var entries: [WorkoutEntry]

    init(
        date: Date = Date(),
        name: String = "",
        notes: String = "",
        entries: [WorkoutEntry] = [],
        startedAt: Date? = nil,
        endedAt: Date? = nil,
        sessionType: String = "training",
        climbingData: ClimbingSessionData? = nil
    ) {
        self.date = date
        self.name = name
        self.notes = notes
        self.entries = entries
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.sessionType = sessionType
        self.climbingData = climbingData
    }

    /// Clave de día (inicio del día) útil para agrupar en estadísticas futuras.
    var dayKey: Date {
        Calendar.current.startOfDay(for: date)
    }
}


// MARK: - ClimbingSessionData

@Model
final class ClimbingSessionData {
    var location: String
    var sector: String
    var routesCount: Int
    var grades: [String]

    init(
        location: String = "",
        sector: String = "",
        routesCount: Int = 0,
        grades: [String] = []
    ) {
        self.location = location
        self.sector = sector
        self.routesCount = routesCount
        self.grades = grades
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

// MARK: - WorkoutDay session type

extension WorkoutDay {
    enum SessionType: String {
        case training = "training"
        case climbing = "climbing"
    }

    var sessionTypeEnum: SessionType {
        SessionType(rawValue: sessionType) ?? .training
    }

    /// Nombre del asset de imagen para el tipo de sesión.
    var sessionIcon: String {
        sessionTypeEnum == .climbing ? "iconMountain" : "iconClimbingShoes"
    }

    /// Garantiza que climbingData existe si y solo si sessionType == "climbing".
    /// Llamar tras cambiar sessionType.
    func applySessionTypeConsistency() {
        if sessionType == "climbing", climbingData == nil {
            climbingData = ClimbingSessionData()
        } else if sessionType == "training" {
            climbingData = nil
        }
    }
}


// MARK: - WorkoutDay display naming (sin tocar persistencia)
extension WorkoutDay {
    var physicalCategories: [String] {
        let excluded = ["bloque", "bloques", "travesia", "travesias"]

        let categories = Set(
            entries.compactMap { entry -> String? in
                let category = entry.exercise.category
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !category.isEmpty else { return nil }

                let normalized = category
                    .lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)

                return excluded.contains(normalized) ? nil : category
            }
        )

        return categories.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var sessionKindName: String? {
        let hasPhysical = !physicalCategories.isEmpty
        let hasBlock = entries.contains { $0.isBlock }
        let hasTraverse = entries.contains { $0.isTraverse }

        if hasPhysical && hasBlock { return "Físico y Boulder" }
        if hasPhysical && hasTraverse { return "Físico y Travesía" }
        if hasPhysical { return "Físico" }
        if hasBlock { return "Boulder" }
        if hasTraverse { return "Travesía" }

        return nil
    }

    var categoriesSummary: String? {
        guard !physicalCategories.isEmpty else { return nil }
        return physicalCategories.joined(separator: " · ")
    }

    var categoriesBasedName: String? {
        sessionKindName
    }
}

// MARK: - UserProfile

/// Perfil local único (sin login). Solo debe existir una instancia en el store.
@Model
final class UserProfile {
    var name: String
    var heightCm: Double?
    var birthDate: Date?

    /// Peso del usuario en kilogramos. Optional → SwiftData hace migración ligera
    /// automática para perfiles existentes (queda como nil hasta que el usuario lo introduzca).
    var weightKg: Double?

    /// Género del usuario. Valores válidos: "escalador" | "escaladora".
    /// Default con literal para permitir migración ligera SwiftData en perfiles existentes.
    var gender: String = "escalador"

    init(
        name: String = "",
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        birthDate: Date? = nil,
        gender: String = "escalador"
    ) {
        self.name = name
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.birthDate = birthDate
        self.gender = gender
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
