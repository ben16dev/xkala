import XCTest
@testable import Xkala

/// Integración de la cadena real de inactividad:
/// `[WorkoutDay] → realCompletedWorkouts → daysSinceLastRealSession → ActivityInsightResolver.resolve`.
///
/// Cubre la causa raíz del bug percibido: la inactividad depende de "sesión real completada",
/// que exige `effectiveDurationMinutes > 0` y excluye sesiones abiertas, importadas y futuras.
@MainActor
final class ActivityInsightInactivityIntegrationTests: XCTestCase {

    private let calendar = Calendar.current

    /// Sesión real: manual sin cronómetro pero con duración registrada (cuenta como real).
    private func makeManualRealSession(daysAgo: Int, now: Date, durationMinutes: Int = 60) -> WorkoutDay {
        let dayStart = calendar.startOfDay(for: now)
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: dayStart) ?? dayStart
        let workout = WorkoutDay(date: date)
        workout.durationMinutes = durationMinutes
        return workout
    }

    private func resolvedInsight(for workouts: [WorkoutDay], now: Date) -> ActivityInsight? {
        let real = AvatarMoodResolver.realCompletedWorkouts(from: workouts, now: now, calendar: calendar)
        let days = AvatarMoodResolver.daysSinceLastRealSession(in: real, now: now, calendar: calendar)
        return ActivityInsightResolver.resolve(snapshot: .empty, daysSinceLastRealSession: days)
    }

    // MARK: - Umbral exacto y superior

    func test_lastRealSessionExactly7DaysAgo_returnsInactive7() {
        let now = Date()
        let workouts = [makeManualRealSession(daysAgo: 7, now: now)]

        let real = AvatarMoodResolver.realCompletedWorkouts(from: workouts, now: now, calendar: calendar)
        let days = AvatarMoodResolver.daysSinceLastRealSession(in: real, now: now, calendar: calendar)

        XCTAssertEqual(days, 7)
        XCTAssertEqual(
            ActivityInsightResolver.resolve(snapshot: .empty, daysSinceLastRealSession: days),
            .inactive(days: 7)
        )
    }

    func test_lastRealSessionMoreThan7DaysAgo_returnsInactive() {
        let now = Date()
        let workouts = [makeManualRealSession(daysAgo: 12, now: now)]

        XCTAssertEqual(resolvedInsight(for: workouts, now: now), .inactive(days: 12))
    }

    // MARK: - Sesiones que NO deben reiniciar la inactividad

    func test_recentOpenSession_doesNotResetInactivity() {
        let now = Date()
        let openRecent = WorkoutDay(date: now)
        openRecent.startedAt = now
        openRecent.endedAt = nil // cronómetro en curso → no es sesión real

        let workouts = [makeManualRealSession(daysAgo: 10, now: now), openRecent]

        XCTAssertEqual(resolvedInsight(for: workouts, now: now), .inactive(days: 10))
    }

    func test_recentImportedSession_doesNotResetInactivity() {
        let now = Date()
        let importedRecent = WorkoutDay(date: now)
        importedRecent.durationMinutes = 60
        importedRecent.notes = WorkoutImportBatchNotes.importBatchMarker(for: "batch-1")

        let workouts = [makeManualRealSession(daysAgo: 10, now: now), importedRecent]

        XCTAssertEqual(resolvedInsight(for: workouts, now: now), .inactive(days: 10))
    }

    func test_futureSession_doesNotResetInactivity() {
        let now = Date()
        let futureDate = calendar.date(byAdding: .day, value: 3, to: now) ?? now
        let future = WorkoutDay(date: futureDate)
        future.durationMinutes = 60

        let workouts = [makeManualRealSession(daysAgo: 10, now: now), future]

        XCTAssertEqual(resolvedInsight(for: workouts, now: now), .inactive(days: 10))
    }

    // MARK: - Ausencia de sesiones reales (Int.max) no produce mensaje inválido

    func test_noRealSessions_returnsNilNotInvalidMessage() {
        let now = Date()
        let openOnly = WorkoutDay(date: now)
        openOnly.startedAt = now
        openOnly.endedAt = nil

        let real = AvatarMoodResolver.realCompletedWorkouts(from: [openOnly], now: now, calendar: calendar)
        let days = AvatarMoodResolver.daysSinceLastRealSession(in: real, now: now, calendar: calendar)

        XCTAssertEqual(days, Int.max)
        XCTAssertNil(ActivityInsightResolver.resolve(snapshot: .empty, daysSinceLastRealSession: days))
    }

    func test_emptyWorkouts_returnsNil() {
        let now = Date()
        XCTAssertNil(resolvedInsight(for: [], now: now))
    }

    // MARK: - Causa raíz del bug percibido

    /// Documenta la semántica actual: una sesión manual SIN duración registrada no es "real",
    /// por lo que no ancla la inactividad. Es la causa habitual de que el aviso no aparezca.
    func test_manualSessionWithoutDuration_isNotRealSession() {
        let now = Date()
        let noDuration = makeManualRealSession(daysAgo: 8, now: now, durationMinutes: 0)
        noDuration.durationMinutes = nil // sin cronómetro y sin minutos → no real

        let real = AvatarMoodResolver.realCompletedWorkouts(from: [noDuration], now: now, calendar: calendar)
        let days = AvatarMoodResolver.daysSinceLastRealSession(in: real, now: now, calendar: calendar)

        XCTAssertTrue(real.isEmpty)
        XCTAssertEqual(days, Int.max)
        XCTAssertNil(ActivityInsightResolver.resolve(snapshot: .empty, daysSinceLastRealSession: days))
    }

    /// Confirma que una sesión manual válida SIN cronómetro pero CON duración sí cuenta como real.
    func test_manualSessionWithDurationWithoutTimer_isRealSession() {
        let now = Date()
        let workouts = [makeManualRealSession(daysAgo: 8, now: now, durationMinutes: 45)]

        XCTAssertEqual(resolvedInsight(for: workouts, now: now), .inactive(days: 8))
    }
}
