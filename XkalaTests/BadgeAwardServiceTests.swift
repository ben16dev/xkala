import XCTest
import SwiftData
@testable import Xkala

@MainActor
final class BadgeAwardServiceTests: XCTestCase {

    private var calendar: Calendar!
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUp() {
        super.setUp()
        calendar = Calendar.current
    }

    // MARK: - Helpers

    private func makeExercise(name: String, category: String = "Climb") -> Exercise {
        Exercise(name: name, category: category, mode: "reps", loadAllowed: false)
    }

    private func makeBlockEntry(success: Bool?, isDone: Bool = true) -> WorkoutEntry {
        WorkoutEntry(
            exercise: makeExercise(name: "Bloque"),
            isDone: isDone,
            sets: [SetRecord(reps: 1)],
            climbKind: "block",
            climbSuccess: success
        )
    }

    private func makeTraverseEntry(success: Bool?, isDone: Bool = true) -> WorkoutEntry {
        WorkoutEntry(
            exercise: makeExercise(name: "Travesía"),
            isDone: true,
            sets: [SetRecord(reps: 1)],
            climbKind: "traverse",
            climbSuccess: success
        )
    }

    private func makeManualWorkout(
        sessionType: String = "training",
        dayOffset: Int = 0,
        durationMinutes: Int,
        entries: [WorkoutEntry] = []
    ) -> WorkoutDay {
        let dayStart = calendar.startOfDay(for: now)
        let date = calendar.date(byAdding: .day, value: dayOffset, to: dayStart)!
        let workout = WorkoutDay(date: date, entries: entries)
        workout.sessionType = sessionType
        workout.durationMinutes = durationMinutes
        return workout
    }

    private func unlocked(
        from workouts: [WorkoutDay],
        earned: [EarnedBadge] = []
    ) -> [BadgeUnlock] {
        BadgeAwardService.newlyUnlockedBadges(
            workouts: workouts,
            earnedBadges: earned,
            now: now,
            calendar: calendar
        )
    }

    private func badgeIds(from unlocks: [BadgeUnlock]) -> [String] {
        unlocks.map(\.badge.id)
    }

    // MARK: - Sesión única rocódromo / roca

    func test_trainingManualDuration30WithoutTimer_unlocksOnlyWoodTrainingSessions() {
        let workout = WorkoutDay(date: now, entries: [])
        workout.sessionType = "training"
        workout.durationMinutes = 30

        let unlocks = unlocked(from: [workout])

        XCTAssertEqual(badgeIds(from: unlocks), [BadgeDefinition.woodTrainingSessions.id])
    }

    func test_climbingManualDuration30WithoutTimer_unlocksOnlyWoodRockSessions() {
        let workout = WorkoutDay(date: now, entries: [])
        workout.sessionType = "climbing"
        workout.durationMinutes = 30

        let unlocks = unlocked(from: [workout])

        XCTAssertEqual(badgeIds(from: unlocks), [BadgeDefinition.woodRockSessions.id])
    }

    func test_climbingManualDuration60WithoutTimer_unlocksOnlyWoodRockSessions() {
        let workout = WorkoutDay(date: now, entries: [])
        workout.sessionType = "climbing"
        workout.durationMinutes = 60

        let unlocks = unlocked(from: [workout])

        XCTAssertEqual(badgeIds(from: unlocks), [BadgeDefinition.woodRockSessions.id])
    }

    func test_trainingManualWithoutBlockEntries_doesNotUnlockWoodBlocksCheck() {
        let workout = makeManualWorkout(sessionType: "training", durationMinutes: 30, entries: [])

        let unlocks = unlocked(from: [workout])

        XCTAssertFalse(unlocks.contains { $0.badge == .woodBlocksCheck })
        XCTAssertFalse(unlocks.contains { $0.badge == .woodRockSessions })
        XCTAssertFalse(BadgeAwardService.isBlockSuccessBadgeCandidate(workout, now: now, calendar: calendar))
    }

    func test_zeroDuration_doesNotUnlock() {
        let workout = WorkoutDay(date: now, entries: [])
        workout.sessionType = "training"
        workout.durationMinutes = 0

        XCTAssertFalse(workout.isBadgeEligibleWorkout(now: now))
        XCTAssertTrue(unlocked(from: [workout]).isEmpty)
    }

    // MARK: - Bloque / travesía

    func test_manualValidSessionWithBlockSuccess_unlocksWoodBlocksCheck() {
        let workout = makeManualWorkout(
            sessionType: "training",
            durationMinutes: 60,
            entries: [makeBlockEntry(success: true, isDone: false)]
        )
        let earned = [EarnedBadge(badgeId: BadgeDefinition.woodTrainingSessions.id, sourceWorkout: workout)]

        let unlocks = unlocked(from: [workout], earned: earned)

        XCTAssertEqual(badgeIds(from: unlocks), [BadgeDefinition.woodBlocksCheck.id])
    }

