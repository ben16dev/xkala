import XCTest
@testable import Xkala

// NOTA: el target Xkala tiene SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor,
// por lo que los @Model y los métodos del calculator se infieren @MainActor.
// Marcar la clase @MainActor evita warnings/errores de concurrencia en el target de tests.
@MainActor
final class ExerciseProgressCalculatorTests: XCTestCase {

    // MARK: - Fechas fijas para controlar orden cronológico

    private let dayOld  = Date(timeIntervalSince1970: 0)
    private let dayNew  = Date(timeIntervalSince1970: 86_400)

    // MARK: - Helpers

    private func makeExercise(
        name: String = "Pull-ups",
        category: String = "Strength",
        mode: String = "reps",
        loadAllowed: Bool = false
    ) -> Exercise {
        Exercise(name: name, category: category, mode: mode, loadAllowed: loadAllowed)
    }

    /// Crea un WorkoutEntry con un único set. isDone = true por defecto.
    private func makeEntry(
        exercise: Exercise,
        reps: Int? = nil,
        seconds: Int? = nil,
        loadKg: Double? = nil,
        isDone: Bool = true
    ) -> WorkoutEntry {
        let set = SetRecord(reps: reps, seconds: seconds, loadKg: loadKg)
        return WorkoutEntry(exercise: exercise, isDone: isDone, sets: [set])
    }

    private func makeWorkout(date: Date, entries: [WorkoutEntry]) -> WorkoutDay {
        WorkoutDay(date: date, entries: entries)
    }

    // MARK: - Tests

    /// Sesión única → "Primera sesión registrada" + "🔥 mejor marca"
    func test_snapshot_singleSession_showsFirstSessionAndBestMark() {
        // Arrange
        let exercise = makeExercise()
        let entry    = makeEntry(exercise: exercise, reps: 10)
        let workouts = [makeWorkout(date: dayOld, entries: [entry])]

        // Act
        let snapshot = ExerciseProgressCalculator.snapshot(for: exercise, in: workouts)

        // Assert
        XCTAssertTrue(snapshot.hasEnoughData)
        XCTAssertEqual(snapshot.comparisonText, "Primera sesión registrada")
        XCTAssertEqual(snapshot.vsBestText, "🔥 mejor marca")
    }

    /// Última sesión 9 reps, mejor histórico 10 reps → ratio 0.9 ≥ 0.9 → "cerca de tu mejor"
    func test_snapshot_repsWithoutLoad_closeToBest() {
        // Arrange
        let exercise = makeExercise()
        let older    = makeEntry(exercise: exercise, reps: 10)
        let newer    = makeEntry(exercise: exercise, reps: 9)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        // Act
        let snapshot = ExerciseProgressCalculator.snapshot(for: exercise, in: workouts)

        // Assert
        XCTAssertEqual(snapshot.vsBestText, "cerca de tu mejor")
    }

    /// Última sesión 6 reps, mejor histórico 10 reps → ratio 0.6 < 0.9 → "por debajo de tu mejor"
    func test_snapshot_repsWithoutLoad_belowBest() {
        // Arrange
        let exercise = makeExercise()
        let older    = makeEntry(exercise: exercise, reps: 10)
        let newer    = makeEntry(exercise: exercise, reps: 6)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        // Act
        let snapshot = ExerciseProgressCalculator.snapshot(for: exercise, in: workouts)

        // Assert
        XCTAssertEqual(snapshot.vsBestText, "por debajo de tu mejor")
    }

    /// Con carga: mejor histórico 10 reps @ +20 kg, última sesión 12 reps @ +10 kg.
    /// compare prioriza loadKg → +10 kg < +20 kg → última es peor → "por debajo de tu mejor".
    func test_snapshot_withLoad_notEqualBest_isBelowBest() {
        // Arrange
        let exercise = makeExercise(loadAllowed: true)
        let older    = makeEntry(exercise: exercise, reps: 10, loadKg: 20)
        let newer    = makeEntry(exercise: exercise, reps: 12, loadKg: 10)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        // Act
        let snapshot = ExerciseProgressCalculator.snapshot(for: exercise, in: workouts)

        // Assert
        XCTAssertEqual(snapshot.vsBestText, "por debajo de tu mejor")
    }

