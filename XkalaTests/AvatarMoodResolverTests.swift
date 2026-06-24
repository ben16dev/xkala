import XCTest
@testable import Xkala

@MainActor
final class AvatarMoodResolverTests: XCTestCase {

    private var calendar: Calendar!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = cal
    }

    // MARK: - Helpers

    private func makeExercise(name: String = "Dominadas") -> Exercise {
        Exercise(name: name, category: "Fuerza", mode: "reps", loadAllowed: false)
    }

    private func makeEntry(exercise: Exercise, reps: Int, isDone: Bool = true) -> WorkoutEntry {
        WorkoutEntry(exercise: exercise, isDone: isDone, sets: [SetRecord(reps: reps)])
    }

    private func makeRealWorkout(
        on dayOffset: Int,
        durationMinutes: Int = 60,
        rpe: Int = 7,
        entries: [WorkoutEntry],
        notes: String = ""
    ) -> WorkoutDay {
        let dayStart = calendar.startOfDay(for: now)
        let date = calendar.date(byAdding: .day, value: dayOffset, to: dayStart)!
        let workout = WorkoutDay(date: date, notes: notes, entries: entries)
        workout.startedAt = date
        workout.endedAt = calendar.date(byAdding: .minute, value: durationMinutes, to: date)
        workout.durationMinutes = durationMinutes
        workout.rpe = rpe
        return workout
    }

    private func mood(for workouts: [WorkoutDay], at date: Date? = nil) -> AvatarMood {
        AvatarMoodResolver.mood(for: workouts, now: date ?? now, calendar: calendar)
    }

    // MARK: - Tests

    func test_sessionTodayOverSixtyMinutes_yieldsStrong() {
        let today = makeRealWorkout(
            on: 0,
            durationMinutes: 61,
            entries: [makeEntry(exercise: makeExercise(), reps: 8)]
        )

        XCTAssertEqual(mood(for: [today]), .strong)
    }

    func test_manualDurationOverSixtyMinutesToday_yieldsStrong() {
        let today = makeRealWorkout(
            on: 0,
            durationMinutes: 75,
            entries: [makeEntry(exercise: makeExercise(), reps: 8)]
        )

        XCTAssertEqual(today.effectiveDurationMinutes, 75)
        XCTAssertEqual(mood(for: [today]), .strong)
    }

    func test_timerDurationUnderSixtyButManualDurationOverSixty_yieldsStrong() {
        let today = makeRealWorkout(
            on: 0,
            durationMinutes: 45,
            entries: [makeEntry(exercise: makeExercise(), reps: 8)]
        )
        today.durationMinutes = 75

        XCTAssertEqual(SessionTimeFormatter.seconds(from: today), 45 * 60)
        XCTAssertEqual(today.effectiveDurationMinutes, 75)
        XCTAssertEqual(mood(for: [today]), .strong)
    }

    func test_climbingSessionTodayOverSixtyMinutes_yieldsStrong() {
        let today = makeRealWorkout(
            on: 0,
            durationMinutes: 61,
            entries: []
        )
        today.sessionType = WorkoutDay.SessionType.climbing.rawValue

        XCTAssertEqual(mood(for: [today]), .strong)
    }

    func test_isRealCompletedWorkout_excludesWhenEndedAtAfterEvaluationNow() {
        let today = makeRealWorkout(
            on: 0,
            durationMinutes: 61,
            entries: []
        )
        today.sessionType = WorkoutDay.SessionType.climbing.rawValue
        guard let endedAt = today.endedAt else {
            return XCTFail("endedAt esperado")
        }
        let beforeSessionEnd = endedAt.addingTimeInterval(-60)

        XCTAssertFalse(
            AvatarMoodResolver.isRealCompletedWorkout(today, now: beforeSessionEnd, calendar: calendar)
        )
    }

    func test_twoSessionsInLastThreeDaysPlusToday_yieldsStrong() {
        let today = makeRealWorkout(on: 0, durationMinutes: 45, entries: [makeEntry(exercise: makeExercise(), reps: 8)])
        let yesterday = makeRealWorkout(on: -1, durationMinutes: 45, entries: [makeEntry(exercise: makeExercise(name: "A"), reps: 8)])

        XCTAssertEqual(mood(for: [today, yesterday]), .strong)
    }

    func test_strongRetainedForTwentyFourHours() {
        let today = makeRealWorkout(
            on: 0,
            durationMinutes: 90,
            entries: [makeEntry(exercise: makeExercise(), reps: 10)]
        )
        let signal = AvatarMoodResolver.sessionReferenceDate(today)
        let at12h = signal.addingTimeInterval(12 * 3600)
        let at25h = signal.addingTimeInterval(25 * 3600)

        XCTAssertEqual(mood(for: [today], at: at12h), .strong)
        XCTAssertNotEqual(mood(for: [today], at: at25h), .strong)
    }

    func test_twoSessionsInLastSevenDays_yieldsHappy() {
        let w1 = makeRealWorkout(on: -2, entries: [makeEntry(exercise: makeExercise(), reps: 8)])
        let w2 = makeRealWorkout(on: -5, entries: [makeEntry(exercise: makeExercise(name: "B"), reps: 9)])

        XCTAssertEqual(mood(for: [w1, w2]), .happy)
    }

    func test_atLeastFourDaysWithoutTraining_yieldsTired() {
        let last = makeRealWorkout(on: -4, entries: [makeEntry(exercise: makeExercise(), reps: 8)])

        XCTAssertEqual(mood(for: [last]), .tired)
    }

    func test_singleRecentSession_yieldsIdle() {
        let only = makeRealWorkout(on: -2, entries: [makeEntry(exercise: makeExercise(), reps: 8)])

        XCTAssertEqual(mood(for: [only]), .idle)
    }

    func test_futurePlannedSession_doesNotChangeMood() {
        let past = makeRealWorkout(on: -2, entries: [makeEntry(exercise: makeExercise(), reps: 8)])
        let future = WorkoutDay(
            date: calendar.date(byAdding: .day, value: 3, to: now)!,
            entries: [makeEntry(exercise: makeExercise(name: "Plan"), reps: 10)]
        )
        future.rpe = 8
        future.durationMinutes = 90

        XCTAssertEqual(mood(for: [past]), .idle)
        XCTAssertEqual(mood(for: [past, future]), .idle)
    }

    func test_importedSession_doesNotCount() {
        let imported = makeRealWorkout(
            on: -1,
            entries: [makeEntry(exercise: makeExercise(), reps: 10)],
            notes: WorkoutImportBatchNotes.importBatchMarker(for: "batch-1")
        )
        let real = makeRealWorkout(on: -3, entries: [makeEntry(exercise: makeExercise(), reps: 8)])

        XCTAssertEqual(mood(for: [imported, real]), .idle)
    }

    func test_manualDurationOnlyWithoutTimer_countsForMoodStrong() {
        let today = WorkoutDay(date: now, entries: [makeEntry(exercise: makeExercise(), reps: 8)])
        today.durationMinutes = 75

        XCTAssertNil(today.startedAt)
        XCTAssertNil(today.endedAt)
        XCTAssertTrue(AvatarMoodResolver.isRealCompletedWorkout(today, now: now, calendar: calendar))
        XCTAssertEqual(mood(for: [today]), .strong)
    }

    func test_runningTimerSession_doesNotCountAsRealCompletedWorkout() {
        let open = WorkoutDay(
            date: calendar.date(byAdding: .day, value: -1, to: now)!,
            entries: [makeEntry(exercise: makeExercise(), reps: 10)]
        )
        open.startedAt = open.date
        // endedAt == nil: cronómetro en curso, no finalizado
        open.durationMinutes = 60
        open.rpe = 8

        XCTAssertFalse(AvatarMoodResolver.isRealCompletedWorkout(open, now: now, calendar: calendar))
        // Sin sesiones válidas, daysSinceLastRealSession == Int.max → qualifiesForTired
        XCTAssertEqual(mood(for: [open]), .tired)
    }

    func test_openSessionDoesNotInfluenceMoodCalculation() {
        let open = WorkoutDay(
            date: calendar.startOfDay(for: now),
            entries: [makeEntry(exercise: makeExercise(), reps: 10)]
        )
        open.startedAt = open.date
        // endedAt == nil: sesión todavía en curso
        open.durationMinutes = 60
        open.rpe = 8

        let completed = makeRealWorkout(
            on: -1,
            durationMinutes: 60,
            entries: [makeEntry(exercise: makeExercise(name: "Pull-up"), reps: 8)]
        )

        XCTAssertFalse(AvatarMoodResolver.isRealCompletedWorkout(open, now: now, calendar: calendar))
        XCTAssertTrue(AvatarMoodResolver.isRealCompletedWorkout(completed, now: now, calendar: calendar))

        let moodWithoutOpen = mood(for: [completed])
        let moodWithOpen = mood(for: [open, completed])

        // La sesión abierta no altera el mood derivado únicamente de la sesión completada
        XCTAssertEqual(moodWithOpen, moodWithoutOpen)
        // Una sola sesión completada ayer (a < 4 días, solo 1 sesión en 7 días) → idle
        XCTAssertEqual(moodWithOpen, .idle)
        // La sesión abierta no activa strong por sí sola junto a la completada
        XCTAssertNotEqual(moodWithOpen, .strong)
    }
}
