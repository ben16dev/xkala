import Foundation
import SwiftData

enum WorkoutCSVImportExecutionError: LocalizedError {
    case exerciseNotResolved(String)

    var errorDescription: String? {
        switch self {
        case .exerciseNotResolved(let name):
            return "No se pudo resolver el ejercicio «\(name)» al guardar."
        }
    }
}

/// Marcador `[IMPORT:…]` en `WorkoutDay.notes`. Sin `@MainActor` para usarlo desde el modelo.
enum WorkoutImportBatchNotes {
    private static let importBatchTagPattern = #/\[IMPORT:([^\]]+)\]/#

    static func importBatchMarker(for batchId: String) -> String {
        "[IMPORT:\(batchId)]"
    }

    static func extractImportBatchId(from notes: String) -> String? {
        guard let match = notes.firstMatch(of: importBatchTagPattern) else { return nil }
        return String(match.1)
    }
}

/// Persistencia de filas ya validadas (parser + catálogo). No crea `Exercise`.
@MainActor
enum WorkoutCSVImportExecutor {

    static func makeImportBatchId() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }

    static func importBatchMarker(for batchId: String) -> String {
        WorkoutImportBatchNotes.importBatchMarker(for: batchId)
    }

    static func extractImportBatchId(from notes: String) -> String? {
        WorkoutImportBatchNotes.extractImportBatchId(from: notes)
    }

    /// `importBatchId` más reciente según timestamp ISO8601 embebido en `notes`.
    static func latestImportBatchId(in days: [WorkoutDay]) -> String? {
        let ids = days.compactMap { extractImportBatchId(from: $0.notes) }
        guard !ids.isEmpty else { return nil }
        return ids.max(by: { compareImportBatchIds($0, $1) == .orderedAscending })
    }

    static func workoutDays(forImportBatchId batchId: String, in days: [WorkoutDay]) -> [WorkoutDay] {
        let marker = importBatchMarker(for: batchId)
        return days.filter { $0.notes.contains(marker) }
    }

    /// Borra las sesiones de la última importación CSV. Devuelve cuántas se eliminaron.
    @discardableResult
    static func revertLastImport(days: [WorkoutDay], context: ModelContext) throws -> Int {
        guard let batchId = latestImportBatchId(in: days) else { return 0 }
        let toDelete = workoutDays(forImportBatchId: batchId, in: days)
        guard !toDelete.isEmpty else { return 0 }
        for day in toDelete {
            context.delete(day)
        }
        try context.save()
        return toDelete.count
    }

    private static func compareImportBatchIds(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let leftDate = formatter.date(from: lhs)
        let rightDate = formatter.date(from: rhs)
        switch (leftDate, rightDate) {
        case let (l?, r?):
            if l != r { return l < r ? .orderedAscending : .orderedDescending }
            return lhs.compare(rhs)
        case (.some, .none):
            return .orderedDescending
        case (.none, .some):
            return .orderedAscending
        case (.none, .none):
            return lhs.compare(rhs)
        }
    }

    /// Días (inicio de día local) en `rows` que ya tienen al menos un `WorkoutDay` guardado.
    static func conflictingImportDayKeys(rows: [WorkoutImportRow], existingDays: [WorkoutDay]) -> [Date] {
        let cal = Calendar.current
        let importKeys = Set(rows.map { cal.startOfDay(for: $0.date) })
        let existingKeys = Set(existingDays.map { cal.startOfDay(for: $0.date) })
        return importKeys.intersection(existingKeys).sorted()
    }

    static func run(rows: [WorkoutImportRow], exercises: [Exercise], context: ModelContext) throws {
        let exerciseMap = ImportExerciseCatalogValidator.exerciseByNormalizedName(exercises)
        let cal = Calendar.current
        let importBatchId = makeImportBatchId()
        let importMarker = importBatchMarker(for: importBatchId)

        var byDay: [Date: [WorkoutImportRow]] = [:]
        for row in rows {
            let key = cal.startOfDay(for: row.date)
            byDay[key, default: []].append(row)
        }

        let sortedDayKeys = byDay.keys.sorted()

        for dayKey in sortedDayKeys {
            var dayRows = byDay[dayKey] ?? []
            dayRows.sort {
                if $0.date != $1.date { return $0.date < $1.date }
                return $0.sourceLineNumber < $1.sourceLineNumber
            }

            let sessionDate = dayRows.first?.date ?? dayKey
            let sessionName =
                dayRows.first { !$0.workoutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }?
                .workoutName
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let day = WorkoutDay(date: sessionDate, name: sessionName, notes: importMarker, entries: [])
            context.insert(day)

            for row in dayRows {
                let key = ImportExerciseCatalogValidator.normalizedExerciseNameKey(row.exerciseName)
                guard let ex = exerciseMap[key] else {
                    throw WorkoutCSVImportExecutionError.exerciseNotResolved(row.exerciseName)
                }
                let setRecords = makeSetRecords(for: row, exercise: ex)
                let entry = WorkoutEntry(
                    exercise: ex,
                    intensity: row.intensity,
                    isDone: row.isDone,
                    entryNotes: row.entryNotes,
                    sets: setRecords
                )
                day.entries.append(entry)
            }
        }

        try context.save()
    }

    private static func makeSetRecords(for row: WorkoutImportRow, exercise: Exercise) -> [SetRecord] {
        let load: Double? = (exercise.loadAllowed ? row.loadKg : nil)
        var out: [SetRecord] = []
        out.reserveCapacity(row.sets)
        for _ in 0 ..< row.sets {
            switch exercise.modeEnum {
            case .reps:
                out.append(SetRecord(reps: row.value, seconds: nil, loadKg: load))
            case .seconds:
                out.append(SetRecord(reps: nil, seconds: row.value, loadKg: load))
            }
        }
        return out
    }
}
