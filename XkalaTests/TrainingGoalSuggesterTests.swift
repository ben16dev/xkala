import XCTest
@testable import Xkala

final class TrainingGoalSuggesterTests: XCTestCase {

    func testHangboardSuggestsStrength() {
        let workout = makeWorkout(
            exercises: [("Suspensiones libres", "Hangboard")]
        )
        XCTAssertEqual(TrainingGoalSuggester.suggest(for: workout), .strength)
    }

    func testCampusSuggestsExplosive() {
        let workout = makeWorkout(
            exercises: [("Campus dinámico", "Campus")]
        )
        XCTAssertEqual(TrainingGoalSuggester.suggest(for: workout), .explosive)
    }

    func testBlockEntrySuggestsBoulder() {
        let exercise = Exercise(name: "Bloque", category: "Boulder", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: exercise, climbKind: "block", climbIdentifier: "12")
        let workout = WorkoutDay(entries: [entry])
        XCTAssertEqual(TrainingGoalSuggester.suggest(for: workout), .boulder)
    }

    func testTraverseSuggestsContinuity() {
        let exercise = Exercise(name: "Travesía", category: "Resistencia", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: exercise, climbKind: "traverse", climbIdentifier: "A")
        let workout = WorkoutDay(entries: [entry])
        XCTAssertEqual(TrainingGoalSuggester.suggest(for: workout), .continuity)
    }

    func testAcondicionamientoCategoryAliasSuggestsEndurance() {
        let workout = makeWorkout(
            exercises: [("Dominadas asistidas", "Acondicionamiento")]
        )
        XCTAssertEqual(TrainingGoalSuggester.suggest(for: workout), .endurance)
    }

    func testCoreSuggestsMobilityCore() {
        let workout = makeWorkout(exercises: [("Plancha lateral", "Core")])
        XCTAssertEqual(TrainingGoalSuggester.suggest(for: workout), .mobilityCore)
    }

    func testEmptySessionReturnsNil() {
        let workout = WorkoutDay()
        XCTAssertNil(TrainingGoalSuggester.suggest(for: workout))
    }

    func testSessionLoadRequiresDurationAndRPE() {
        let workout = WorkoutDay()
        XCTAssertNil(workout.sessionLoad)

        workout.durationMinutes = 60
        XCTAssertNil(workout.sessionLoad)

        workout.rpe = 7
        XCTAssertEqual(workout.sessionLoad, 420)
    }

    func testSessionLoadNilWhenDurationZeroOrInvalidRPE() {
        let workout = WorkoutDay()
        workout.rpe = 5

        workout.durationMinutes = 0
        XCTAssertNil(workout.sessionLoad)

        workout.durationMinutes = -10
        XCTAssertNil(workout.sessionLoad)

        workout.durationMinutes = 30
        workout.rpe = 0
        XCTAssertNil(workout.sessionLoad)

        workout.rpe = 11
        XCTAssertNil(workout.sessionLoad)
    }

    func testNormalizePlanningScalarsClampsOutOfRange() {
        let workout = WorkoutDay()
        workout.rpe = 15
        workout.perceivedFatigue = 0
        workout.fingerSensation = 12
        workout.durationMinutes = -5
        workout.trainingMethodRawValue = "not_a_real_method"

        workout.normalizePlanningScalars()

        XCTAssertEqual(workout.rpe, 10)
        XCTAssertEqual(workout.perceivedFatigue, 1)
        XCTAssertEqual(workout.fingerSensation, 10)
        XCTAssertNil(workout.durationMinutes)
        XCTAssertNil(workout.trainingMethodRawValue)
    }

    func testSuggestionNeverWritesTrainingMethod() {
        let workout = makeWorkout(exercises: [("Campus básico", "Campus")])
        workout.trainingMethod = .recovery

        _ = TrainingGoalSuggester.suggest(for: workout)

        XCTAssertEqual(workout.trainingMethod, .recovery)
        XCTAssertEqual(workout.trainingMethodRawValue, TrainingMethod.recovery.rawValue)
    }

    private func makeWorkout(exercises: [(String, String)]) -> WorkoutDay {
        let entries = exercises.map { name, category in
            let ex = Exercise(name: name, category: category, mode: "reps", loadAllowed: false)
            return WorkoutEntry(exercise: ex)
        }
        return WorkoutDay(entries: entries)
    }
}