    func test_manualValidSessionWithTraverseSuccess_unlocksWoodTraveCheck() {
        let workout = makeManualWorkout(
            sessionType: "training",
            durationMinutes: 60,
            entries: [makeTraverseEntry(success: true, isDone: false)]
        )
        let earned = [EarnedBadge(badgeId: BadgeDefinition.woodTrainingSessions.id, sourceWorkout: workout)]

        let unlocks = unlocked(from: [workout], earned: earned)

        XCTAssertEqual(badgeIds(from: unlocks), [BadgeDefinition.woodTraveCheck.id])
    }

    func test_traverseEntryByExerciseNameOnly_unlocksWoodTraveCheck() {
        let exercise = makeExercise(name: "Travesía", category: "Travesía")
        let entry = WorkoutEntry(
            exercise: exercise,
            isDone: false,
            sets: [SetRecord(reps: 1)],
            climbSuccess: true
        )
        let workout = makeManualWorkout(
            sessionType: "training",
            durationMinutes: 60,
            entries: [entry]
        )
        let earned = [EarnedBadge(badgeId: BadgeDefinition.woodTrainingSessions.id, sourceWorkout: workout)]

        XCTAssertTrue(entry.isTraverse)
        let unlocks = unlocked(from: [workout], earned: earned)
        XCTAssertEqual(badgeIds(from: unlocks), [BadgeDefinition.woodTraveCheck.id])
    }

    func test_threeValidSessionsInLastSevenDays_unlocksOnlyWoodSessionsInWeekWhenOthersEarned() {
        let day1 = calendar.date(byAdding: .day, value: -5, to: now)!
        let day2 = calendar.date(byAdding: .day, value: -3, to: now)!
        let day3 = calendar.date(byAdding: .day, value: -1, to: now)!

        let w1 = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        w1.date = day1
        let w2 = makeManualWorkout(sessionType: "climbing", durationMinutes: 45)
        w2.date = day2
        let w3 = makeManualWorkout(sessionType: "training", durationMinutes: 60)
        w3.date = day3

        let earned = [
            EarnedBadge(badgeId: BadgeDefinition.woodTrainingSessions.id, sourceWorkout: w1),
            EarnedBadge(badgeId: BadgeDefinition.woodRockSessions.id, sourceWorkout: w2),
        ]

        let unlocks = unlocked(from: [w1, w2, w3], earned: earned)

        XCTAssertEqual(badgeIds(from: unlocks), [BadgeDefinition.woodSessionsInWeek.id])
        XCTAssertEqual(
            unlocks.first { $0.badge == .woodSessionsInWeek }?.sourceWorkout.date,
            day3
        )
    }

    func test_manualValidSessionWithTraverseSuccessClimbingSession_unlocksWoodTraveCheck() {
        let workout = makeManualWorkout(
            sessionType: "climbing",
            durationMinutes: 60,
            entries: [makeTraverseEntry(success: true, isDone: false)]
        )
        let earned = [EarnedBadge(badgeId: BadgeDefinition.woodRockSessions.id, sourceWorkout: workout)]

        let unlocks = unlocked(from: [workout], earned: earned)

        XCTAssertEqual(badgeIds(from: unlocks), [BadgeDefinition.woodTraveCheck.id])
    }

    // MARK: - Ventana móvil 7 días

    func test_threeValidSessionsInLastSevenDays_unlocksWoodSessionsInWeek() {
        let day1 = calendar.date(byAdding: .day, value: -6, to: now)!
        let day2 = calendar.date(byAdding: .day, value: -3, to: now)!
        let day3 = calendar.date(byAdding: .day, value: -1, to: now)!

        let w1 = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        w1.date = day1
        let w2 = makeManualWorkout(sessionType: "climbing", durationMinutes: 30)
        w2.date = day2
        let w3 = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        w3.date = day3

        let unlocks = unlocked(from: [w1, w2, w3])

        XCTAssertTrue(unlocks.contains { $0.badge == .woodSessionsInWeek })
        XCTAssertEqual(
            unlocks.first { $0.badge == .woodSessionsInWeek }?.sourceWorkout.date,
            day3
        )
    }

    func test_twoValidSessionsInLastSevenDays_doesNotUnlockWoodSessionsInWeek() {
        let day1 = calendar.date(byAdding: .day, value: -2, to: now)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: now)!

        let w1 = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        w1.date = day1
        let w2 = makeManualWorkout(sessionType: "climbing", durationMinutes: 30)
        w2.date = day2

        let unlocks = unlocked(from: [w1, w2])

