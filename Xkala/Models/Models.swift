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

    // MARK: - Planificación de sesión (opcionales → migración ligera)

    /// Duración percibida de la sesión en minutos.
    var durationMinutes: Int?

    /// RPE 1–10: «¿Cómo de dura fue la sesión?»
    var rpe: Int?

    /// Fatiga percibida 1–10.
    var perceivedFatigue: Int?

    /// Sensación de dedos 1–10 (10 = sin molestias).
    var fingerSensation: Int?

    /// Notas de dolor u otras molestias.
    var painNotes: String?

    /// `TrainingMethod.rawValue`; string para compatibilidad SwiftData.
    var trainingMethodRawValue: String?

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

extension WorkoutDay {
    /// Acceso al objetivo de sesión; solo persiste `trainingMethodRawValue`.
    var trainingMethod: TrainingMethod? {
        get {
            guard let raw = trainingMethodRawValue else { return nil }
            return TrainingMethod(rawValue: raw)
        }
        set {
            trainingMethodRawValue = newValue?.rawValue
        }
    }

    /// Carga de sesión derivada: minutos × RPE cuando ambos existen y son válidos.
    var sessionLoad: Int? {
        guard let minutes = effectiveDurationMinutes, let rpe else { return nil }
        guard minutes > 0, (1...10).contains(rpe) else { return nil }
        return minutes * rpe
    }

    /// Recorta escalas 1–10 y duración inválida guardadas fuera de rango (sin tocar método ni notas).
    func normalizePlanningScalars() {
        rpe = Self.clampedPlanningScale(rpe)
        perceivedFatigue = Self.clampedPlanningScale(perceivedFatigue)
        fingerSensation = Self.clampedPlanningScale(fingerSensation)
        syncDurationMinutesFromSessionTimer()
        if let minutes = durationMinutes, minutes <= 0 {
            durationMinutes = nil
        }
        if let raw = trainingMethodRawValue, TrainingMethod(rawValue: raw) == nil {
            trainingMethodRawValue = nil
        }
    }

    /// Actualiza `durationMinutes` desde el cronómetro o la duración manual (`startedAt` / `endedAt`).
    /// No borra minutos guardados en sesiones legacy sin timer.
    func syncDurationMinutesFromSessionTimer() {
        guard startedAt != nil else { return }
        // Sesión ya cerrada con minutos fijados (p. ej. edición manual tras Finalizar).
        if endedAt != nil, let minutes = durationMinutes, minutes > 0 {
            return
        }
        let seconds = SessionTimeFormatter.seconds(from: self)
        guard seconds > 0 else {
            durationMinutes = nil
            return
        }
        durationMinutes = max(1, Int((Double(seconds) / 60.0).rounded()))
    }

    /// Inicia el cronómetro de sesión (no cierra ni recalcula fechas de cierre).
    func startSessionTimer(at startDate: Date = Date()) {
        startedAt = startDate
        endedAt = nil
    }

    /// Finaliza el cronómetro: fija `endedAt`, recalcula inicio real y alinea `date`.
    /// Solo para detención definitiva; una futura pausa no debe llamar a este método.
    func finishSessionTimer(at endDate: Date = Date()) {
        guard startedAt != nil, endedAt == nil else { return }
        let elapsedSeconds = SessionTimeFormatter.seconds(from: self, referenceEnd: endDate)
        endedAt = endDate
        let computedStartDate = endDate.addingTimeInterval(-Double(elapsedSeconds))
        startedAt = computedStartDate
        date = computedStartDate
        syncDurationMinutesFromSessionTimer()
    }

    /// Aplica duración manual según el estado del cronómetro:
    /// - Sin timer: solo `durationMinutes` (sin fechas artificiales).
    /// - En curso: no modifica fechas ni el tiempo mostrado.
    /// - Cerrado: conserva `endedAt`, recalcula `startedAt`/`date` y guarda `durationMinutes`.
    func applyManualSessionDuration(totalSeconds: Int) {
        guard totalSeconds > 0 else { return }
        let minutes = max(1, Int((Double(totalSeconds) / 60.0).rounded()))
        let durationSeconds = TimeInterval(minutes * 60)

        if let ended = endedAt {
            durationMinutes = minutes
            let newStart = ended.addingTimeInterval(-durationSeconds)
            startedAt = newStart
            date = newStart
            return
        }

        if startedAt == nil {
            durationMinutes = minutes
            return
        }

        // Timer en curso: no tocar fechas ni el display live.
    }

