import XCTest
import SwiftData
@testable import Xkala

@MainActor
final class BadgeUnlockCoordinatorTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            WorkoutDay.self,
            Exercise.self,
            WorkoutEntry.self,
            SetRecord.self,
            EarnedBadge.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    private func makeManualTrainingWorkout(durationMinutes: Int) -> WorkoutDay {
        let workout = WorkoutDay(date: now, entries: [])
        workout.sessionType = "training"
        workout.durationMinutes = durationMinutes
        return workout
    }

    private func makeBlockEntry(success: Bool) -> WorkoutEntry {
        let exercise = Exercise(name: "Bloque", category: "Climb", mode: "reps", loadAllowed: false)
        return WorkoutEntry(
            exercise: exercise,
            isDone: false,
            sets: [SetRecord(reps: 1)],
            climbKind: "block",
            climbSuccess: success
        )
    }

    func test_afterManualDurationSave_createsOnlyTrainingBadgeAndShowsPopup() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let coordinator = BadgeUnlockCoordinator()

        let workout = makeManualTrainingWorkout(durationMinutes: 60)
        context.insert(workout)
        try context.save()

        BadgeEvaluationTrigger.evaluateBadgesAfterSessionChange(
            context: context,
            coordinator: coordinator,
            currentWorkout: workout,
            reason: .manualDuration
        )

        let earned = try context.fetch(FetchDescriptor<EarnedBadge>())
        XCTAssertEqual(earned.count, 1)
        XCTAssertEqual(earned.first?.badgeId, BadgeDefinition.woodTrainingSessions.id)
        XCTAssertNotNil(earned.first?.sourceWorkout)
        XCTAssertEqual(coordinator.pendingBadge, .woodTrainingSessions)
        XCTAssertNotNil(coordinator.pendingUnlock)
    }

    func test_afterClimbSuccessSave_createsWoodBlocksCheckBadgeAndShowsPopup() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let coordinator = BadgeUnlockCoordinator()

        let entry = makeBlockEntry(success: true)
        let workout = makeManualTrainingWorkout(durationMinutes: 60)
        workout.entries = [entry]
        context.insert(workout)

        let existing = EarnedBadge(
            badgeId: BadgeDefinition.woodTrainingSessions.id,
            sourceWorkout: workout
        )
        context.insert(existing)
        try context.save()

        BadgeEvaluationTrigger.evaluateBadgesAfterSessionChange(
            context: context,
            coordinator: coordinator,
            currentWorkout: workout,
            reason: .climbSuccess
        )

        let earned = try context.fetch(FetchDescriptor<EarnedBadge>())
        XCTAssertEqual(earned.count, 2)
        XCTAssertTrue(earned.contains { $0.badgeId == BadgeDefinition.woodBlocksCheck.id })
        XCTAssertEqual(coordinator.pendingBadge, .woodBlocksCheck)
        XCTAssertNotNil(coordinator.pendingUnlock)
    }
}
