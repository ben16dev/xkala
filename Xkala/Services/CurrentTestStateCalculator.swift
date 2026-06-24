import Foundation

/// Calculadora pura para obtener el estado actual de Tests agrupado por capacidad física.
struct CurrentTestStateCalculator {
    
    static func snapshot(from workouts: [WorkoutDay]) -> CurrentTestStateSnapshot {
        // 1. Obtener todos los ejercicios Test únicos con datos
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
        
        // 3. Para cada capacidad, elegir el Test más reciente con datos válidos
        var results: [TestCapacity: CurrentTestStateSnapshot.TestCapacityResult] = [:]
        
        for (capacity, exercises) in capacityGroups {
            // Ordenar por fecha del último workout donde aparece cada Test
            let sorted = exercises.sorted { e1, e2 in
                let date1 = lastWorkoutDate(for: e1, in: workouts) ?? .distantPast
                let date2 = lastWorkoutDate(for: e2, in: workouts) ?? .distantPast
                return date1 > date2
            }
            
            // Tomar el primero con datos válidos
            for exercise in sorted {
                // Crear un entry temporal para calcular snapshot
                let entry = WorkoutEntry(exercise: exercise)
                let testSnapshot = TestResultCalculator.snapshot(for: entry, in: workouts)
                
                guard testSnapshot.hasData else { continue }
                
                results[capacity] = CurrentTestStateSnapshot.TestCapacityResult(
                    testName: exercise.name,
                    resultText: testSnapshot.lastResultText
                )
                break
            }
        }
        
        return CurrentTestStateSnapshot(resultsByCapacity: results)
    }
    
    // MARK: - Helpers
    
    private static func exerciseKey(_ exercise: Exercise) -> String {
        "\(exercise.name)|\(exercise.category)"
    }
    
    private static func lastWorkoutDate(for exercise: Exercise, in workouts: [WorkoutDay]) -> Date? {
        workouts
            .filter { workout in
                workout.entries.contains { entry in
                    entry.isDone && isSameExercise(entry, exercise: exercise)
                }
            }
            .map(\.date)
            .max()
    }
    
    private static func isSameExercise(_ entry: WorkoutEntry, exercise: Exercise) -> Bool {
        entry.exercise === exercise
            || (entry.exercise.name == exercise.name && entry.exercise.category == exercise.category)
    }
}