    /// Reinicia el cronómetro y borra la duración derivada del timer.
    func clearSessionTimer() {
        startedAt = nil
        endedAt = nil
        durationMinutes = nil
    }

    /// Minutos para planificación: valor persistido o derivado del timer en memoria.
    var effectiveDurationMinutes: Int? {
        if let minutes = durationMinutes, minutes > 0 { return minutes }
        guard startedAt != nil else { return nil }
        let seconds = SessionTimeFormatter.seconds(from: self)
        guard seconds > 0 else { return nil }
        return max(1, Int((Double(seconds) / 60.0).rounded()))
    }

    /// Duración usada por badges: misma prioridad que planificación/stats (`durationMinutes` primero).
    var badgeEligibleDurationMinutes: Int {
        if let durationMinutes, durationMinutes > 0 { return durationMinutes }
        if let effectiveDurationMinutes, effectiveDurationMinutes > 0 { return effectiveDurationMinutes }
        return 0
    }

    /// `true` si hay minutos manuales persistidos sin cronómetro iniciado.
    var hasManualDurationWithoutTimer: Bool {
        startedAt == nil && (durationMinutes ?? 0) > 0
    }

    /// Segundos para el cronómetro visual: timer activo/cerrado o duración manual sin timer.
    var sessionDisplaySeconds: Int {
        if hasManualDurationWithoutTimer {
            return (durationMinutes ?? 0) * 60
        }
        return SessionTimeFormatter.seconds(from: self)
    }

    /// Sesión válida para desbloqueo de chapas (sin exigir cronómetro).
    func isBadgeEligibleWorkout(now: Date = Date()) -> Bool {
        BadgeAwardService.isBadgeEligibleWorkout(self, now: now)
    }

    private static func clampedPlanningScale(_ value: Int?) -> Int? {
        guard let value else { return nil }
        return min(max(value, 1), 10)
    }

