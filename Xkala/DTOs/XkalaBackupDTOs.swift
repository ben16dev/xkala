import Foundation

// MARK: - Raíz V2

struct XkalaBackupV2: Codable {
    var schemaVersion: Int
    var exportedAt: Date
    var appName: String
    var userProfile: UserProfileBackupDTO?
    var exercises: [ExerciseBackupDTO]
    var workoutDays: [WorkoutDayBackupDTO]
}

// MARK: - Perfil

struct UserProfileBackupDTO: Codable {
    var name: String
    var heightCm: Double?
    var weightKg: Double?
    var birthDate: Date?
    var gender: String
}

// MARK: - Ejercicio

struct ExerciseBackupDTO: Codable {
    var name: String
    var category: String
    var mode: String
    var loadAllowed: Bool
    var notes: String
    var isArchived: Bool
}

// MARK: - Sesión

struct WorkoutDayBackupDTO: Codable {
    var date: Date
    var startedAt: Date?
    var endedAt: Date?
    var name: String
    var notes: String
    var sessionType: String
    var durationMinutes: Int?
    var rpe: Int?
    var perceivedFatigue: Int?
    var fingerSensation: Int?
    var painNotes: String?
    var trainingMethodRawValue: String?
    var climbingData: ClimbingSessionDataBackupDTO?
    var entries: [WorkoutEntryBackupDTO]
}

// MARK: - Roca

struct ClimbingSessionDataBackupDTO: Codable {
    var location: String
    var sector: String
    var routesCount: Int
    var attemptedRoutesCount: Int
    var sentRoutesCount: Int
    var bestTriedGrade: String
    var bestSentGrade: String
    var grades: [String]
    var routes: [ClimbingRouteRecordBackupDTO]
}

struct ClimbingRouteRecordBackupDTO: Codable {
    var name: String
    var grade: String
    var isSent: Bool
}

// MARK: - Entry / Set

struct WorkoutEntryBackupDTO: Codable {
    var exerciseName: String
    var intensity: Int
    var isDone: Bool
    var entryNotes: String
    var climbKind: String?
    var climbIdentifier: String?
    var climbGradeColor: String?
    var climbSuccess: Bool?
    var sets: [SetRecordBackupDTO]
}

struct SetRecordBackupDTO: Codable {
    var reps: Int?
    var seconds: Int?
    var loadKg: Double?
}

// MARK: - Resúmenes de importación

struct XkalaBackupFileSummary {
    var exercises: Int
    var sessions: Int
    var entries: Int
    var sets: Int
}

struct XkalaBackupImportResult {
    var importedExercises: Int = 0
    var importedSessions: Int = 0
    var importedEntries: Int = 0
    var importedSets: Int = 0
    var skippedSessions: Int = 0
    var errors: [String] = []
}

enum XkalaBackupError: LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidFormat(String)
    case missingExercise(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let v):
            return "Versión de backup no compatible (\(v)). Solo se admite schemaVersion = 2."
        case .invalidFormat(let detail):
            return "El archivo no es un backup válido de Xkala: \(detail)"
        case .missingExercise(let name):
            return "No se encontró el ejercicio «\(name)» al restaurar una sesión."
        }
    }
}
