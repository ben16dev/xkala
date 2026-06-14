import Foundation
import SwiftData

/// Evalúa qué chapas se desbloquean a partir del histórico de sesiones.
/// Sin dependencias de SwiftUI; testeable en aislamiento.
enum BadgeAwardService {

    static func newlyUnlockedBadges(
        workouts: [WorkoutDay],
        earnedBadges: [EarnedBadge],
        now: Date,
        calendar: Calendar = .current
    ) -> [BadgeUnlock] {
        let earnedIds = Set(earnedBadges.map(\.badgeId))

        #if DEBUG
        debugLogWorkouts(workouts, now: now, calendar: calendar)
        #endif

        var result: [BadgeUnlock] = []

        if !earnedIds.contains(BadgeDefinition.woodTrainingSessions.id),
           let source = firstWorkout(in: workouts, matching: {
               isTrainingSessionBadgeCandidate($0, now: now, calendar: calendar)
           }) {
            result.append(BadgeUnlock(badge: .woodTrainingSessions, sourceWorkout: source))
        }

        if !earnedIds.contains(BadgeDefinition.woodRockSessions.id),
           let source = firstWorkout(in: workouts, matching: {
               isRockSessionBadgeCandidate($0, now: now, calendar: calendar)
           }) {
            result.append(BadgeUnlock(badge: .woodRockSessions, sourceWorkout: source))
        }

        if !earnedIds.contains(BadgeDefinition.woodBlocksCheck.id),
           let source = firstWorkout(in: workouts, matching: {
               isBlockSuccessBadgeCandidate($0, now: now, calendar: calendar)
           }) {
            result.append(BadgeUnlock(badge: .woodBlocksCheck, sourceWorkout: source))
        }

        if !earnedIds.contains(BadgeDefinition.woodTraveCheck.id),
           let source = firstWorkout(in: workouts, matching: {
               isTraverseSuccessBadgeCandidate($0, now: now, calendar: calendar)
           }) {
            result.append(BadgeUnlock(badge: .woodTraveCheck, sourceWorkout: source))
        }

        if !earnedIds.contains(BadgeDefinition.woodSessionsInWeek.id) {
            let weeklySessions = weeklySessionsInLastSevenDays(workouts, now: now, calendar: calendar)
            #if DEBUG
            let dates = weeklySessions.map { $0.date.description }.joined(separator: ", ")
            print(
                "[BadgeWeek] count=\(weeklySessions.count) dates=[\(dates)] " +
                "unlocked=\(weeklySessions.count >= 3)"
            )
            #endif
            if weeklySessions.count >= 3 {
                result.append(BadgeUnlock(badge: .woodSessionsInWeek, sourceWorkout: weeklySessions[2]))
            }
        }

        return result
    }

    // MARK: - Eligibility helpers (una regla por badge)

    static func isBadgeEligibleWorkout(
        _ workout: WorkoutDay,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        _ = calendar
        let hasDuration = (workout.durationMinutes ?? 0) > 0
            || (workout.effectiveDurationMinutes ?? 0) > 0
        guard hasDuration else { return false }
        guard workout.date <= now else { return false }
        if let endedAt = workout.endedAt, endedAt > now { return false }
        if WorkoutImportBatchNotes.containsImportMarker(in: workout.notes) { return false }
        return true
    }

    static func isTrainingSessionBadgeCandidate(
        _ workout: WorkoutDay,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard isBadgeEligibleWorkout(workout, now: now, calendar: calendar) else { return false }
        return workout.sessionType == "training"
    }

    static func isRockSessionBadgeCandidate(
        _ workout: WorkoutDay,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard isBadgeEligibleWorkout(workout, now: now, calendar: calendar) else { return false }
        return workout.sessionType == "climbing"
    }

    static func isBlockSuccessBadgeCandidate(
        _ workout: WorkoutDay,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard isBadgeEligibleWorkout(workout, now: now, calendar: calendar) else { return false }
        return workout.entries.contains { $0.isBlock && $0.climbSuccess == true }
    }

