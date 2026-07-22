import XCTest
@testable import Xkala

/// Reproduce el bug real: sesión visible en el calendario el 14/07/2026 con `now` = 22/07/2026
/// que debía mostrar inactividad (8 días) pero mostraba el insight de carga.
///
/// Ejercita la cadena usada por `StatsView`:
/// `[WorkoutDay] → realCompletedWorkouts → daysSinceLastRealSession → ActivityInsightResolver.resolve`.
@MainActor
final class ActivityInsightInactivityBugTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func daysSince(_ workouts: [WorkoutDay], now: Date) -> Int {
        let real = AvatarMoodResolver.realCompletedWorkouts(from: workouts, now: now, calendar: calendar)
        return AvatarMoodResolver.daysSinceLastRealSession(in: real, now: now, calendar: calendar)
    }

    private func insight(_ workouts: [WorkoutDay], now: Date) -> ActivityInsight? {
        ActivityInsightResolver.resolve(
            snapshot: .empty,
            daysSinceLastRealSession: daysSince(workouts, now: now)
        )
    }

    // 1 + 2: sesión real completada el 14/07 + now 22/07 → 8 días naturales e `.inactive(8)`.
    func test_realSessionOn14July_now22July_yields8DaysAndInactive() {
        let now = makeDate(2026, 7, 22, hour: 21)
        let session = WorkoutDay(date: makeDate(2026, 7, 14, hour: 19))
        session.durationMinutes = 60

        XCTAssertEqual(daysSince([session], now: now), 8)
        XCTAssertEqual(insight([session], now: now), .inactive(days: 8))
    }

    // Regresión del bug: sesión con `date` = 14/07 pero `endedAt` = 22/07 (cronómetro cerrado hoy).
    // Antes del fix se medía desde `endedAt` → 0 días → caía al insight de carga.
    func test_backdatedSessionFinishedToday_countsFromCalendarDate() {
        let now = makeDate(2026, 7, 22, hour: 21)
        let session = WorkoutDay(date: makeDate(2026, 7, 14, hour: 10))
        session.startedAt = makeDate(2026, 7, 22, hour: 19)
        session.endedAt = makeDate(2026, 7, 22, hour: 20)
        session.durationMinutes = 60
        session.rpe = 6

        XCTAssertEqual(daysSince([session], now: now), 8)
        XCTAssertEqual(insight([session], now: now), .inactive(days: 8))
    }

    // 3: sesión manual válida sin cronómetro cuenta como sesión real (semántica aprobada).
    func test_manualSessionWithoutTimer_countsAsReal() {
        let now = makeDate(2026, 7, 22, hour: 21)
        let session = WorkoutDay(date: makeDate(2026, 7, 14, hour: 8))
        session.durationMinutes = 45

        XCTAssertNil(session.startedAt)
        XCTAssertNil(session.endedAt)
        XCTAssertEqual(daysSince([session], now: now), 8)
        XCTAssertEqual(insight([session], now: now), .inactive(days: 8))
    }

    // 4: sesión abierta reciente no reinicia la inactividad.
    func test_recentOpenSession_doesNotResetInactivity() {
        let now = makeDate(2026, 7, 22, hour: 21)
        let real = WorkoutDay(date: makeDate(2026, 7, 14, hour: 19))
        real.durationMinutes = 60
        let open = WorkoutDay(date: makeDate(2026, 7, 22, hour: 18))
        open.startedAt = makeDate(2026, 7, 22, hour: 18)
        open.durationMinutes = 30

        XCTAssertEqual(daysSince([real, open], now: now), 8)
        XCTAssertEqual(insight([real, open], now: now), .inactive(days: 8))
    }

    // 5: sesión futura no reinicia la inactividad.
    func test_futureSession_doesNotResetInactivity() {
        let now = makeDate(2026, 7, 22, hour: 21)
        let real = WorkoutDay(date: makeDate(2026, 7, 14, hour: 19))
        real.durationMinutes = 60
        let future = WorkoutDay(date: makeDate(2026, 7, 25, hour: 10))
        future.durationMinutes = 60

        XCTAssertEqual(daysSince([real, future], now: now), 8)
        XCTAssertEqual(insight([real, future], now: now), .inactive(days: 8))
    }

    // 6: sesión importada no reinicia la inactividad (regla vigente).
    func test_importedSession_doesNotResetInactivity() {
        let now = makeDate(2026, 7, 22, hour: 21)
        let real = WorkoutDay(date: makeDate(2026, 7, 14, hour: 19))
        real.durationMinutes = 60
        let imported = WorkoutDay(date: makeDate(2026, 7, 21, hour: 12))
        imported.durationMinutes = 60
        imported.notes = WorkoutImportBatchNotes.importBatchMarker(for: "batch-1")

        XCTAssertEqual(daysSince([real, imported], now: now), 8)
        XCTAssertEqual(insight([real, imported], now: now), .inactive(days: 8))
    }

    // 7: ninguna sesión real (solo importada) → Int.max, sin mensaje de inactividad inválido.
    func test_noRealSessions_returnsIntMaxAndNoInsight() {
        let now = makeDate(2026, 7, 22, hour: 21)
        let imported = WorkoutDay(date: makeDate(2026, 7, 14, hour: 19))
        imported.durationMinutes = 60
        imported.notes = WorkoutImportBatchNotes.importBatchMarker(for: "batch-1")

        XCTAssertEqual(daysSince([imported], now: now), Int.max)
        XCTAssertNil(insight([imported], now: now))
    }
}
