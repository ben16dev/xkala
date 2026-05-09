import Foundation
import SwiftData

// MARK: - DTOs

struct ExportData: Codable {
    var workoutDays: [WorkoutDayDTO]
}

struct WorkoutDayDTO: Codable {
    var date: Date
    var notes: String
    var entries: [WorkoutEntryDTO]
}

struct WorkoutEntryDTO: Codable {
    var exerciseName: String
    var intensity: Int
    var isDone: Bool
    var entryNotes: String
    var sets: [SetRecordDTO]
}

struct SetRecordDTO: Codable {
    var reps: Int?
    var seconds: Int?
    var loadKg: Double?
}

// MARK: - Servicio

@MainActor
enum ExportService {
    static func export(context: ModelContext) throws -> Data {
        let descriptor = FetchDescriptor<WorkoutDay>(
            sortBy: [SortDescriptor(\WorkoutDay.date, order: .forward)]
        )

        let days = try context.fetch(descriptor)
        let root = ExportData(workoutDays: days.map(mapWorkoutDay))

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601

        return try encoder.encode(root)
    }

    /// Genera el JSON y lo guarda en `FileManager.default.temporaryDirectory/xkala_export.json` para compartir.
    static func exportTemporaryJSONFile(context: ModelContext) throws -> URL {
        let data = try export(context: context)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("xkala_export.json", isDirectory: false)
        try data.write(to: url, options: [.atomic])
        return url
    }

    private static func mapWorkoutDay(_ day: WorkoutDay) -> WorkoutDayDTO {
        WorkoutDayDTO(
            date: day.date,
            notes: day.notes,
            entries: day.entries.map(mapWorkoutEntry)
        )
    }

    private static func mapWorkoutEntry(_ entry: WorkoutEntry) -> WorkoutEntryDTO {
        WorkoutEntryDTO(
            exerciseName: entry.exercise.name,
            intensity: entry.intensity,
            isDone: entry.isDone,
            entryNotes: entry.entryNotes,
            sets: entry.sets.map(mapSetRecord)
        )
    }

    private static func mapSetRecord(_ set: SetRecord) -> SetRecordDTO {
        SetRecordDTO(
            reps: set.reps,
            seconds: set.seconds,
            loadKg: set.loadKg
        )
    }
}
