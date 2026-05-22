import Foundation

struct WorkoutImportRow: Identifiable, Equatable {
    let id = UUID()
    /// Línea del archivo (1-based) de esta fila de datos.
    let sourceLineNumber: Int
    let date: Date
    let workoutName: String
    let exerciseName: String
    let intensity: Int
    let isDone: Bool
    let setType: String
    let sets: Int
    let value: Int
    let loadKg: Double?
    let entryNotes: String

    static func == (lhs: WorkoutImportRow, rhs: WorkoutImportRow) -> Bool {
        lhs.sourceLineNumber == rhs.sourceLineNumber
            && lhs.date == rhs.date
            && lhs.workoutName == rhs.workoutName
            && lhs.exerciseName == rhs.exerciseName
            && lhs.intensity == rhs.intensity
            && lhs.isDone == rhs.isDone
            && lhs.setType == rhs.setType
            && lhs.sets == rhs.sets
            && lhs.value == rhs.value
            && lhs.loadKg == rhs.loadKg
            && lhs.entryNotes == rhs.entryNotes
    }
}
