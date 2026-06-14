import Foundation
import SwiftData
import Combine

/// Coordina la evaluación, persistencia y presentación de chapas recién desbloqueadas.
@MainActor
final class BadgeUnlockCoordinator: ObservableObject {
    @Published var pendingUnlock: BadgeUnlock?

    var pendingBadge: BadgeDefinition? { pendingUnlock?.badge }

    private var queue: [BadgeUnlock] = []

    func evaluateAndAward(
        context: ModelContext,
        workouts: [WorkoutDay],
        earnedBadges: [EarnedBadge],
        now: Date = Date()
    ) {
        evaluate(workouts: workouts, earnedBadges: earnedBadges, context: context, now: now)
    }

    func evaluate(
        workouts: [WorkoutDay],
        earnedBadges: [EarnedBadge],
        context: ModelContext,
        now: Date = Date()
    ) {
        let calendar = Calendar.current
        let earnedIds = Set(earnedBadges.map(\.badgeId))
        let newUnlocks = BadgeAwardService.newlyUnlockedBadges(
            workouts: workouts,
            earnedBadges: earnedBadges,
            now: now,
            calendar: calendar
        )
        guard !newUnlocks.isEmpty else { return }

        var insertedAny = false
        for unlock in newUnlocks where !earnedIds.contains(unlock.badge.id) {
            context.insert(EarnedBadge(
                badgeId: unlock.badge.id,
                earnedAt: now,
                sourceWorkout: unlock.sourceWorkout
            ))
            #if DEBUG
            print(
                "[BadgePersist] inserted=\(unlock.badge.id) " +
                "sourceWorkoutExists=\(unlock.sourceWorkout.modelContext != nil)"
            )
            #endif
            queue.append(unlock)
            insertedAny = true
        }

        guard insertedAny else { return }

        try? context.save()
        presentNextIfNeeded()
    }

    func dismissCurrent() {
        pendingUnlock = nil
        presentNextIfNeeded()
    }

    private func presentNextIfNeeded() {
        guard pendingUnlock == nil, !queue.isEmpty else { return }
        pendingUnlock = queue.removeFirst()
    }
}
