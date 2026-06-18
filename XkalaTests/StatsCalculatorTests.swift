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
        climbKind: String? = nil,
        climbSuccess: Bool? = nil
    ) -> WorkoutEntry {
        WorkoutEntry(
            exercise: exercise,
            isDone: isDone,
            sets: [SetRecord(reps: 5)],
            climbKind: climbKind,
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

    func test_climbingStats_countsBlocksAndTraversesWithSuccessOnlyWhenExplicit() {
        let blockDone = makeEntry(
            exercise: makeExercise(name: "Bloque A", category: "Climb"),
            isDone: true,
            climbKind: "block",
            climbSuccess: true
        )
        let blockPending = makeEntry(
            exercise: makeExercise(name: "Bloque B", category: "Climb"),
            isDone: false,
            climbKind: "block",
            climbSuccess: nil
        )
        let blockFailed = makeEntry(
            exercise: makeExercise(name: "Bloque C", category: "Climb"),
            isDone: true,
            climbKind: "block",
            climbSuccess: false
        )
        let traverseDone = makeEntry(
            exercise: makeExercise(name: "Travesía A", category: "Climb"),
            isDone: true,
            climbKind: "traverse",
            climbSuccess: true
        )
        let traverseUnmarked = makeEntry(
            exercise: makeExercise(name: "Travesía B", category: "Climb"),
            isDone: true,
            climbKind: "traverse",
            climbSuccess: nil
        )
        let workouts = [
            WorkoutDay(
                date: day,
                entries: [blockDone, blockPending, blockFailed, traverseDone, traverseUnmarked]
            )
        ]

        let climbing = StatsCalculator.climbingStats(from: workouts)

        XCTAssertEqual(climbing?.blocksTotal, 3)
        XCTAssertEqual(climbing?.blocksSuccess, 1)
        XCTAssertEqual(climbing?.traversesTotal, 2)
        XCTAssertEqual(climbing?.traversesSuccess, 1)
        XCTAssertEqual(climbing?.blockSuccessRateText, "33%")
        XCTAssertEqual(climbing?.traverseSuccessRateText, "50%")
    }

    func test_climbingStats_successRates_nilWhenNoEntriesOfKind() {
        let blockOnly = makeEntry(
            exercise: makeExercise(name: "Bloque", category: "Climb"),
            isDone: true,
            climbKind: "block",
            climbSuccess: true
        )
        let climbing = StatsCalculator.climbingStats(from: [
            WorkoutDay(date: day, entries: [blockOnly])
        ])

        XCTAssertEqual(climbing?.blockSuccessRateText, "100%")
        XCTAssertNil(climbing?.traverseSuccessRateText)
    }

    func test_climbingStats_returnsNilWhenNoBlocksOrTraverses() {
        let normal = makeEntry(exercise: makeExercise(name: "Pull-ups"), isDone: true)
        let workouts = [WorkoutDay(date: day, entries: [normal])]

        XCTAssertNil(StatsCalculator.climbingStats(from: workouts))
        XCTAssertNil(StatsCalculator.snapshot(from: workouts, now: day).climbingStats)
    }

    func test_lastTrainingMethod_returnsMostRecentValidSessionWithObjective() {
        let older = WorkoutDay(date: day, entries: [])
        older.trainingMethod = .strength

        let newer = WorkoutDay(
            date: Date(timeIntervalSince1970: 86_400),
            entries: []
        )
        newer.trainingMethod = .recovery

        let method = StatsCalculator.lastTrainingMethod(
            workouts: [older, newer],
            now: Date(timeIntervalSince1970: 86_400)
        )

        XCTAssertEqual(method, .recovery)
    }

    func test_lastTrainingMethod_ignoresFutureSessions() {
        let past = WorkoutDay(date: day, entries: [])
        past.trainingMethod = .strength

        let future = WorkoutDay(
            date: Date(timeIntervalSince1970: 86_400),
            entries: []
        )
        future.trainingMethod = .boulder

        let method = StatsCalculator.lastTrainingMethod(
            workouts: [past, future],
            now: day
        )

        XCTAssertEqual(method, .strength)
    }

    func test_lastTrainingMethod_ignoresImportedSessions() {
        let imported = WorkoutDay(date: day, entries: [])
        imported.trainingMethod = .boulder
        imported.notes = WorkoutImportBatchNotes.importBatchMarker(for: "batch-1")

        let real = WorkoutDay(
            date: Date(timeIntervalSince1970: -86_400),
            entries: []
        )
        real.trainingMethod = .technique

        let method = StatsCalculator.lastTrainingMethod(
            workouts: [imported, real],
            now: day
        )

        XCTAssertEqual(method, .technique)
    }

    func test_lastTrainingMethod_returnsNilWhenNoObjectiveRegistered() {
        let withoutObjective = WorkoutDay(date: day, entries: [])
        let method = StatsCalculator.lastTrainingMethod(workouts: [withoutObjective], now: day)
        XCTAssertNil(method)
        XCTAssertEqual(
            StatsCalculator.snapshot(from: [withoutObjective], now: day).lastTrainingMethod?.displayName ?? "—",
            "—"
        )
    }
}
