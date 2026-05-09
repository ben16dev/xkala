import Foundation

/// Agregados temporales para insights globales. Solo datos derivados; sin persistencia.
enum InsightsCalculator {

    /// Sesión válida para métricas de tiempo: timer completo y coherente (misma regla que `StatsCalculator` para tiempo total).
    static func isValidTimedSession(_ workout: WorkoutDay) -> Bool {
        guard
            let startedAt = workout.startedAt,
            let endedAt = workout.endedAt,
            endedAt > startedAt
        else {
            return false
        }
        return true
    }

    static func snapshot(
        from workouts: [WorkoutDay],
        range: StatsRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> InsightsSnapshot {
        let timed = workouts.filter { isValidTimedSession($0) }
        let window = timeWindow(for: range, now: now, calendar: calendar)
        let inWindow = timed.filter { w in
            guard let end = w.endedAt else { return false }
            return end >= window.start && end <= window.end
        }

        let bucketStartsRaw = generateBucketStarts(
            for: range,
            windowStart: window.start,
            windowEnd: window.end,
            calendar: calendar
        )
        let bucketStarts = bucketStartsRaw.sorted()

        guard !bucketStarts.isEmpty else {
            return InsightsSnapshot(range: range, buckets: [])
        }

        var timeByKey: [Date: TimeInterval] = [:]
        var trainTimeByKey: [Date: TimeInterval] = [:]
        var climbTimeByKey: [Date: TimeInterval] = [:]
        var countByKey: [Date: Int] = [:]
        var trainByKey: [Date: Int] = [:]
        var climbByKey: [Date: Int] = [:]

        for key in bucketStarts {
            timeByKey[key] = 0
            trainTimeByKey[key] = 0
            climbTimeByKey[key] = 0
            countByKey[key] = 0
            trainByKey[key] = 0
            climbByKey[key] = 0
        }

        for w in inWindow {
            guard let endedAt = w.endedAt, let startedAt = w.startedAt else { continue }
            guard let key = bucketKey(
                for: endedAt,
                range: range,
                bucketStarts: bucketStarts,
                calendar: calendar
            ),
                timeByKey[key] != nil
            else {
                continue
            }

            let duration = endedAt.timeIntervalSince(startedAt)
            timeByKey[key, default: 0] += duration
            countByKey[key, default: 0] += 1

            switch w.sessionTypeEnum {
            case .training:
                trainByKey[key, default: 0] += 1
                trainTimeByKey[key, default: 0] += duration
            case .climbing:
                climbByKey[key, default: 0] += 1
                climbTimeByKey[key, default: 0] += duration
            }
        }

        let buckets: [InsightsBucket] = bucketStarts.enumerated().map { index, start in
            let axisLabel = axisLabelForBucket(
                intervalStart: start,
                range: range,
                weekOrdinal: index + 1,
                calendar: calendar
            )
            return InsightsBucket(
                id: bucketId(start: start, calendar: calendar),
                chronologicalIndex: index,
                intervalStart: start,
                axisLabel: axisLabel,
                trainingTimeSeconds: timeByKey[start] ?? 0,
                sessionCount: countByKey[start] ?? 0,
                trainingTypeTimeSeconds: trainTimeByKey[start] ?? 0,
                climbingTypeTimeSeconds: climbTimeByKey[start] ?? 0,
                trainingSessions: trainByKey[start] ?? 0,
                climbingSessions: climbByKey[start] ?? 0
            )
        }

        return InsightsSnapshot(range: range, buckets: buckets)
    }

    // MARK: - Ventana temporal

    private struct TimeWindow: Equatable {
        let start: Date
        let end: Date
    }

    private static func timeWindow(for range: StatsRange, now: Date, calendar: Calendar) -> TimeWindow {
        let end = now
        let startInstant: Date
        switch range {
        case .sevenDays:
            guard let d = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else {
                return TimeWindow(start: now, end: end)
            }
            startInstant = d
        case .oneMonth:
            guard let d = calendar.date(byAdding: .day, value: -29, to: calendar.startOfDay(for: now)) else {
                return TimeWindow(start: now, end: end)
            }
            startInstant = d
        case .sixMonths:
            startInstant = calendar.date(byAdding: .month, value: -6, to: now) ?? now
        case .oneYear:
            startInstant = calendar.date(byAdding: .year, value: -1, to: now) ?? now
        }
        return TimeWindow(start: startInstant, end: end)
    }

    // MARK: - Buckets

    private static func generateBucketStarts(
        for range: StatsRange,
        windowStart: Date,
        windowEnd: Date,
        calendar: Calendar
    ) -> [Date] {
        switch range {
        case .sevenDays:
            let firstDay = calendar.startOfDay(for: windowStart)
            let lastDay = calendar.startOfDay(for: windowEnd)
            var result: [Date] = []
            var d = firstDay
            while d <= lastDay {
                result.append(d)
                guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
                d = next
            }
            return result

        case .oneMonth:
            let anchor = calendar.startOfDay(for: windowStart)
            let lastDay = calendar.startOfDay(for: windowEnd)
            var result: [Date] = []
            var d = anchor
            while d <= lastDay {
                result.append(d)
                guard let next = calendar.date(byAdding: .day, value: 7, to: d) else { break }
                d = next
            }
            return result

        case .sixMonths, .oneYear:
            let startComps = calendar.dateComponents([.year, .month], from: windowStart)
            guard var monthCursor = calendar.date(from: startComps) else { return [] }
            let endMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: windowEnd)) ?? windowEnd
            var result: [Date] = []
            while monthCursor <= endMonthStart {
                result.append(monthCursor)
                guard let next = calendar.date(byAdding: .month, value: 1, to: monthCursor) else { break }
                monthCursor = next
            }
            return result
        }
    }

    private static func bucketKey(
        for endedAt: Date,
        range: StatsRange,
        bucketStarts: [Date],
        calendar: Calendar
    ) -> Date? {
        switch range {
        case .sevenDays:
            return calendar.startOfDay(for: endedAt)

        case .oneMonth:
            guard let anchor = bucketStarts.first else { return nil }
            let day = calendar.startOfDay(for: endedAt)
            let days = calendar.dateComponents([.day], from: anchor, to: day).day ?? 0
            if days < 0 { return nil }
            let idx = days / 7
            guard !bucketStarts.isEmpty else { return nil }
            if idx < bucketStarts.count {
                return bucketStarts[idx]
            }
            return bucketStarts[bucketStarts.count - 1]

        case .sixMonths, .oneYear:
            let c = calendar.dateComponents([.year, .month], from: endedAt)
            return calendar.date(from: c)
        }
    }

    private static func bucketId(start: Date, calendar: Calendar) -> String {
        let f = DateFormatter()
        f.calendar = calendar
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: start)
    }

    /// Letra de día L M X J V S D (domingo = D … sábado = S).
    private static func weekdayAxisLetter(date: Date, calendar: Calendar) -> String {
        let letters = ["", "D", "L", "M", "X", "J", "V", "S"]
        let wd = calendar.component(.weekday, from: date)
        guard (1...7).contains(wd) else { return "" }
        return letters[wd]
    }

    /// Diminutivos de mes en español (6M / 1A), sin ambigüedad.
    private static func monthAxisAbbreviation(date: Date, calendar: Calendar) -> String {
        let abbrevs = [
            "",
            "ENE", "FEB", "MAR", "ABR", "MAY", "JUN",
            "JUL", "AGO", "SEP", "OCT", "NOV", "DIC"
        ]
        let m = calendar.component(.month, from: date)
        guard (1...12).contains(m) else { return "" }
        return abbrevs[m]
    }

    private static func axisLabelForBucket(
        intervalStart: Date,
        range: StatsRange,
        weekOrdinal: Int,
        calendar: Calendar
    ) -> String {
        switch range {
        case .sevenDays:
            return weekdayAxisLetter(date: intervalStart, calendar: calendar)
        case .oneMonth:
            return "SEM \(weekOrdinal)"
        case .sixMonths, .oneYear:
            return monthAxisAbbreviation(date: intervalStart, calendar: calendar)
        }
    }
}
