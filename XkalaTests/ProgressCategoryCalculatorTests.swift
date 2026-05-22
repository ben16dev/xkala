import XCTest
@testable import Xkala

@MainActor
final class ProgressCategoryCalculatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeExercise(name: String, category: String) -> Exercise {
        Exercise(name: name, category: category, mode: "reps", loadAllowed: false)
    }

    private func makeEntry(exercise: Exercise, isDone: Bool) -> WorkoutEntry {
        WorkoutEntry(exercise: exercise, isDone: isDone, sets: [SetRecord(reps: 5, seconds: nil, loadKg: nil)])
    }

    func test_countsOnlyCompletedEntries_byCategory() {
        let fuerza = makeExercise(name: "Dominadas", category: "Fuerza general")
        let recuperacion = makeExercise(name: "Estiramientos", category: "Recuperación")

        let workout = WorkoutDay(
            date: now,
            name: "",
            notes: "",
            entries: [
                makeEntry(exercise: fuerza, isDone: true),
                makeEntry(exercise: recuperacion, isDone: true),
                makeEntry(exercise: fuerza, isDone: false)
            ]
        )

        let snapshot = ProgressCategoryCalculator.snapshot(
            from: [workout],
            range: .sevenDays,
            now: now
        )

        XCTAssertTrue(snapshot.hasAnyData)
        XCTAssertEqual(snapshot.series.count, 2)

        let fuerzaSeries = snapshot.series.first { $0.displayName == "Fuerza general" }
        let recuperacionSeries = snapshot.series.first { $0.displayName == "Recuperación" }
        XCTAssertEqual(fuerzaSeries?.totalInRange, 1)
        XCTAssertEqual(recuperacionSeries?.totalInRange, 1)
    }

    func test_emptyWhenNoCompletedEntries() {
        let exercise = makeExercise(name: "Test", category: "Técnica")
        let workout = WorkoutDay(
            date: now,
            name: "",
            notes: "",
            entries: [makeEntry(exercise: exercise, isDone: false)]
        )

        let snapshot = ProgressCategoryCalculator.snapshot(
            from: [workout],
            range: .sevenDays,
            now: now
        )

        XCTAssertFalse(snapshot.hasAnyData)
        XCTAssertTrue(snapshot.series.isEmpty)
        XCTAssertTrue(ProgressCategoryCalculator.allCategoryOptions(from: [workout]).isEmpty)
    }

    func test_bucketsReturnZerosWhenNoActivityInRange() {
        let exercise = makeExercise(name: "Dominadas", category: "Fuerza general")
        let oldDate = Date(timeIntervalSince1970: 0)
        let workout = WorkoutDay(
            date: oldDate,
            name: "",
            notes: "",
            entries: [makeEntry(exercise: exercise, isDone: true)]
        )

        let options = ProgressCategoryCalculator.allCategoryOptions(from: [workout])
        XCTAssertEqual(options.count, 1)

        let buckets = ProgressCategoryCalculator.buckets(
            forCategoryKey: options[0].id,
            from: [workout],
            range: .sevenDays,
            now: now
        )

        XCTAssertFalse(buckets.isEmpty)
        XCTAssertTrue(buckets.allSatisfy { $0.completedCount == 0 })
    }
}
