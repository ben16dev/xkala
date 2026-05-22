import Foundation
import SwiftData

// MARK: - Catálogo (importación / reimportación determinista, no destructiva)
//
// Orden lógico de `upsertFromCatalogRows`:
// A. Normalizar filas del CSV
// B. Renombres canónicos en store (antes de upsert)
// C. (Implícito) Filas CSV + `ExerciseCatalog.renameMap` resuelven el mismo `Exercise` por nombre nuevo o alias
// D. Upsert de ejercicios desde el catálogo (incluye filas `Test de …` explícitas en el CSV)
// D2. Consolidar duplicados nombre antiguo / nombre nuevo del renameMap (reapuntar `WorkoutEntry`, archivar resto)
// F. Archivar legacy equivalente intermitentes 7/3 distinto del canónico
// G. Borrar o archivar legacy Hangboard retirado **solo** si sin `WorkoutEntry`
// H. Sin duplicados visibles: reactivación vía upsert; no se borran ejercicios con histórico

enum ExerciseImporter {

    // MARK: - Reglas de negocio (mantener aquí; ampliar con nuevas entradas)

    private enum CatalogCanonical {
        /// Ejercicio intermitentes unico visible en Hangboard (nombre y categoria persistidos).
        static let suspensionesIntermitentesName = "Suspensiones intermitentes"
        static let suspensionesIntermitentesCategory = "Hangboard"
        static let suspensionesIntermitentesNotes =
            "Registrar tiempo de ejercicio/descanso, numero de ciclos y numero rondas por ciclo"
        static let suspensionesIntermitentesMode = "seconds"
        static let suspensionesIntermitentesLoadAllowed = true
    }

    /// Variantes de fila CSV que se fusionan al canónico de intermitentes (no listado exhaustivo: la detección usa `matchesLegacyIntermittent73`).
    private enum CatalogLegacyIntermittent73 {
        static let mergedDisplayName = CatalogCanonical.suspensionesIntermitentesName
        static let mergedCategory = CatalogCanonical.suspensionesIntermitentesCategory
    }

    /// Hangboard retirados del catálogo: claves de nombre ya normalizadas con `catalogExerciseNameMatchKey`.
    private enum CatalogLegacyObsoleteHangboard {
        static let nameKeysToRemoveOrArchive: Set<String> = [
            "intermitentes 5/5",
            "suspensiones intermitentes 10/5 + lastre"
        ]
    }

    private enum CatalogRename {
        static let dominadasLastradasLegacyDisplay = "Dominadas lastradas"
        static let dominadasLastreNegativoDisplay = "Dominadas con lastre negativo"
        static let dominadasCategory = "Fuerza general"
    }

    // MARK: - Normalización (único sitio para matching robusto)