    /// Notas visibles al usuario (sin marcador interno `[IMPORT:…]`).
    var displayNotes: String {
        notes
            .replacingOccurrences(
                of: #"\[IMPORT:[^\]]+\]"#,
                with: "",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Actualiza las notas editables preservando el marcador de importación, si existe.
    func applyDisplayNotes(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let batchId = WorkoutImportBatchNotes.extractImportBatchId(from: notes) {
            let marker = WorkoutImportBatchNotes.importBatchMarker(for: batchId)
            notes = trimmed.isEmpty ? marker : "\(trimmed)\n\(marker)"
        } else {
            notes = trimmed
        }
    }
}


// MARK: - ClimbingRouteRecord

@Model
final class ClimbingRouteRecord {
    var name: String = ""
    var grade: String = ""
    var isSent: Bool = false

    init(
        name: String = "",
        grade: String = "",
        isSent: Bool = false
    ) {
        self.name = name
        self.grade = grade
        self.isSent = isSent
    }
}


// MARK: - ClimbingSessionData

@Model
final class ClimbingSessionData {
    var location: String = ""
    var sector: String = ""
    /// Legacy: conservado para histórico; usar `effectiveAttemptedRoutesCount` en UI.
    var routesCount: Int = 0
    var attemptedRoutesCount: Int = 0
    var sentRoutesCount: Int = 0
    var bestTriedGrade: String = ""
    var bestSentGrade: String = ""
    var grades: [String] = []

    @Relationship(deleteRule: .cascade)
    var routes: [ClimbingRouteRecord] = []

    init(
        location: String = "",
        sector: String = "",
        routesCount: Int = 0,
        attemptedRoutesCount: Int = 0,
        sentRoutesCount: Int = 0,
        bestTriedGrade: String = "",
        bestSentGrade: String = "",
        grades: [String] = [],
        routes: [ClimbingRouteRecord] = []
    ) {
        self.location = location
        self.sector = sector
        self.routesCount = routesCount
        self.attemptedRoutesCount = attemptedRoutesCount
        self.sentRoutesCount = sentRoutesCount
        self.bestTriedGrade = bestTriedGrade
        self.bestSentGrade = bestSentGrade
        self.grades = grades
        self.routes = routes
    }

    /// Vías probadas: nuevo campo o fallback legacy `routesCount`.
    var effectiveAttemptedRoutesCount: Int {
        if attemptedRoutesCount > 0 { return attemptedRoutesCount }
        return max(0, routesCount)
    }

    func setAttemptedRoutesCount(_ value: Int) {
        attemptedRoutesCount = max(0, value)
    }

    func setSentRoutesCount(_ value: Int) {
        sentRoutesCount = max(0, value)
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
        if let kind = climbKindNormalized {
            if kind == "traverse" || kind == "trave" { return true }
        }
        if exerciseNameNormalized == "travesia" { return true }
        let categoryKey = exercise.exerciseCategoryKeyForSemantics
        return categoryKey == "travesia" || categoryKey == "travesias"
    }

    // MARK: - Editores especiales (semántica centralizada; la vista no heurística inline)

    /// Misma semántica que `isBlock`: UI de bloque (identificador, color, intentos).
    var usesBlockEditor: Bool { isBlock }

    /// Misma semántica que `isTraverse`: UI de travesía (letra, intentos).
    var usesTraverseEditor: Bool { isTraverse }

    /// Circuito / vuelta de calentamiento: un solo set, reps = nº vueltas (nombre canónico o histórico).
    var usesCircuitEditor: Bool { exercise.isCircuitStyleExercise }

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
        sessionTypeEnum == .climbing ? "iconRope" : "iconClimbingShoes"
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
    /// Etiquetas únicas de categoría detectadas en la sesión (solo lectura en UI).
    var sessionCategoryLabels: [String] {
        let labels = Set(entries.compactMap { Self.displayCategoryLabel(for: $0) })
        return labels.sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
    }

    var sessionKindName: String? {
        let parts = sessionActivityNameParts
        guard !parts.isEmpty else { return nil }
        return Self.joinedSpanishList(parts)
    }

    var categoriesSummary: String? {
        let labels = sessionCategoryLabels
        guard !labels.isEmpty else { return nil }
        return labels.joined(separator: " · ")
    }

    /// Nombre automático para sesiones de cuerda (ubicación / sector).
    var climbingAutoGeneratedName: String {
        let location = Self.trimmedNonEmpty(climbingData?.location ?? "")
        let sector = Self.trimmedNonEmpty(climbingData?.sector ?? "")
        switch (location, sector) {
        case let (loc?, sec?):
            return "\(loc) · \(sec)"
        case let (loc?, nil):
            return loc
        case let (nil, sec?):
            return sec
        case (nil, nil):
            return "Sesión de cuerda"
        }
    }

    /// Nombre que el sistema generaría ahora para esta sesión.
    var proposedAutoGeneratedSessionName: String? {
        if sessionTypeEnum == .climbing {
            return climbingAutoGeneratedName
        }
        return sessionKindName
    }

    var categoriesBasedName: String? {
        if sessionTypeEnum == .climbing {
            return climbingAutoGeneratedName
        }
        return sessionKindName
    }

    /// Defaults estáticos que pueden sobrescribirse con autogeneración.
    static let knownStaticAutoDefaultSessionNames: [String] = [
        "Sesión de cuerda",
        "Entrenamiento",
        "Sesión de entrenamiento",
        "Test de entrenamiento",
        "Sesión de roca",
        "Rocódromo",
        "Test en rocódromo",
        "Sesión Rocódromo",
        "Bloque",
        "Bloques",
        "Travesía",
        "Físico",
        "Hangboard",
        "Campus",
    ]

    /// `true` si `name` está vacío o coincide con un nombre automático conocido.
    var isAutoDefaultSessionName: Bool {
        if sessionTypeEnum == .climbing {
            return !isClimbingUserLockedSessionName
        }
        return isTrainingAutoDefaultSessionName
    }

    /// Entrenamiento / training: solo nombres automáticos válidos actuales o legacy conocidos.
    private var isTrainingAutoDefaultSessionName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return true }
        
        // Nombres automáticos actuales
        if trimmed.compare("Entrenamiento", options: .caseInsensitive) == .orderedSame {
            return true
        }
        if trimmed.compare("Test de entrenamiento", options: .caseInsensitive) == .orderedSame {
            return true
        }
        
        // Legacy: defaults conocidos de versiones anteriores
        if Self.knownStaticAutoDefaultSessionNames.contains(where: {
            trimmed.compare($0, options: .caseInsensitive) == .orderedSame
        }) {
            return true
        }
        
        return false
    }

