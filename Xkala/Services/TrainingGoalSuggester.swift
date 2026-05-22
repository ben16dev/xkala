import Foundation

/// Sugerencia automática del objetivo de sesión a partir de ejercicios de la sesión.
/// Solo lectura; el usuario confirma o cambia en la UI.
enum TrainingGoalSuggester {

    private static let priority: [TrainingMethod] = [
        .strength,
        .explosive,
        .boulder,
        .continuity,
        .endurance,
        .mobilityCore
    ]

    static func suggest(for workout: WorkoutDay) -> TrainingMethod? {
        var detected = Set<TrainingMethod>()

        for entry in workout.entries {
            if let method = goalSignal(for: entry) {
                detected.insert(method)
            }
        }

        return priority.first { detected.contains($0) }
    }

    private static func goalSignal(for entry: WorkoutEntry) -> TrainingMethod? {
        if entry.isBlock { return .boulder }
        if entry.isTraverse { return .continuity }

        let category = entry.exercise.exerciseCategoryKeyForSemantics
        let name = entry.exercise.exerciseNameKeyForSemantics

        if category == "hangboard" || name.contains("suspension") {
            return .strength
        }
        if category == "campus" || name.contains("explosiv") {
            return .explosive
        }
        if category == "boulder" {
            return .boulder
        }
        if category == "resistencia" {
            return entry.exercise.isCircuitStyleExercise ? .continuity : .endurance
        }
        if category == "core" || category == "movilidad" {
            return .mobilityCore
        }

        return nil
    }
}