    /// Texto de celda CSV: trim + espacios colapsados.
    private static func normalizeCatalogField(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private static func normalizeCategoryKey(_ s: String) -> String {
        let normalized = normalizeCatalogField(s)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        return Exercise.canonicalCategorySemanticKey(normalized)
    }

    /// Clave de nombre para comparar ejercicios: trim, diacríticos, minúsculas, comillas y separadores `/` tolerantes.
    /// Sirve para alinear variantes tipo `7''/3''` vs `7"/3`.
    private static func catalogExerciseNameMatchKey(_ name: String) -> String {
        var k = normalizeCatalogField(name)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
        k = k.replacingOccurrences(of: "''", with: "")
        k = k.replacingOccurrences(of: "\"", with: "")
        k = k.replacingOccurrences(of: "'", with: "")
        k = k.replacingOccurrences(of: " / ", with: "/")
        k = k.replacingOccurrences(of: "/ ", with: "/")
        k = k.replacingOccurrences(of: " /", with: "/")
        return k
    }

    private static func normalizeMode(_ raw: String) -> String {
        let m = normalizeCatalogField(raw).lowercased()
        return (m == "seconds") ? "seconds" : "reps"
    }

    private static func normalizeBoolSiNo(_ raw: String) -> Bool {
        let v = normalizeCatalogField(raw).lowercased()
        return v == "si" || v == "sí" || v == "true" || v == "1"
    }

    // MARK: - Notas del catálogo (único punto de salida hacia `Exercise.notes` en importación)

    /// Solo prefijo inicial `Test:` (case-insensitive), tras normalizar campo.
    private static func stripLeadingTestPrefixFromNotes(_ raw: String) -> String {
        let collapsed = normalizeCatalogField(raw)
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else { return trimmed }
        let prefixEnd = trimmed.index(trimmed.startIndex, offsetBy: 5)
        if trimmed[..<prefixEnd].caseInsensitiveCompare("test:") == .orderedSame {
            return String(trimmed[prefixEnd...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    private static func isCanonicalSuspensionesIntermitentes(name: String, category: String) -> Bool {
        catalogExerciseNameMatchKey(name) == catalogExerciseNameMatchKey(CatalogCanonical.suspensionesIntermitentesName)
            && normalizeCategoryKey(category) == normalizeCategoryKey(CatalogCanonical.suspensionesIntermitentesCategory)
    }

    /// Resuelve notas definitivas para persistir en un ejercicio del catálogo (base o ya canónico).
    private static func resolvedCatalogNotes(
        canonicalName: String,
        canonicalCategory: String,
        rawNotesFromPayload: String
    ) -> String {
        if isCanonicalSuspensionesIntermitentes(name: canonicalName, category: canonicalCategory) {
            return CatalogCanonical.suspensionesIntermitentesNotes
        }
        return stripLeadingTestPrefixFromNotes(rawNotesFromPayload)
    }

    // MARK: - Filas CSV normalizadas (A)

    private struct NormalizedCatalogRow {
        let name: String
        let category: String
        let mode: String
        let loadAllowed: Bool
        let notes: String
    }

    private static func normalizedCatalogRows(from rows: [[String]]) -> [NormalizedCatalogRow] {
        var out: [NormalizedCatalogRow] = []
        out.reserveCapacity(rows.count)
        for row in rows {
            guard row.count >= 4 else { continue }
            let name = normalizeCatalogField(row[0])
            let category = normalizeCatalogField(row[1])
            let mode = normalizeMode(row[2])
            let loadAllowed = normalizeBoolSiNo(row[3])
            let notes = row.count >= 5 ? normalizeCatalogField(row[4]) : ""
            out.append(NormalizedCatalogRow(
                name: name,
                category: category,
                mode: mode,
                loadAllowed: loadAllowed,
                notes: notes
            ))
        }
        return out
    }

    // MARK: - Búsqueda y persistencia

    private static func fetchAllExercises(context: ModelContext) throws -> [Exercise] {
        try context.fetch(FetchDescriptor<Exercise>())
    }

    private static func fetchAllWorkoutEntries(context: ModelContext) throws -> [WorkoutEntry] {
        try context.fetch(FetchDescriptor<WorkoutEntry>())
    }

    private static func exerciseHasWorkoutEntries(_ exercise: Exercise, entries: [WorkoutEntry]) -> Bool {
        entries.contains { $0.exercise === exercise }
    }

    private static func findExercise(
        displayName: String,
        category: String,
        in exercises: [Exercise]
    ) -> Exercise? {
        let nameKey = catalogExerciseNameMatchKey(displayName)
        let categoryKey = normalizeCategoryKey(category)
        return exercises.first {
            catalogExerciseNameMatchKey($0.name) == nameKey
                && normalizeCategoryKey($0.category) == categoryKey
        }
    }

    private static func findExercise(
        displayName: String,
        category: String,
        context: ModelContext
    ) throws -> Exercise? {
        try findExercise(displayName: displayName, category: category, in: fetchAllExercises(context: context))
    }

    // MARK: - `ExerciseCatalog.renameMap` (alias → nombre CSV)

    /// Claves de nombre (`catalogExerciseNameMatchKey`) de aliases cuyo destino en el mapa coincide con el nombre de catálogo actual.
    private static func renameAliasNameKeys(forCanonicalCatalogName name: String) -> [String] {
        let targetKey = catalogExerciseNameMatchKey(name)
        return ExerciseCatalog.renameMap.compactMap { oldDisplay, newDisplay in
            catalogExerciseNameMatchKey(newDisplay) == targetKey
                ? catalogExerciseNameMatchKey(oldDisplay)
                : nil
        }
    }

    private static func pickPrimaryExerciseForMerge(candidates: [Exercise], entries: [WorkoutEntry]) -> Exercise {
        let sorted = candidates.sorted { a, b in
            let aHas = entries.contains { $0.exercise === a }
            let bHas = entries.contains { $0.exercise === b }
            if aHas != bHas { return aHas && !bHas }
            if a.isArchived != b.isArchived { return !a.isArchived && b.isArchived }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }
        return sorted[0]
    }

    /// Si hay varios `Exercise` bajo distintos aliases que colisionan en un único nombre de catálogo, unifica en uno y archiva el resto (sin borrar).
    private static func mergeExercisesIfNeeded(
        candidates: [Exercise],
        entries: [WorkoutEntry]
    ) -> Exercise {
        guard let first = candidates.first else {
            preconditionFailure("mergeExercisesIfNeeded requiere al menos un candidato")
        }
        guard candidates.count > 1 else { return first }

        let primary = pickPrimaryExerciseForMerge(candidates: candidates, entries: entries)
        for ex in candidates where ex !== primary {
            for entry in entries where entry.exercise === ex {
                entry.exercise = primary
            }
            ex.isArchived = true
        }
        return primary
    }

    /// Reapunta entradas desde ejercicios que siguen con nombre “antiguo” del mapa hacia uno que ya tiene el nombre nuevo, si ambos existen.
    private static func consolidateRenameMapDuplicates(context: ModelContext) throws {
        let all = try fetchAllExercises(context: context)
        let entries = try fetchAllWorkoutEntries(context: context)

        for (oldDisplay, newDisplay) in ExerciseCatalog.renameMap {
            let oldKey = catalogExerciseNameMatchKey(oldDisplay)
            let newKey = catalogExerciseNameMatchKey(newDisplay)
            let olds = all.filter { catalogExerciseNameMatchKey($0.name) == oldKey }
            let news = all.filter { catalogExerciseNameMatchKey($0.name) == newKey }
            guard !olds.isEmpty, !news.isEmpty else { continue }

            let primary = pickPrimaryExerciseForMerge(candidates: news, entries: entries)
            for o in olds where o !== primary {
                for entry in entries where entry.exercise === o {
                    entry.exercise = primary
                }
                o.isArchived = true
            }
        }
    }

    /// Fusiona fila CSV → payload persistible (canónico intermitentes 7/3, etc.).
    private static func canonicalPayloadFromCatalogRow(
        name: String,
        category: String,
        mode: String,
        loadAllowed: Bool,
        notes: String
    ) -> NormalizedCatalogRow {
        if matchesLegacyIntermittent73(name: name, category: category) {
            return NormalizedCatalogRow(
                name: CatalogLegacyIntermittent73.mergedDisplayName,
                category: CatalogLegacyIntermittent73.mergedCategory,
                mode: CatalogCanonical.suspensionesIntermitentesMode,
                loadAllowed: CatalogCanonical.suspensionesIntermitentesLoadAllowed,
                notes: notes
            )
        }
        return NormalizedCatalogRow(
            name: name,
            category: category,
            mode: mode,
            loadAllowed: loadAllowed,
            notes: notes
        )
    }

    private static func matchesLegacyIntermittent73(name: String, category: String) -> Bool {
        guard normalizeCategoryKey(category) == normalizeCategoryKey(CatalogCanonical.suspensionesIntermitentesCategory) else {
            return false
        }
        let key = catalogExerciseNameMatchKey(name)
        guard key.contains("suspensiones"), key.contains("intermitent") else { return false }
        let canonicalKey = catalogExerciseNameMatchKey(CatalogCanonical.suspensionesIntermitentesName)
        guard key != canonicalKey else { return false }
        return key.contains("7") && key.contains("3")
    }

    private static func upsertCatalogExercise(
        payload: NormalizedCatalogRow,
        context: ModelContext
    ) throws {
        let resolvedNotes = resolvedCatalogNotes(
            canonicalName: payload.name,
            canonicalCategory: payload.category,
            rawNotesFromPayload: payload.notes
        )

        let all = try fetchAllExercises(context: context)
        let entries = try fetchAllWorkoutEntries(context: context)

        var existing = findExercise(
            displayName: payload.name,
            category: payload.category,
            in: all
        )

        if existing == nil {
            let aliasKeys = renameAliasNameKeys(forCanonicalCatalogName: payload.name)
            var candidates: [Exercise] = []
            candidates.reserveCapacity(aliasKeys.count * 2)
            for key in aliasKeys {
                for ex in all where catalogExerciseNameMatchKey(ex.name) == key {
                    candidates.append(ex)
                }
            }
            var seen = Set<ObjectIdentifier>()
            let unique = candidates.filter { seen.insert(ObjectIdentifier($0)).inserted }
            if !unique.isEmpty {
                existing = mergeExercisesIfNeeded(candidates: unique, entries: entries)
            }
        }

        guard let resolvedExisting = existing else {
            let exercise = Exercise(
                name: payload.name,
                category: payload.category,
                mode: payload.mode,
                loadAllowed: payload.loadAllowed,
                notes: resolvedNotes
            )
            context.insert(exercise)
            return
        }

        resolvedExisting.name = payload.name
        resolvedExisting.category = payload.category
        resolvedExisting.mode = payload.mode
        resolvedExisting.loadAllowed = payload.loadAllowed
        resolvedExisting.notes = resolvedNotes
        if resolvedExisting.isArchived { resolvedExisting.isArchived = false }
    }

    /// Alta manual / API pública: misma resolución de canónico y notas; **no** ejecuta pasos F/G del catálogo completo.
    static func upsertExercise(
        name: String,
        category: String,
        mode: String,
        loadAllowed: Bool,
        notes: String,
        context: ModelContext
    ) throws {
        let row = NormalizedCatalogRow(
            name: normalizeCatalogField(name),
            category: normalizeCatalogField(category),
            mode: mode,
            loadAllowed: loadAllowed,
            notes: normalizeCatalogField(notes)
        )
        let payload = canonicalPayloadFromCatalogRow(
            name: row.name,
            category: row.category,
            mode: row.mode,
            loadAllowed: row.loadAllowed,
            notes: row.notes
        )
        try upsertCatalogExercise(payload: payload, context: context)
    }

    // MARK: - B — Renombres en store

    private static func applyDominadasLastradasRename(context: ModelContext) throws {
        let oldKey = catalogExerciseNameMatchKey(CatalogRename.dominadasLastradasLegacyDisplay)
        let newName = CatalogRename.dominadasLastreNegativoDisplay
        let newKey = catalogExerciseNameMatchKey(newName)
        let categoryKey = normalizeCategoryKey(CatalogRename.dominadasCategory)

        let all = try fetchAllExercises(context: context)
        let legacyMatches = all.filter {
            catalogExerciseNameMatchKey($0.name) == oldKey
                && normalizeCategoryKey($0.category) == categoryKey
        }
        guard !legacyMatches.isEmpty else { return }

        let newNameExists = all.contains {
            catalogExerciseNameMatchKey($0.name) == newKey
                && normalizeCategoryKey($0.category) == categoryKey
        }

        if newNameExists {
            for ex in legacyMatches { ex.isArchived = true }
            return
        }

        if let first = legacyMatches.first {
            first.name = newName
            first.isArchived = false
        }
        for ex in legacyMatches.dropFirst() {
            ex.isArchived = true
        }
    }

    // MARK: - F — Archivar legacy intermitentes 7/3

    private static func archiveLegacyIntermittent73Variants(context: ModelContext) throws {
        let all = try fetchAllExercises(context: context)
        for exercise in all {
            if matchesLegacyIntermittent73(name: exercise.name, category: exercise.category) {
                exercise.isArchived = true
            }
        }
    }

    // MARK: - G — Legacy Hangboard retirado: borrar si sin uso, si no archivar

    private static func matchesObsoleteHangboardCatalogExercise(name: String, category: String) -> Bool {
        guard normalizeCategoryKey(category) == normalizeCategoryKey(CatalogCanonical.suspensionesIntermitentesCategory) else {
            return false
        }
        let k = catalogExerciseNameMatchKey(name)
        return CatalogLegacyObsoleteHangboard.nameKeysToRemoveOrArchive.contains(k)
    }

    private static func pruneObsoleteHangboardCatalogExercises(context: ModelContext) throws {
        let exercises = try fetchAllExercises(context: context)
        let targets = exercises.filter { matchesObsoleteHangboardCatalogExercise(name: $0.name, category: $0.category) }
        guard !targets.isEmpty else { return }

        let entries = try fetchAllWorkoutEntries(context: context)
        for exercise in targets {
            if exerciseHasWorkoutEntries(exercise, entries: entries) {
                exercise.isArchived = true
            } else {
                context.delete(exercise)
            }
        }
    }

    // MARK: - Entrada principal (A → … → H)

    static func upsertFromCatalogRows(_ rows: [[String]], context: ModelContext) throws {
        // A — Normalizar filas
        let normalizedRows = normalizedCatalogRows(from: rows)

        // B — Renombres canónicos en store (antes del upsert por filas)
        try applyDominadasLastradasRename(context: context)

        // D — Upsert ejercicios (catálogo completo en CSV, incl. tests)
        for row in normalizedRows {
            let payload = canonicalPayloadFromCatalogRow(
                name: row.name,
                category: row.category,
                mode: row.mode,
                loadAllowed: row.loadAllowed,
                notes: row.notes
            )
            try upsertCatalogExercise(payload: payload, context: context)
        }

        // D2 — Colisiones nombre antiguo / nuevo tras importación
        try consolidateRenameMapDuplicates(context: context)

        // F — Archivar equivalentes legacy (7/3)
        try archiveLegacyIntermittent73Variants(context: context)

        // G — Retirados obsoletos Hangboard
        try pruneObsoleteHangboardCatalogExercises(context: context)

        // H — Duplicados visibles: los upserts reactivan solo filas del CSV; legacy permanece archivado.
    }
}
