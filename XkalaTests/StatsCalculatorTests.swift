import XCTest
@testable import Xkala

@MainActor
final class StatsCalculatorTests: XCTestCase {

    private let day = Date(timeIntervalSince1970: 0)

    private func makeExercise(name: String, category: String = "Strength") -> Exercise {
        Exercise(name: name, category: category, mode: "reps", loadAllowed: false)
    }

    private func makeEntry(
        exercise: Exercise,
        isDone: Bool,
        climbSuccess: Bool? = nil
    ) -> WorkoutEntry {
        WorkoutEntry(
            exercise: exercise,
            isDone: isDone,
            sets: [SetRecord(reps: 5)],
            climbSuccess: climbSuccess
        )
    }

    func test_totalCompletedExercises_countsAllDoneEntriesRegardlessOfClimbSuccess() {
        let normal = makeEntry(exercise: makeExercise(name: "Pull-ups"), isDone: true)
        let blockFailed = makeEntry(
            exercise: makeExercise(name: "Bloque", category: "Climb"),
            isDone: true,
            climbSuccess: false
        )
        let blockSucceeded = makeEntry(
            exercise: makeExercise(name: "Bloque 2", category: "Climb"),
            isDone: true,
            climbSuccess: true
        )
        let workouts = [WorkoutDay(date: day, entries: [normal, blockFailed, blockSucceeded])]

        let snapshot = StatsCalculator.snapshot(from: workouts, now: day)

        XCTAssertEqual(snapshot.totalCompletedExercises, 3)
    }

    func test_totalCompletedExercises_excludesEntriesNotMarkedDone() {
        let done = makeEntry(exercise: makeExercise(name: "Pull-ups"), isDone: true)
        let pending = makeEntry(exercise: makeExercise(name: "Dips"), isDone: false, climbSuccess: true)
        let workouts = [WorkoutDay(date: day, entries: [done, pending])]

        let snapshot = StatsCalculator.snapshot(from: workouts, now: day)

        XCTAssertEqual(snapshot.totalCompletedExercises, 1)
    }

    func test_favoriteCategory_unifiesLegacyAndNewCategoryLabels() {
        let legacy = makeEntry(
            exercise: makeExercise(name: "Dominadas", category: "Fuerza"),
            isDone: true
        )
        let updated = makeEntry(
            exercise: makeExercise(name: "Press banca", category: "Fuerza general"),
            isDone: true
        )
        let workouts = [WorkoutDay(date: day, entries: [legacy, updated])]

        let snapshot = StatsCalculator.snapshot(from: workouts, now: day)

        XCTAssertEqual(snapshot.favoriteCategory, "Fuerza general")
    }
}
