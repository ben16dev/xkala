import XCTest
@testable import Xkala

final class WorkoutDaySessionSemanticsTests: XCTestCase {

    func testTrainingSessionDefaultNameIsEntrenamiento() {
        let workout = WorkoutDay(entries: [
            makeEntry(name: "Dominadas", category: "Fuerza"),
            makeEntry(name: "Plancha", category: "Core"),
        ])

        XCTAssertEqual(workout.sessionKindName, "Entrenamiento")
        XCTAssertTrue(workout.isAutoDefaultSessionName)
    }

    func testTrainingSessionWithBlocksIsEntrenamiento() {
        let workout = WorkoutDay(entries: [makeBlockEntry()])
        XCTAssertEqual(workout.sessionKindName, "Entrenamiento")
        XCTAssertEqual(workout.categoriesSummary, "Bloques")
    }

    func testTrainingSessionWithHangboardIsEntrenamiento() {
        let workout = WorkoutDay(entries: [
            makeEntry(name: "Suspensiones", category: "Hangboard"),
        ])
        XCTAssertEqual(workout.sessionKindName, "Entrenamiento")
    }

    func testDurationSyncFromSessionTimer() {
        let workout = WorkoutDay()
        let start = Date()
        workout.startedAt = start
        workout.endedAt = start.addingTimeInterval(90 * 60)

        workout.syncDurationMinutesFromSessionTimer()

        XCTAssertEqual(workout.durationMinutes, 90)
        XCTAssertEqual(workout.effectiveDurationMinutes, 90)
    }

    func testDurationSyncDoesNotClearLegacyMinutesWithoutTimer() {
        let workout = WorkoutDay()
        workout.durationMinutes = 45

        workout.syncDurationMinutesFromSessionTimer()

        XCTAssertEqual(workout.durationMinutes, 45)
    }

    func testFinishSessionTimerBackfillsStartDateAndDuration() {
        let workout = WorkoutDay()
        let end = Date(timeIntervalSince1970: 1_700_000_000)
        let start = end.addingTimeInterval(-75 * 60)
        let preservedDate = Date(timeIntervalSince1970: 1_600_000_000)
        workout.date = preservedDate
        workout.startSessionTimer(at: start)

        workout.finishSessionTimer(at: end)

        XCTAssertEqual(workout.endedAt, end)
        XCTAssertEqual(workout.startedAt, start)
        XCTAssertEqual(workout.date, preservedDate)
        XCTAssertEqual(workout.durationMinutes, 75)
        XCTAssertEqual(SessionTimeFormatter.seconds(from: workout), 75 * 60)
    }

    func testFinishSessionTimerNoOpWithoutActiveTimer() {
        let workout = WorkoutDay()
        let legacyDate = Date(timeIntervalSince1970: 1_600_000_000)
        workout.date = legacyDate
        workout.durationMinutes = 45

        workout.finishSessionTimer(at: Date())

        XCTAssertNil(workout.startedAt)
        XCTAssertNil(workout.endedAt)
        XCTAssertEqual(workout.date, legacyDate)
        XCTAssertEqual(workout.durationMinutes, 45)
    }

    func testFinishSessionTimerNoOpWhenAlreadyFinished() {
        let workout = WorkoutDay()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)
        workout.startedAt = start
        workout.endedAt = end
        workout.date = start

        workout.finishSessionTimer(at: end.addingTimeInterval(999))

