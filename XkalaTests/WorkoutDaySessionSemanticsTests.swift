import XCTest
@testable import Xkala

final class WorkoutDaySessionSemanticsTests: XCTestCase {

    func testMixedSessionNameAndCategories() {
        let workout = WorkoutDay(entries: [
            makeEntry(name: "Dominadas", category: "Fuerza"),
            makeEntry(name: "Plancha", category: "Core"),
            makeBlockEntry(),
            makeEntry(name: "Suspensiones", category: "Hangboard"),
        ])

        XCTAssertEqual(workout.sessionKindName, "Físico, Bloques y Hangboard")
        XCTAssertEqual(
            workout.categoriesSummary,
            "Bloques · Core · Fuerza general · Hangboard"
        )
    }

    func testTraverseAndCampusName() {
        let workout = WorkoutDay(entries: [
            makeTraverseEntry(),
            makeEntry(name: "Campus dinámico", category: "Campus"),
        ])

        XCTAssertEqual(workout.sessionKindName, "Travesía y Campus")
        XCTAssertEqual(workout.categoriesSummary, "Campus · Travesía")
    }

    func testBlocksOnlyName() {
        let workout = WorkoutDay(entries: [makeBlockEntry()])
        XCTAssertEqual(workout.sessionKindName, "Bloques")
        XCTAssertEqual(workout.categoriesSummary, "Bloques")
    }

    func testHangboardOnlyName() {
        let workout = WorkoutDay(entries: [
            makeEntry(name: "Suspensiones", category: "Hangboard"),
        ])
        XCTAssertEqual(workout.sessionKindName, "Hangboard")
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
        workout.startSessionTimer(at: start)

        workout.finishSessionTimer(at: end)

        XCTAssertEqual(workout.endedAt, end)
        XCTAssertEqual(workout.startedAt, start)
        XCTAssertEqual(workout.date, start)
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

    func testApplyManualSessionDurationAnchorsToDate() {
        let workout = WorkoutDay()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        workout.date = base

        workout.applyManualSessionDuration(totalSeconds: 90 * 60)

        XCTAssertEqual(workout.startedAt, base)
        XCTAssertEqual(workout.endedAt, base.addingTimeInterval(90 * 60))
        XCTAssertEqual(workout.durationMinutes, 90)
    }

    func testApplyManualSessionDurationOnClosedSessionPreservesEndedAt() {
        let workout = WorkoutDay()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(45 * 60)
        workout.startSessionTimer(at: start)
        workout.finishSessionTimer(at: end)

        workout.applyManualSessionDuration(totalSeconds: 75 * 60)

        XCTAssertEqual(workout.endedAt, end)
        XCTAssertEqual(workout.startedAt, start)
        XCTAssertEqual(workout.durationMinutes, 75)
        XCTAssertEqual(workout.effectiveDurationMinutes, 75)
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

    func testClimbingAutoName_emptyDefaultsToSesionDeRoca() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        XCTAssertEqual(workout.climbingAutoGeneratedName, "Sesión de roca")
        XCTAssertEqual(workout.categoriesBasedName, "Sesión de roca")
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

    func testClimbingSync_doesNotUseBlockEntryName() {
        var workout = WorkoutDay(sessionType: "climbing", entries: [makeBlockEntry()])
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

    func testClimbingSync_updatesAfterStaleAutoNames() {
        var workout = WorkoutDay(sessionType: "climbing")
        workout.applySessionTypeConsistency()
        workout.syncAutoGeneratedSessionNameIfNeeded()
        XCTAssertEqual(workout.name, "Sesión de roca")

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
        XCTAssertEqual(workout.categoriesBasedName, "Bloques")
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
