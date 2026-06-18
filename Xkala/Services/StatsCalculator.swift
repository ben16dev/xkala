import Foundation

enum StatsCalculator {
    static func snapshot(
        from workouts: [WorkoutDay],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> GlobalStatsSnapshot {
        guard !workouts.isEmpty else { return .empty }

        let totalWorkouts = workouts.count
        let cutoff30Days = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        let workoutsLast30Days = workouts.filter { $0.date >= cutoff30Days }.count

        // Volumen realizado: todas las entradas marcadas como hechas, sin filtrar por éxito en bloque/travesía.
        let completedEntries = workouts
            .flatMap(\.entries)
            .filter(\.isDone)
        let totalCompletedExercises = completedEntries.count

        let favoriteCategory = favoriteCategory(from: completedEntries)
        let totalTrainingTime = totalValidTrainingTime(from: workouts)
        let recentRecords = recentRecords(from: completedEntries, workouts: workouts)
        let sessionLoadLast7Days = totalSessionLoad(workouts: workouts, dayCount: 7, now: now, calendar: calendar)
        let sessionLoadLast30Days = totalSessionLoad(workouts: workouts, dayCount: 30, now: now, calendar: calendar)
        let lastTrainingMethod = lastTrainingMethod(
            workouts: workouts,
            now: now
        )
        let climbingStats = climbingStats(from: workouts)

        return GlobalStatsSnapshot(
            totalWorkouts: totalWorkouts,
            workoutsLast30Days: workoutsLast30Days,
            totalCompletedExercises: totalCompletedExercises,
            favoriteCategory: favoriteCategory,
            totalTrainingTime: totalTrainingTime,
            recentRecords: recentRecords,
            sessionLoadLast7Days: sessionLoadLast7Days,
            sessionLoadLast30Days: sessionLoadLast30Days,
            lastTrainingMethod: lastTrainingMethod,
            climbingStats: climbingStats
        )
    }

    // MARK: - Escalada (bloques y travesías)

    static func climbingStats(from workouts: [WorkoutDay]) -> ClimbingStatsSnapshot? {
        let entries = workouts.flatMap(\.entries)
        let blockEntries = entries.filter(\.isBlock)
        let traverseEntries = entries.filter(\.isTraverse)

        let blocksTotal = blockEntries.count
        let blocksSuccess = blockEntries.filter { $0.climbSuccess == true }.count
        let traversesTotal = traverseEntries.count
        let traversesSuccess = traverseEntries.filter { $0.climbSuccess == true }.count

        let snapshot = ClimbingStatsSnapshot(
            blocksTotal: blocksTotal,
            blocksSuccess: blocksSuccess,
            traversesTotal: traversesTotal,
            traversesSuccess: traversesSuccess
        )
        return snapshot.isEmpty ? nil : snapshot
    }

    // MARK: - Carga de sesión (planificación)


    static func totalSessionLoad(
        workouts: [WorkoutDay],
        dayCount: Int,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Int? {
        guard dayCount > 0,
              let windowStart = calendar.date(
                byAdding: .day,
                value: -(dayCount - 1),
                to: calendar.startOfDay(for: now)
              )
        else { return nil }

        let loads = workouts
            .filter { $0.date >= windowStart && $0.date <= now }
            .compactMap(\.sessionLoad)

        guard !loads.isEmpty else { return nil }
        return loads.reduce(0, +)
    }

    static func lastTrainingMethod(
        workouts: [WorkoutDay],
        now: Date = Date()
    ) -> TrainingMethod? {
        workouts
            .filter { workout in
                guard workout.date <= now else { return false }
                if let endedAt = workout.endedAt, endedAt > now { return false }
                guard !AvatarMoodResolver.isImportedSession(workout) else { return false }
                return workout.trainingMethod != nil
            }
            .sorted { $0.date > $1.date }
            .first?
            .trainingMethod
    }

    private static func favoriteCategory(from entries: [WorkoutEntry]) -> String {
        var countsByCategory: [String: Int] = [:]
        var displayNameByKey: [String: String] = [:]

        for entry in entries {
            let key = entry.exercise.exerciseCategoryKeyForSemantics
            guard !key.isEmpty else { continue }

            countsByCategory[key, default: 0] += 1
            if displayNameByKey[key] == nil {
                displayNameByKey[key] = entry.exercise.displayCategoryLabel
            }
        }

        guard let maxCount = countsByCategory.values.max(), maxCount > 0 else {
            return "Sin datos"
        }

        let topKeys = countsByCategory
            .filter { $0.value == maxCount }
            .map(\.key)
            .sorted()

        guard let winnerKey = topKeys.first, topKeys.count == 1 else {
            return "Sin datos"
        }

        return displayNameByKey[winnerKey] ?? "Sin datos"
    }

    private static func totalValidTrainingTime(from workouts: [WorkoutDay]) -> TimeInterval {
        workouts.reduce(0) { partial, workout in
            guard
                let startedAt = workout.startedAt,
                let endedAt = workout.endedAt,
                endedAt > startedAt
            else {
                return partial
            }
            return partial + endedAt.timeIntervalSince(startedAt)
        }
    }

    private static func recentRecords(
        from completedEntries: [WorkoutEntry],
        workouts: [WorkoutDay]
    ) -> [RecentRecordSnapshot] {
        let exercises = uniqueExercises(from: completedEntries)

        let recordsWithDate: [(record: RecentRecordSnapshot, date: Date)] = exercises.compactMap { exercise in
            guard let pr = ExerciseProgressCalculator.latestStrictPersonalRecord(for: exercise, in: workouts) else {
                return nil
            }

            let exerciseName = exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedMark = pr.markText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !exerciseName.isEmpty, !normalizedMark.isEmpty else { return nil }

            let record = RecentRecordSnapshot(
                id: normalize(exerciseName) + "|" + normalize(exercise.category) + "|" + normalize(exercise.mode),
                exerciseName: exerciseName,
                bestMark: normalizedMark,
                recordDate: pr.sessionDate,
                workout: pr.workout,
                entry: pr.entry
            )
            return (record, pr.sessionDate)
        }

        return recordsWithDate
            .sorted { $0.date > $1.date }
            .prefix(3)
            .map(\.record)
    }

    private static func uniqueExercises(from entries: [WorkoutEntry]) -> [Exercise] {
        var seenKeys = Set<String>()
        var exercises: [Exercise] = []

        for entry in entries {
            let name = entry.exercise.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }

            let key = normalize(name) + "|" + normalize(entry.exercise.category) + "|" + normalize(entry.exercise.mode)
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            exercises.append(entry.exercise)
        }

        return exercises
    }

    private static func normalize(_ text: String) -> String {
        text
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "es_ES"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
