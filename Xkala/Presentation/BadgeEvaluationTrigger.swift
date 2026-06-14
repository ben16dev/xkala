import Foundation
import SwiftData

/// Punto único para evaluar badges tras cambios en sesión/ejercicios.
@MainActor
enum BadgeEvaluationTrigger {

    enum Reason: String {
        case manualDuration
        case climbSuccess
        case finalize
        case sessionChange
        case homeReturn
    }

    static func evaluateBadgesAfterSessionChange(
        context: ModelContext,
        coordinator: BadgeUnlockCoordinator,
        currentWorkout: WorkoutDay?,
        reason: Reason
    ) {
        context.processPendingChanges()
        try? context.save()

        var workouts = (try? context.fetch(FetchDescriptor<WorkoutDay>())) ?? []
        if let currentWorkout {
            workouts = workoutsIncludingCurrent(currentWorkout, in: workouts)
        }
        materializeEntries(for: workouts)
        let earnedBadges = (try? context.fetch(FetchDescriptor<EarnedBadge>())) ?? []

        #if DEBUG
        debugLog(
            reason: reason,
            currentWorkout: currentWorkout,
            workouts: workouts,
            earnedBadges: earnedBadges
        )
        #endif

        coordinator.evaluate(
            workouts: workouts,
            earnedBadges: earnedBadges,
            context: context,
            now: Date()
        )
    }

    /// Fuerza la carga de `entries` tras fetch (bloques/travesía no deben quedar vacíos por faulting).
    private static func materializeEntries(for workouts: [WorkoutDay]) {
        for workout in workouts {
            _ = workout.entries.count
        }
    }

    /// Garantiza que la sesión editada en memoria (p. ej. `sessionType` recién cambiado) se evalúa con datos actuales.
    private static func workoutsIncludingCurrent(
        _ current: WorkoutDay,
        in fetched: [WorkoutDay]
    ) -> [WorkoutDay] {
        var workouts = fetched
        if let index = workouts.firstIndex(where: { $0.persistentModelID == current.persistentModelID }) {
            workouts[index] = current
        } else {
            workouts.append(current)
        }
        return workouts
    }

    #if DEBUG
    private static func debugLog(
        reason: Reason,
        currentWorkout: WorkoutDay?,
        workouts: [WorkoutDay],
        earnedBadges: [EarnedBadge]
    ) {
        print("[BadgeTrigger] reason=\(reason.rawValue) workouts=\(workouts.count) earned=\(earnedBadges.count)")

        guard let workout = currentWorkout else { return }

        let climbSummary = workout.entries.map { entry in
            let kind = entry.isBlock ? "block" : (entry.isTraverse ? "traverse" : "other")
            return "\(kind):success=\(entry.climbSuccess.map(String.init) ?? "nil")"
        }.joined(separator: " | ")

        print(
            "[ManualDuration] workout date=\(workout.date) sessionType=\(workout.sessionType) " +
            "durationMinutes=\(workout.durationMinutes.map(String.init) ?? "nil") " +
            "effectiveDurationMinutes=\(workout.effectiveDurationMinutes.map(String.init) ?? "nil") " +
            "startedAt=\(workout.startedAt.map(String.init(describing:)) ?? "nil") " +
            "endedAt=\(workout.endedAt.map(String.init(describing:)) ?? "nil")"
        )
        print("[BadgeTrigger] entries block/traverse/climbSuccess=[\(climbSummary)]")
    }
    #endif
}
