import Foundation

/// Calculadora pura para obtener el estado actual de Tests agrupado por capacidad física.
struct CurrentTestStateCalculator {

    static func snapshot(from workouts: [WorkoutDay]) -> CurrentTestStateSnapshot {
        // 1. Obtener todos los ejercicios Test únicos con entradas completadas
        var testExercises: [Exercise] = []
        var seenIds = Set<String>()

        for workout in workouts {
            for entry in workout.entries where entry.isDone {
                let exercise = entry.exercise
                guard exercise.isTestExercise else { continue }

                let key = exerciseKey(exercise)
                guard !seenIds.contains(key) else { continue }
                seenIds.insert(key)
                testExercises.append(exercise)
            }
        }

        guard !testExercises.isEmpty else { return .empty }

        // 2. Agrupar por capacidad
        var capacityGroups: [TestCapacity: [Exercise]] = [:]
        for exercise in testExercises {
            let capacity = exercise.testCapacity
            capacityGroups[capacity, default: []].append(exercise)
        }

        // 3. Por capacidad: el Test con resultado válido más reciente
        var results: [TestCapacity: CurrentTestStateSnapshot.TestCapacityResult] = [:]

        for (capacity, exercises) in capacityGroups {
            var best: (
                name: String,
                resultText: String,
                date: Date
            )?

            for exercise in exercises {
                let entry = WorkoutEntry(exercise: exercise)
                let testSnapshot = TestResultCalculator.snapshot(for: entry, in: workouts)
                guard testSnapshot.hasData, let lastDate = testSnapshot.lastResultDate else { continue }

                if let current = best {
                    if lastDate > current.date {
                        best = (exercise.name, testSnapshot.lastResultText, lastDate)
                    }
                } else {
                    best = (exercise.name, testSnapshot.lastResultText, lastDate)
                }
            }

            if let best {
                results[capacity] = CurrentTestStateSnapshot.TestCapacityResult(
                    testName: best.name,
                    resultText: best.resultText,
                    lastTestDate: best.date
                )
            }
        }

        return CurrentTestStateSnapshot(resultsByCapacity: results)
    }

    // MARK: - Helpers

    private static func exerciseKey(_ exercise: Exercise) -> String {
        "\(exercise.name)|\(exercise.category)"
    }
}