        XCTAssertEqual(workout.endedAt, end)
        XCTAssertEqual(workout.startedAt, start)
    }

    func testApplyManualSessionDurationWithoutTimerPersistsMinutesOnly() {
        let workout = WorkoutDay()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        workout.date = base

        workout.applyManualSessionDuration(totalSeconds: 90 * 60)

        XCTAssertNil(workout.startedAt)
        XCTAssertNil(workout.endedAt)
        XCTAssertEqual(workout.durationMinutes, 90)
    }

    func testApplyManualSessionDurationOnClosedSessionRecalculatesStartedAtPreservesDate() {
        let workout = WorkoutDay()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(45 * 60)
        let preservedDate = Date(timeIntervalSince1970: 1_600_000_000)
        workout.date = preservedDate
        workout.startSessionTimer(at: start)
        workout.finishSessionTimer(at: end)

        workout.applyManualSessionDuration(totalSeconds: 75 * 60)

        let expectedStart = end.addingTimeInterval(-75 * 60)
        XCTAssertEqual(workout.endedAt, end)
        XCTAssertEqual(workout.startedAt, expectedStart)
        XCTAssertEqual(workout.date, preservedDate)
        XCTAssertEqual(workout.durationMinutes, 75)
        XCTAssertEqual(workout.effectiveDurationMinutes, 75)
        XCTAssertEqual(SessionTimeFormatter.seconds(from: workout), 75 * 60)
        XCTAssertEqual(workout.sessionDisplaySeconds, 75 * 60)
    }

    func testApplyManualSessionDurationOnActiveTimerDoesNotChangeDatesOrDisplay() {
        let workout = WorkoutDay()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        workout.startSessionTimer(at: start)
        workout.date = start
        let liveSecondsBefore = SessionTimeFormatter.seconds(
            from: workout,
            referenceEnd: start.addingTimeInterval(10 * 60)
        )

        workout.applyManualSessionDuration(totalSeconds: 75 * 60)

        XCTAssertEqual(workout.startedAt, start)
        XCTAssertNil(workout.endedAt)
        XCTAssertEqual(workout.date, start)
        XCTAssertNil(workout.durationMinutes)
        let liveSecondsAfter = SessionTimeFormatter.seconds(
            from: workout,
            referenceEnd: start.addingTimeInterval(10 * 60)
        )
        XCTAssertEqual(liveSecondsAfter, liveSecondsBefore)
        XCTAssertEqual(liveSecondsAfter, 10 * 60)
    }

    func testSyncDurationDoesNotOverwriteManualMinutesOnClosedSession() {
        let workout = WorkoutDay()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(45 * 60)
        workout.startedAt = start
        workout.endedAt = end
        workout.durationMinutes = 75

        workout.syncDurationMinutesFromSessionTimer()

        XCTAssertEqual(workout.durationMinutes, 75)
        XCTAssertEqual(workout.effectiveDurationMinutes, 75)
    }

    func testClimbingAutoName_emptyDefaultsToSesionDeCuerda() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        XCTAssertEqual(workout.climbingAutoGeneratedName, "Sesión de cuerda")
        XCTAssertEqual(workout.categoriesBasedName, "Sesión de cuerda")
    }

    func testClimbingAutoName_locationOnly() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        workout.climbingData?.location = "  Patones  "
        XCTAssertEqual(workout.climbingAutoGeneratedName, "Patones")
    }

    func testClimbingAutoName_locationAndSector() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        workout.climbingData?.location = "Patones"
        workout.climbingData?.sector = "Pontón de la Oliva"
        XCTAssertEqual(workout.climbingAutoGeneratedName, "Patones · Pontón de la Oliva")
    }

    func testClimbingAutoName_sectorOnly() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        workout.climbingData?.sector = "El Polvorín"
        XCTAssertEqual(workout.climbingAutoGeneratedName, "El Polvorín")
    }

    func testSessionIconsUseRopeForClimbingAndShoesForTraining() {
        XCTAssertEqual(WorkoutDay(sessionType: "climbing").sessionIcon, "iconRope")
        XCTAssertEqual(WorkoutDay(sessionType: "training").sessionIcon, "iconClimbingShoes")
    }

    func testClimbingSync_doesNotUseBlockEntryName() {
        var workout = WorkoutDay(entries: [makeBlockEntry()], sessionType: "climbing")
        workout.applySessionTypeConsistency()
        workout.climbingData?.location = "Patones"
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Patones")
        XCTAssertNotEqual(workout.name, "Bloques")
    }

    func testClimbingSync_respectsManualName() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        workout.name = "Salida con Juan"
        workout.climbingData?.location = "Patones"
        workout.climbingData?.sector = "Sector Sur"
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Salida con Juan")
    }

    func testClimbingSync_updatesWhenStillDefault() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        workout.name = "Sesión de roca"
        workout.climbingData?.location = "Patones"
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Patones")
        workout.climbingData?.sector = "La Maliciosa"
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Patones · La Maliciosa")
    }

    func testClimbingSync_legacySesionDeRocaIsStillAutoDefault() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        workout.name = "Sesión de roca"

        XCTAssertTrue(workout.isAutoDefaultSessionName)
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Sesión de cuerda")
    }

    func testClimbingSync_updatesAfterStaleAutoNames() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Sesión de cuerda")

        workout.climbingData?.location = "Patones"
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Patones")

        workout.climbingData?.sector = "Pontón"
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Patones · Pontón")

        workout.climbingData?.location = "Torrelodones"
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Torrelodones · Pontón")

        workout.climbingData?.sector = "Placa del Emilio"
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Torrelodones · Placa del Emilio")
    }

    func testClimbingSync_staleCompoundNameIsStillAuto() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        workout.name = "Patones · Pontón"
        workout.climbingData?.location = "Torrelodones"
        workout.climbingData?.sector = "Pontón"
        XCTAssertTrue(workout.isAutoDefaultSessionName)
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Torrelodones · Pontón")
    }

    func testTrainingCategoriesBasedName_unchanged() {
        let workout = WorkoutDay(entries: [makeBlockEntry()])
        XCTAssertEqual(workout.categoriesBasedName, "Entrenamiento")
    }

    func testJoinedSpanishList() {
        XCTAssertEqual(
            WorkoutDay.joinedSpanishList(["Físico", "Bloques", "Hangboard"]),
            "Físico, Bloques y Hangboard"
        )
        XCTAssertEqual(
            WorkoutDay.joinedSpanishList(["Travesía", "Campus"]),
            "Travesía y Campus"
        )
    }

    // MARK: - Test exercise naming

    func testCompletedTestInTrainingNamesSessionAsTestDeEntrenamiento() {
        let testExercise = Exercise(
            name: "Test de dominadas libres",
            category: "Test",
            mode: "reps",
            loadAllowed: false
        )
        let testEntry = WorkoutEntry(exercise: testExercise, isDone: true)
        let workout = WorkoutDay(entries: [testEntry])

        XCTAssertEqual(workout.sessionKindName, "Test de entrenamiento")
        XCTAssertTrue(workout.isAutoDefaultSessionName)
    }

    func testCompletedTestWithOtherExercisesIsTestDeEntrenamiento() {
        let testExercise = Exercise(
            name: "Test de bloque max",
            category: "Test",
            mode: "reps",
            loadAllowed: false
        )
        let testEntry = WorkoutEntry(exercise: testExercise, isDone: true)
        let campusEntry = makeEntry(name: "Campus dinámico", category: "Campus")
        let workout = WorkoutDay(entries: [testEntry, campusEntry])

        XCTAssertEqual(workout.sessionKindName, "Test de entrenamiento")
    }

    func testIncompleteTestDoesNotChangeTrainingName() {
        let testExercise = Exercise(
            name: "Test de suspensiones",
            category: "Test",
            mode: "seconds",
            loadAllowed: false
        )
        let testEntry = WorkoutEntry(exercise: testExercise, isDone: false)
        let campusEntry = makeEntry(name: "Campus", category: "Campus")
        let workout = WorkoutDay(entries: [testEntry, campusEntry])

        XCTAssertEqual(workout.sessionKindName, "Entrenamiento")
    }

    func testRemovingCompletedTestReturnsNameToEntrenamiento() {
        let testExercise = Exercise(
            name: "Test de fuerza",
            category: "Test",
            mode: "reps",
            loadAllowed: false
        )
        let testEntry = WorkoutEntry(exercise: testExercise, isDone: true)
        var workout = WorkoutDay(entries: [testEntry])

        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Test de entrenamiento")

        workout.entries.removeAll()
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Entrenamiento")
    }

    func testManualNameIsNotOverwritten() {
        let testExercise = Exercise(
            name: "Test de fuerza",
            category: "Test",
            mode: "reps",
            loadAllowed: false
        )
        let testEntry = WorkoutEntry(exercise: testExercise, isDone: true)
        var workout = WorkoutDay(entries: [testEntry])

        workout.name = "Sesión especial"
        workout.syncAutoGeneratedSessionNameIfNeeded()

        XCTAssertEqual(workout.name, "Sesión especial")
        XCTAssertFalse(workout.isAutoDefaultSessionName)
    }

    // MARK: - Helpers

    private func makeEntry(name: String, category: String) -> WorkoutEntry {
        let exercise = Exercise(name: name, category: category, mode: "reps", loadAllowed: false)
        return WorkoutEntry(exercise: exercise)
    }

    private func makeBlockEntry() -> WorkoutEntry {
        let exercise = Exercise(name: "Bloque", category: "Boulder", mode: "reps", loadAllowed: false)
        return WorkoutEntry(exercise: exercise, climbKind: "block", climbIdentifier: "12")
    }

    private func makeTraverseEntry() -> WorkoutEntry {
        let exercise = Exercise(name: "Travesía", category: "Resistencia", mode: "reps", loadAllowed: false)
        return WorkoutEntry(exercise: exercise, climbKind: "traverse", climbIdentifier: "A")
    }
}
