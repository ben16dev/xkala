import XCTest
@testable import Xkala

@MainActor
final class TestResultCalculatorTests: XCTestCase {

    private let dayOld = Date(timeIntervalSince1970: 0)
    private let dayMid = Date(timeIntervalSince1970: 86_400)
    private let dayNew = Date(timeIntervalSince1970: 172_800)

    // MARK: - Helpers

    private func makeExercise(
        name: String,
        category: String = "Test",
        mode: String = "reps",
        loadAllowed: Bool = false
    ) -> Exercise {
        Exercise(name: name, category: category, mode: mode, loadAllowed: loadAllowed)
    }

    private func makeEntry(
        exercise: Exercise,
        reps: Int? = nil,
        seconds: Int? = nil,
        loadKg: Double? = nil,
        isDone: Bool = true,
        extraSets: [SetRecord] = []
    ) -> WorkoutEntry {
        var sets = [SetRecord(reps: reps, seconds: seconds, loadKg: loadKg)]
        sets.append(contentsOf: extraSets)
        return WorkoutEntry(exercise: exercise, isDone: isDone, sets: sets)
    }

    private func makeWorkout(date: Date, entries: [WorkoutEntry]) -> WorkoutDay {
        WorkoutDay(date: date, entries: entries)
    }

    // MARK: - Vacío / inválidos

    func test_snapshot_noCompletedSessions_isEmpty() {
        let exercise = makeExercise(name: "Test de dominadas libres")
        let entry = makeEntry(exercise: exercise, reps: 10, isDone: false)
        let workouts = [makeWorkout(date: dayNew, entries: [entry])]

        let snapshot = TestResultCalculator.snapshot(for: entry, in: workouts)

        XCTAssertFalse(snapshot.hasData)
        XCTAssertEqual(snapshot.lastResultText, "")
        XCTAssertEqual(snapshot.bestResultText, "")
        XCTAssertEqual(snapshot.deltaText, "")
        XCTAssertNil(snapshot.lastResultDate)
    }

    func test_snapshot_zeroReps_isExcluded() {
        let exercise = makeExercise(name: "Test de dominadas libres")
        let entry = makeEntry(exercise: exercise, reps: 0)
        let workouts = [makeWorkout(date: dayNew, entries: [entry])]

        let snapshot = TestResultCalculator.snapshot(for: entry, in: workouts)

        XCTAssertFalse(snapshot.hasData)
        XCTAssertNil(snapshot.lastResultDate)
    }

    // MARK: - Último / mejor / delta (reps sin carga)

    func test_snapshot_repsWithoutLoad_lastBestAndDelta() {
        let exercise = makeExercise(name: "Test de dominadas libres")
        let older = makeEntry(exercise: exercise, reps: 15)
        let newer = makeEntry(exercise: exercise, reps: 20)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        let snapshot = TestResultCalculator.snapshot(for: newer, in: workouts)

        XCTAssertTrue(snapshot.hasData)
        XCTAssertEqual(snapshot.lastResultText, "20 reps")
        XCTAssertEqual(snapshot.bestResultText, "20 reps")
        XCTAssertEqual(snapshot.deltaText, "↑ +5 reps")
        XCTAssertTrue(snapshot.isImproving)
        XCTAssertEqual(snapshot.lastResultDate, dayNew)
    }

    func test_snapshot_repsWithoutLoad_bestIsHistoricalWhenLastIsWorse() {
        let exercise = makeExercise(name: "Test de dominadas libres")
        let older = makeEntry(exercise: exercise, reps: 22)
        let newer = makeEntry(exercise: exercise, reps: 18)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        let snapshot = TestResultCalculator.snapshot(for: newer, in: workouts)

        XCTAssertEqual(snapshot.lastResultText, "18 reps")
        XCTAssertEqual(snapshot.bestResultText, "22 reps")
        XCTAssertEqual(snapshot.deltaText, "↓ -4 reps")
        XCTAssertFalse(snapshot.isImproving)
    }

    func test_snapshot_singleSession_hasNoDelta() {
        let exercise = makeExercise(name: "Test de dominadas libres")
        let entry = makeEntry(exercise: exercise, reps: 12)
        let workouts = [makeWorkout(date: dayNew, entries: [entry])]

        let snapshot = TestResultCalculator.snapshot(for: entry, in: workouts)

        XCTAssertEqual(snapshot.lastResultText, "12 reps")
        XCTAssertEqual(snapshot.bestResultText, "12 reps")
        XCTAssertEqual(snapshot.deltaText, "")
        XCTAssertFalse(snapshot.isImproving)
        XCTAssertEqual(snapshot.lastResultDate, dayNew)
    }

    // MARK: - Desempates con carga (reps)

