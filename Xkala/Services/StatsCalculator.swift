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

        let completedEntries = workouts
            .flatMap(\.entries)
            .filter(\.isDone)
        let totalCompletedExercises = completedEntries.count

        let currentWeekWorkouts = workoutsInCurrentWeek(workouts, now: now, calendar: calendar)
        let favoriteCategory = favoriteCategory(from: completedEntries)
        let totalTrainingTime = totalValidTrainingTime(from: workouts)
        let recentRecords = recentRecords(from: completedEntries, workouts: workouts)

        return GlobalStatsSnapshot(
            totalWorkouts: totalWorkouts,
            workoutsLast30Days: workoutsLast30Days,
            totalCompletedExercises: totalCompletedExercises,
            currentWeekWorkouts: currentWeekWorkouts,
            favoriteCategory: favoriteCategory,
            totalTrainingTime: totalTrainingTime,
            recentRecords: recentRecords
        )
    }

    private static func workoutsInCurrentWeek(
        _ workouts: [WorkoutDay],
        now: Date,
        calendar: Calendar
    ) -> Int {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return workouts.filter { weekInterval.contains($0.date) }.count
    }

    private static func favoriteCategory(from entries: [WorkoutEntry]) -> String {
        var countsByCategory: [String: Int] = [:]
        var displayNameByKey: [String: String] = [:]

        for entry in entries {
            let rawCategory = entry.exercise.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !rawCategory.isEmpty else { continue }

            let key = normalize(rawCategory)
            guard !key.isEmpty else { continue }

            countsByCategory[key, default: 0] += 1
            if displayNameByKey[key] == nil {
                displayNameByKey[key] = rawCategory
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