    /// Entrada no completada (isDone = false) no cuenta.
    /// Solo la entrada válida genera sesión → comportamiento de sesión única.
    func test_snapshot_ignoresNotDoneEntries() {
        // Arrange
        let exercise = makeExercise()
        let notDone  = makeEntry(exercise: exercise, reps: 20, isDone: false)
        let done     = makeEntry(exercise: exercise, reps: 10, isDone: true)
        let workouts = [
            makeWorkout(date: dayOld, entries: [notDone]),
            makeWorkout(date: dayNew, entries: [done]),
        ]

        // Act
        let snapshot = ExerciseProgressCalculator.snapshot(for: exercise, in: workouts)

        // Assert: solo la entrada válida cuenta → sesión única
        XCTAssertEqual(snapshot.comparisonText, "Primera sesión registrada")
        XCTAssertEqual(snapshot.vsBestText, "🔥 mejor marca")
    }

    /// Set con `seconds` en un ejercicio mode=reps es inválido → sin sesiones → sin datos.
    func test_snapshot_ignoresInvalidSetsForMode() {
        // Arrange
        let exercise = makeExercise(mode: "reps")
        let entry    = makeEntry(exercise: exercise, reps: nil, seconds: 60)
        let workouts = [makeWorkout(date: dayOld, entries: [entry])]

        // Act
        let snapshot = ExerciseProgressCalculator.snapshot(for: exercise, in: workouts)

        // Assert
        XCTAssertFalse(snapshot.hasEnoughData)
        XCTAssertEqual(snapshot.comparisonText, "Sin datos suficientes")
        XCTAssertEqual(snapshot.vsBestText, "")
    }

    // MARK: - Gráfico de evolución (derivado)

    func test_progressChart_twoSessions_reps_chronologicalAndValues() {
        let exercise = makeExercise()
        let older = makeEntry(exercise: exercise, reps: 8)
        let newer = makeEntry(exercise: exercise, reps: 12)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        let model = ExerciseProgressCalculator.progressChartModel(for: newer, in: workouts)

        XCTAssertEqual(model.points.count, 2)
        XCTAssertEqual(model.points[0].date, dayOld)
        XCTAssertEqual(model.points[1].date, dayNew)
        XCTAssertEqual(model.points[0].value, 8)
        XCTAssertEqual(model.points[1].value, 12)
        XCTAssertEqual(model.yAxisTitle, "Reps")
        XCTAssertFalse(model.lowerIsBetter)
        XCTAssertEqual(model.bestInSeries, 12)
    }

    func test_progressChart_loadPrioritizedOnYAxis() {
        let exercise = makeExercise(loadAllowed: true)
        let older = makeEntry(exercise: exercise, reps: 10, loadKg: 10)
        let newer = makeEntry(exercise: exercise, reps: 20, loadKg: 15)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        let model = ExerciseProgressCalculator.progressChartModel(for: newer, in: workouts)

        XCTAssertEqual(model.points.map(\.value), [10, 15])
        XCTAssertEqual(model.yAxisTitle, "Carga (kg)")
        XCTAssertEqual(model.bestInSeries, 15)
    }

    /// Sin carga efectiva (0 kg): mismo criterio que `compare` — se usa la métrica base (reps).
    func test_progressChart_loadAllowedButZeroFallsBackToReps() {
        let exercise = makeExercise(loadAllowed: true)
        let older = makeEntry(exercise: exercise, reps: 8, loadKg: 0)
        let newer = makeEntry(exercise: exercise, reps: 12, loadKg: 0)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        let model = ExerciseProgressCalculator.progressChartModel(for: newer, in: workouts)

        XCTAssertEqual(model.points.map(\.value), [8, 12])
        XCTAssertEqual(model.yAxisTitle, "Reps")
    }

    func test_progressChart_secondsMode() {
        let exercise = makeExercise(mode: "seconds")
        let older = makeEntry(exercise: exercise, seconds: 60)
        let newer = makeEntry(exercise: exercise, seconds: 90)
        let workouts = [
            makeWorkout(date: dayOld, entries: [older]),
            makeWorkout(date: dayNew, entries: [newer]),
        ]

        let model = ExerciseProgressCalculator.progressChartModel(for: newer, in: workouts)

        XCTAssertEqual(model.points.map(\.value), [60, 90])
        XCTAssertEqual(model.yAxisTitle, "Segundos")
    }

    func test_progressChart_ignoresNotDoneEntries() {
        let exercise = makeExercise()
        let notDone = makeEntry(exercise: exercise, reps: 99, isDone: false)
        let done = makeEntry(exercise: exercise, reps: 5, isDone: true)
        let workouts = [
            makeWorkout(date: dayOld, entries: [notDone]),
            makeWorkout(date: dayNew, entries: [done]),
        ]

        let model = ExerciseProgressCalculator.progressChartModel(for: done, in: workouts)

        XCTAssertEqual(model.points.count, 1)
        XCTAssertEqual(model.points[0].value, 5)
    }
}