        XCTAssertFalse(unlocks.contains { $0.badge == .woodSessionsInWeek })
    }

    func test_threeSessionsWithOneFuture_doesNotUnlockWoodSessionsInWeek() {
        let day1 = calendar.date(byAdding: .day, value: -2, to: now)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: now)!
        let future = calendar.date(byAdding: .day, value: 1, to: now)!

        let w1 = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        w1.date = day1
        let w2 = makeManualWorkout(sessionType: "climbing", durationMinutes: 30)
        w2.date = day2
        let w3 = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        w3.date = future

        let unlocks = unlocked(from: [w1, w2, w3])

        XCTAssertFalse(unlocks.contains { $0.badge == .woodSessionsInWeek })
    }

    func test_threeSessionsWithOneZeroDuration_doesNotUnlockWoodSessionsInWeek() {
        let day1 = calendar.date(byAdding: .day, value: -2, to: now)!
        let day2 = calendar.date(byAdding: .day, value: -1, to: now)!
        let day3 = calendar.date(byAdding: .hour, value: -2, to: now)!

        let w1 = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        w1.date = day1
        let w2 = makeManualWorkout(sessionType: "climbing", durationMinutes: 30)
        w2.date = day2
        let w3 = makeManualWorkout(sessionType: "training", durationMinutes: 0)
        w3.date = day3

        let unlocks = unlocked(from: [w1, w2, w3])

        XCTAssertFalse(unlocks.contains { $0.badge == .woodSessionsInWeek })
    }

    func test_weeklySessionsInLastSevenDays_returnsThirdSessionByAscendingDate() {
        let day1 = calendar.date(byAdding: .day, value: -6, to: now)!
        let day2 = calendar.date(byAdding: .day, value: -3, to: now)!
        let day3 = calendar.date(byAdding: .day, value: -1, to: now)!

        let w1 = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        w1.date = day1
        let w2 = makeManualWorkout(sessionType: "climbing", durationMinutes: 30)
        w2.date = day2
        let w3 = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        w3.date = day3

        let weekly = BadgeAwardService.weeklySessionsInLastSevenDays([w1, w2, w3], now: now, calendar: calendar)

        XCTAssertEqual(weekly.count, 3)
        XCTAssertEqual(weekly[2].date, day3)
    }

    func test_weeklySessionsInLastSevenDays_excludesFutureAndZeroDuration() {
        let past = calendar.date(byAdding: .day, value: -1, to: now)!
        let future = calendar.date(byAdding: .day, value: 1, to: now)!

        let valid1 = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        valid1.date = past
        let valid2 = makeManualWorkout(sessionType: "climbing", durationMinutes: 30)
        valid2.date = past
        let zero = makeManualWorkout(sessionType: "training", durationMinutes: 0)
        zero.date = past
        let futureWorkout = makeManualWorkout(sessionType: "training", durationMinutes: 30)
        futureWorkout.date = future

        let weekly = BadgeAwardService.weeklySessionsInLastSevenDays(
            [valid1, valid2, zero, futureWorkout],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(weekly.count, 2)
    }

    func test_badgeEligibleDurationMinutes_prefersPersistedDurationMinutes() {
        let workout = WorkoutDay(date: now, entries: [])
        workout.durationMinutes = 60
        workout.startedAt = now
        workout.endedAt = now.addingTimeInterval(900)

        XCTAssertEqual(workout.badgeEligibleDurationMinutes, 60)
    }

    func test_futureSessionDate_isNotBadgeEligible() {
        let future = calendar.date(byAdding: .day, value: 1, to: now)!
        let workout = WorkoutDay(date: future, entries: [])
        workout.sessionType = "training"
        workout.durationMinutes = 60

        XCTAssertFalse(workout.isBadgeEligibleWorkout(now: now))
        XCTAssertTrue(unlocked(from: [workout]).isEmpty)
    }

    func test_alreadyEarnedBadge_isNotReturnedAgain() {
        let workout = makeManualWorkout(sessionType: "training", durationMinutes: 60)
        let earned = [EarnedBadge(badgeId: BadgeDefinition.woodTrainingSessions.id, sourceWorkout: workout)]

        let unlocks = unlocked(from: [workout], earned: earned)

        XCTAssertFalse(unlocks.contains { $0.badge == .woodTrainingSessions })
    }

    // MARK: - Borrado

    func test_deletingSourceWorkout_removesLinkedBadge() throws {
        let schema = Schema([
            WorkoutDay.self,
            Exercise.self,
            WorkoutEntry.self,
            SetRecord.self,
            EarnedBadge.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext

        let workout = makeManualWorkout(sessionType: "training", durationMinutes: 60)
        context.insert(workout)

        let badge = EarnedBadge(
            badgeId: BadgeDefinition.woodTrainingSessions.id,
            sourceWorkout: workout
        )
        context.insert(badge)
        try context.save()

        BadgeAwardService.deleteEarnedBadges(linkedTo: workout, context: context)
        context.delete(workout)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<EarnedBadge>())
        XCTAssertTrue(remaining.isEmpty)
    }

    func test_earnedBadgeWithoutSourceWorkout_isExcludedFromVisibleList() {
        let linked = EarnedBadge(badgeId: BadgeDefinition.woodTrainingSessions.id, sourceWorkout: nil)
        let orphaned = EarnedBadge(badgeId: BadgeDefinition.woodRockSessions.id, sourceWorkout: nil)
        let all = [linked, orphaned]

        let visible = all.filter { $0.sourceWorkout != nil }

        XCTAssertTrue(visible.isEmpty)
    }
}
