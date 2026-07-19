import Foundation

/// Ejercicios realizados (`isDone`) agrupados por categoría y periodo temporal.
enum ProgressCategoryCalculator {
    /// Categorías distintas con al menos un ejercicio realizado en el historial (para el selector).
    static func allCategoryOptions(from workouts: [WorkoutDay]) -> [ProgressCategoryOption] {
        var displayNameByKey: [String: String] = [:]

        for workout in workouts {
            for entry in workout.entries where entry.isDone {
                let displayName = entry.exercise.displayCategoryLabel
                let key = categoryGroupingKey(from: displayName)
                guard !key.isEmpty else { continue }
                if displayNameByKey[key] == nil {
                    displayNameByKey[key] = displayName
                }
            }
        }

        return displayNameByKey.keys.sorted().compactMap { key in
            guard let name = displayNameByKey[key] else { return nil }
            return ProgressCategoryOption(
                id: key,
                displayName: name,
                shortLabel: ProgressCategoryAbbreviation.shortLabel(for: name)
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Buckets del periodo para una categoría; devuelve ceros si no hay actividad en el rango.
    static func buckets(
        forCategoryKey categoryKey: String,
        from workouts: [WorkoutDay],
        range: StatsRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [ProgressCategoryBucket] {
        let cal = insightsCalendar(from: calendar)
        let bucketStarts = generateBucketStarts(for: range, now: now, calendar: cal).sorted()
        guard !bucketStarts.isEmpty else { return [] }

        let window = timeWindow(for: range, now: now, calendar: cal)
        var countsByBucket: [Date: Int] = [:]
        for start in bucketStarts {
            countsByBucket[start] = 0
        }

        let inWindow = workouts.filter { $0.date >= window.start && $0.date <= window.end }

        for workout in inWindow {
            guard let bucketStart = bucketStart(
                for: workout.date,
                range: range,
                bucketStarts: bucketStarts,
                calendar: cal
            ) else { continue }

            for entry in workout.entries where entry.isDone {
                let displayName = entry.exercise.displayCategoryLabel
                let key = categoryGroupingKey(from: displayName)
                guard key == categoryKey else { continue }
                countsByBucket[bucketStart, default: 0] += 1
            }
        }

        return bucketStarts.enumerated().map { index, start in
            ProgressCategoryBucket(
                id: bucketId(start: start, calendar: cal),
                chronologicalIndex: index,
                axisLabel: InsightsCalculator.bucketAxisLabel(
                    intervalStart: start,
                    range: range,
                    calendar: cal
                ),
                completedCount: countsByBucket[start] ?? 0
            )
        }
    }

    static func snapshot(
        from workouts: [WorkoutDay],
        range: StatsRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> ProgressByCategorySnapshot {
        let options = allCategoryOptions(from: workouts)
        let series: [ProgressCategorySeries] = options.map { option in
            let buckets = buckets(
                forCategoryKey: option.id,
                from: workouts,
                range: range,
                now: now,
                calendar: calendar
            )
            let total = buckets.reduce(0) { $0 + $1.completedCount }
            return ProgressCategorySeries(
                id: option.id,
                displayName: option.displayName,
                buckets: buckets,
                totalInRange: total
            )
        }
        .filter { $0.totalInRange > 0 }

        return ProgressByCategorySnapshot(range: range, series: series)
    }

    // MARK: - Ventana y buckets (misma lógica que insights/carga)

    private struct TimeWindow: Equatable {
        let start: Date
        let end: Date
    }

    private static func insightsCalendar(from calendar: Calendar) -> Calendar {
        var c = calendar
        c.firstWeekday = 2
        return c
    }

    private static func timeWindow(for range: StatsRange, now: Date, calendar: Calendar) -> TimeWindow {
        let end = now
        let startInstant: Date
        switch range {
        case .sevenDays:
            startInstant = InsightsCalculator.lastSevenDayStarts(endingAt: now, calendar: calendar).first ?? now
        case .oneMonth:
            startInstant = InsightsCalculator.lastFiveWeekStarts(endingAt: now, calendar: calendar).first ?? now
        case .threeMonths:
            startInstant = InsightsCalculator.lastWeekStarts(count: 13, endingAt: now, calendar: calendar).first ?? now
        case .sixMonths:
            startInstant = InsightsCalculator.lastMonthStarts(count: 6, endingAt: now, calendar: calendar).first ?? now
        case .oneYear:
            startInstant = InsightsCalculator.lastMonthStarts(count: 12, endingAt: now, calendar: calendar).first ?? now
        }
        return TimeWindow(start: startInstant, end: end)
    }

    private static func generateBucketStarts(
        for range: StatsRange,
        now: Date,
        calendar: Calendar
    ) -> [Date] {
        switch range {
        case .sevenDays:
            return InsightsCalculator.lastSevenDayStarts(endingAt: now, calendar: calendar)
        case .oneMonth:
            return InsightsCalculator.lastFiveWeekStarts(endingAt: now, calendar: calendar)
        case .threeMonths:
            return InsightsCalculator.lastWeekStarts(count: 13, endingAt: now, calendar: calendar)
        case .sixMonths:
            return InsightsCalculator.lastMonthStarts(count: 6, endingAt: now, calendar: calendar)
        case .oneYear:
            return InsightsCalculator.lastMonthStarts(count: 12, endingAt: now, calendar: calendar)
        }
    }

    private static func bucketStart(
        for sessionDate: Date,
        range: StatsRange,
        bucketStarts: [Date],
        calendar: Calendar
    ) -> Date? {
        switch range {
        case .sevenDays:
            return calendar.startOfDay(for: sessionDate)

        case .oneMonth, .threeMonths:
            guard let monday = InsightsCalculator.mondayWeekStart(containing: sessionDate, calendar: calendar) else {
                return nil
            }
            return bucketStarts.first { calendar.isDate($0, inSameDayAs: monday) }

        case .sixMonths, .oneYear:
            let components = calendar.dateComponents([.year, .month], from: sessionDate)
            guard let monthStart = calendar.date(from: components) else { return nil }
            return bucketStarts.first { calendar.isDate($0, equalTo: monthStart, toGranularity: .month) }
        }
    }

    private static func categoryGroupingKey(from displayLabel: String) -> String {
        ProgressCategoryAbbreviation.normalizedKey(from: displayLabel)
    }

    private static func bucketId(start: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: start)
    }
}