    /// Cuerda: bloqueado solo si parece un título manual (p. ej. varias palabras sin ` · `).
    private var isClimbingUserLockedSessionName: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        if Self.knownStaticAutoDefaultSessionNames.contains(where: {
            trimmed.compare($0, options: .caseInsensitive) == .orderedSame
        }) {
            return false
        }
        if let kind = sessionKindName,
           trimmed.compare(kind, options: .caseInsensitive) == .orderedSame {
            return false
        }
        if let summary = categoriesSummary,
           trimmed.compare(summary, options: .caseInsensitive) == .orderedSame {
            return false
        }
        if trimmed.compare(climbingAutoGeneratedName, options: .caseInsensitive) == .orderedSame {
            return false
        }
        if trimmed.compare("Sesión de cuerda", options: .caseInsensitive) == .orderedSame {
            return false
        }
        if trimmed.compare("Sesión de roca", options: .caseInsensitive) == .orderedSame {
            return false
        }
        let location = Self.trimmedNonEmpty(climbingData?.location ?? "")
        let sector = Self.trimmedNonEmpty(climbingData?.sector ?? "")
        if let location, trimmed.compare(location, options: .caseInsensitive) == .orderedSame {
            return false
        }
        if let sector, trimmed.compare(sector, options: .caseInsensitive) == .orderedSame {
            return false
        }
        // Títulos compuestos autogenerados (`Ubicación · Sector`), aunque estén desfasados.
        if trimmed.contains(" · ") { return false }
        // Una sola palabra: nombre autogenerado antiguo (p. ej. ubicación previa).
        if !trimmed.contains(where: \.isWhitespace) { return false }
        return true
    }

    /// Actualiza `name` solo si sigue siendo un default automático (sin flag de edición manual).
    func syncAutoGeneratedSessionNameIfNeeded() {
        guard isAutoDefaultSessionName else { return }
        if sessionTypeEnum == .climbing {
            name = climbingAutoGeneratedName
            return
        }
        name = trainingAutoGeneratedName
    }

    private static func trimmedNonEmpty(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Detección de actividades para nombre automático

    private var hasTestActivity: Bool {
        entries.contains {
            $0.isDone && $0.exercise.isTestExercise
        }
    }

    /// Nombre automático para sesiones de entrenamiento (training).
    /// Regla simple: "Test de entrenamiento" si hay test completado, "Entrenamiento" en caso contrario.
    private var trainingAutoGeneratedName: String {
        hasTestActivity ? "Test de entrenamiento" : "Entrenamiento"
    }

    private var sessionActivityNameParts: [String] {
        guard sessionTypeEnum == .training else { return [] }
        return [trainingAutoGeneratedName]
    }

    private var hasPhysicalTraining: Bool {
        entries.contains { entry in
            guard !entry.isBlock, !entry.isTraverse else { return false }
            let category = entry.exercise.exerciseCategoryKeyForSemantics
            guard category != "hangboard", category != "campus" else { return false }
            return Self.physicalCategoryKeys.contains(category)
        }
    }

    private var hasBlocksActivity: Bool {
        entries.contains { entry in
            entry.isBlock || Self.isBoulderCategory(entry.exercise.exerciseCategoryKeyForSemantics)
        }
    }

    private var hasTraverseActivity: Bool {
        entries.contains { entry in
            entry.isTraverse || Self.isTraverseCategory(entry.exercise.exerciseCategoryKeyForSemantics)
        }
    }

    private var hasHangboardActivity: Bool {
        entries.contains { $0.exercise.exerciseCategoryKeyForSemantics == "hangboard" }
    }

    private var hasCampusActivity: Bool {
        entries.contains { $0.exercise.exerciseCategoryKeyForSemantics == "campus" }
    }

    private static let physicalCategoryKeys: Set<String> = [
        "fuerza", "core", "movilidad", "resistencia", "calentamiento", "otros",
    ]

    static func displayCategoryLabel(for entry: WorkoutEntry) -> String? {
        if entry.isBlock { return "Bloques" }
        if entry.isTraverse { return "Travesía" }

        let categoryKey = entry.exercise.exerciseCategoryKeyForSemantics
        if isBoulderCategory(categoryKey) { return "Bloques" }
        if isTraverseCategory(categoryKey) { return "Travesía" }

        let label = entry.exercise.displayCategoryLabel
        return label.isEmpty ? nil : label
    }

    static func joinedSpanishList(_ items: [String]) -> String {
        switch items.count {
        case 0:
            return ""
        case 1:
            return items[0]
        case 2:
            return "\(items[0]) y \(items[1])"
        default:
            let head = items.dropLast().joined(separator: ", ")
            return "\(head) y \(items[items.count - 1])"
        }
    }

    private static func isBoulderCategory(_ key: String) -> Bool {
        key == "boulder" || key == "bloques" || key == "bloque"
    }

    private static func isTraverseCategory(_ key: String) -> Bool {
        key == "travesia" || key == "travesias"
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

    /// Clave estable para categoría (alias históricos → canónico interno).
    static func canonicalCategorySemanticKey(_ normalizedCategory: String) -> String {
        switch normalizedCategory {
        case "fuerza", "fuerza general": return "fuerza"
        case "resistencia", "acondicionamiento": return "resistencia"
        default: return normalizedCategory
        }
    }

    /// Clave estable para categoría.
    var exerciseCategoryKeyForSemantics: String {
        Self.canonicalCategorySemanticKey(Self.normalizedKeyForSemanticMatching(category))
    }

    /// Etiqueta de categoría para UI y estadísticas (no modifica `category` persistido).
    var displayCategoryLabel: String {
        if let standard = Self.displayLabel(forCategorySemanticKey: exerciseCategoryKeyForSemantics) {
            return standard
        }
        return category.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Mapeo clave semántica → nombre visible; `nil` si no hay etiqueta estándar.
    static func displayLabel(forCategorySemanticKey key: String) -> String? {
        if key == "boulder" || key == "bloques" || key == "bloque" { return "Bloques" }
        if key == "travesia" || key == "travesias" { return "Travesía" }
        switch key {
        case "hangboard": return "Hangboard"
        case "campus": return "Campus"
        case "fuerza": return "Fuerza general"
        case "core": return "Core"
        case "movilidad": return "Movilidad"
        case "resistencia": return "Acondicionamiento"
        case "calentamiento": return "Calentamiento"
        case "test": return "Test"
        case "otros": return "Otros"
        default: return nil
        }
    }

    /// Circuito fluido/técnico y nombres históricos “Vuelta …” (misma UX: un solo control de vueltas).
    var isCircuitStyleExercise: Bool {
        let k = exerciseNameKeyForSemantics
        return k == "circuito fluido"
            || k == "circuito tecnico"
            || k == "vuelta fluida"
            || k == "vuelta tecnica"
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

// MARK: - EarnedBadge

/// Logro desbloqueado una sola vez. No almacena contadores ni estadísticas derivadas.
@Model
final class EarnedBadge {
    /// Identificador estable del badge (`BadgeDefinition.id`).
    var badgeId: String
    /// Momento en que se concedió el logro.
    var earnedAt: Date
    /// Sesión que originó el desbloqueo.
    @Relationship(deleteRule: .nullify)
    var sourceWorkout: WorkoutDay?

    init(badgeId: String, earnedAt: Date = Date(), sourceWorkout: WorkoutDay? = nil) {
        self.badgeId = badgeId
        self.earnedAt = earnedAt
        self.sourceWorkout = sourceWorkout
    }
}