    func test_snapshot_repsWithLoad_prefersHigherLoadThenHigherReps() {
        let exercise = makeExercise(name: "Test de dominadas con lastre", loadAllowed: true)
        let entry = makeEntry(
            exercise: exercise,
            reps: 5,
            loadKg: 20,
            extraSets: [
                SetRecord(reps: 3, loadKg: 25),
                SetRecord(reps: 4, loadKg: 25),
            ]
        )
        let workouts = [makeWorkout(date: dayNew, entries: [entry])]

        let snapshot = TestResultCalculator.snapshot(for: entry, in: workouts)

        // Mejor set: +25 kg × 4 reps (misma carga, más reps)
        XCTAssertEqual(snapshot.lastResultText, "+25 kg × 4 reps")
        XCTAssertEqual(snapshot.bestResultText, "+25 kg × 4 reps")
    }

    func test_snapshot_repsWithLoad_deltaPrefersLoadChange() {
        let exercise = makeExercise(name: "Test de dominadas con lastre", loadAllowed: true)
        let older = makeEntry(exercise: exercise, reps: 3, loadKg: 20)
        let newer = makeEntry(exercise: exercise, reps: 2, loadKg: 25)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        let snapshot = TestResultCalculator.snapshot(for: newer, in: workouts)

        XCTAssertEqual(snapshot.lastResultText, "+25 kg × 2 reps")
        XCTAssertEqual(snapshot.deltaText, "↑ +5 kg")
        XCTAssertTrue(snapshot.isImproving)
    }

    // MARK: - Seconds con carga

    func test_snapshot_secondsWithLoad_lastBestAndFormat() {
        let exercise = makeExercise(
            name: "Test de hangboard con lastre",
            mode: "seconds",
            loadAllowed: true
        )
        let older = makeEntry(exercise: exercise, seconds: 40, loadKg: 10)
        let newer = makeEntry(exercise: exercise, seconds: 50, loadKg: 18)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        let snapshot = TestResultCalculator.snapshot(for: newer, in: workouts)

        XCTAssertEqual(snapshot.lastResultText, "+18 kg · 50 s")
        XCTAssertEqual(snapshot.bestResultText, "+18 kg · 50 s")
        XCTAssertEqual(snapshot.deltaText, "↑ +8 kg")
        XCTAssertTrue(snapshot.isImproving)
        XCTAssertEqual(snapshot.lastResultDate, dayNew)
    }

    func test_snapshot_secondsWithoutLoad_tieBreakUsesDuration() {
        let exercise = makeExercise(
            name: "Test de hangboard peso negativo",
            mode: "seconds",
            loadAllowed: false
        )
        let entry = makeEntry(
            exercise: exercise,
            seconds: 30,
            extraSets: [SetRecord(seconds: 55)]
        )
        let workouts = [makeWorkout(date: dayNew, entries: [entry])]

        let snapshot = TestResultCalculator.snapshot(for: entry, in: workouts)

        XCTAssertEqual(snapshot.lastResultText, "55 s")
        XCTAssertEqual(snapshot.bestResultText, "55 s")
    }

    // MARK: - Intermitente (categoría Hangboard para activar semántica)

    func test_snapshot_intermittent_prefersLoadThenRoundsThenTime() {
        let exercise = makeExercise(
            name: "Test de Suspensiones intermitentes",
            category: "Hangboard",
            mode: "seconds",
            loadAllowed: true
        )
        XCTAssertTrue(exercise.isIntermittentHangboardExercise)

        let entry = makeEntry(
            exercise: exercise,
            reps: 6,
            seconds: 7,
            loadKg: 5,
            extraSets: [
                SetRecord(reps: 8, seconds: 7, loadKg: 5),
                SetRecord(reps: 5, seconds: 7, loadKg: 8),
            ]
        )
        let workouts = [makeWorkout(date: dayNew, entries: [entry])]

        let snapshot = TestResultCalculator.snapshot(for: entry, in: workouts)

        // Mejor: mayor carga (+8 kg), aunque menos rondas
        XCTAssertEqual(snapshot.lastResultText, "5 rondas · 7 s @ +8 kg")
    }

    func test_snapshot_intermittent_invalidWithoutRoundsOrTime_isExcluded() {
        let exercise = makeExercise(
            name: "Test de Suspensiones intermitentes",
            category: "Hangboard",
            mode: "seconds",
            loadAllowed: true
        )
        let entry = makeEntry(exercise: exercise, reps: 0, seconds: 7, loadKg: 5)
        let workouts = [makeWorkout(date: dayNew, entries: [entry])]

        let snapshot = TestResultCalculator.snapshot(for: entry, in: workouts)

        XCTAssertFalse(snapshot.hasData)
    }
}