    static func isTraverseSuccessBadgeCandidate(
        _ workout: WorkoutDay,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard isBadgeEligibleWorkout(workout, now: now, calendar: calendar) else { return false }
        return workout.entries.contains { $0.isTraverse && $0.climbSuccess == true }
    }

    static func weeklySessionsInLastSevenDays(
        _ workouts: [WorkoutDay],
        now: Date,
        calendar: Calendar = .current
    ) -> [WorkoutDay] {
        guard let windowStart = calendar.date(byAdding: .day, value: -7, to: now) else {
            return []
        }

        return workouts
            .filter { isBadgeEligibleWorkout($0, now: now, calendar: calendar) }
            .filter { $0.sessionType == "training" || $0.sessionType == "climbing" }
            .filter { $0.date >= windowStart && $0.date <= now }
            .sorted { $0.date < $1.date }
    }

    static func badgeEligibleWorkouts(
        from workouts: [WorkoutDay],
        now: Date,
        calendar: Calendar = .current
    ) -> [WorkoutDay] {
        workouts.filter { isBadgeEligibleWorkout($0, now: now, calendar: calendar) }
    }

    /// Elimina chapas vinculadas a una sesión antes de borrarla.
    static func deleteEarnedBadges(linkedTo workout: WorkoutDay, context: ModelContext) {
        let targetID = workout.persistentModelID
        guard let earned = try? context.fetch(FetchDescriptor<EarnedBadge>()) else { return }

        var deletedAny = false
        for badge in earned where badge.sourceWorkout?.persistentModelID == targetID {
            #if DEBUG
            print(
                "[BadgeDelete] deleting badgeId=\(badge.badgeId) " +
                "linked to workout=\(workout.date)"
            )
            #endif
            context.delete(badge)
            deletedAny = true
        }

        if deletedAny {
            try? context.save()
        }
    }

    // MARK: - Private

    private static func badgeReferenceDate(_ workout: WorkoutDay) -> Date {
        workout.endedAt ?? workout.date
    }

    private static func firstWorkout(
        in workouts: [WorkoutDay],
        matching predicate: (WorkoutDay) -> Bool
    ) -> WorkoutDay? {
        workouts
            .filter(predicate)
            .min { badgeReferenceDate($0) < badgeReferenceDate($1) }
    }

    #if DEBUG
    private static func debugLogWorkouts(
        _ workouts: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) {
        for workout in workouts {
            let eligible = isBadgeEligibleWorkout(workout, now: now, calendar: calendar)
            let trainingCandidate = isTrainingSessionBadgeCandidate(workout, now: now, calendar: calendar)
            let rockCandidate = isRockSessionBadgeCandidate(workout, now: now, calendar: calendar)
            let blockCandidate = isBlockSuccessBadgeCandidate(workout, now: now, calendar: calendar)
            let traverseCandidate = isTraverseSuccessBadgeCandidate(workout, now: now, calendar: calendar)

            print(
                "[BadgeAward] type=\(workout.sessionType) " +
                "duration=\(workout.durationMinutes.map(String.init) ?? "nil") " +
                "date=\(workout.date) endedAt=\(workout.endedAt.map(String.init(describing:)) ?? "nil") " +
                "eligible=\(eligible) trainingCandidate=\(trainingCandidate) " +
                "rockCandidate=\(rockCandidate) blockCandidate=\(blockCandidate) " +
                "traverseCandidate=\(traverseCandidate)"
            )

            for entry in workout.entries {
                print(
                    "[BadgeAwardEntry] name=\(entry.exercise.name) " +
                    "category=\(entry.exercise.category) climbKind=\(entry.climbKind ?? "nil") " +
                    "isBlock=\(entry.isBlock) isTraverse=\(entry.isTraverse) " +
                    "climbSuccess=\(entry.climbSuccess.map(String.init) ?? "nil")"
                )
            }
        }
    }
    #endif
}
