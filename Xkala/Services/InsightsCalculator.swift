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
        let cal = insightsCalendar(from: calendar)
        let timed = workouts.filter { isValidTimedSession($0) }
        let window = timeWindow(for: range, now: now, calendar: cal)
        let inWindow = timed.filter { w in
            guard let end = w.endedAt else { return false }
            return end >= window.start && end <= window.end
        }

        let bucketStartsRaw = generateBucketStarts(
            for: range,
            windowStart: window.start,
            windowEnd: window.end,
            calendar: cal
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
                calendar: cal
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
                calendar: cal
            )
            return InsightsBucket(
                id: bucketId(start: start, calendar: cal),
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

    /// Agregados de carga por bucket temporal (`workout.date`, no `endedAt`).
    static func loadBuckets(
        from workouts: [WorkoutDay],
        range: StatsRange,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [LoadBucket] {
        let cal = insightsCalendar(from: calendar)
        let withLoad = workouts.filter { ($0.sessionLoad ?? 0) > 0 }
        let window = timeWindow(for: range, now: now, calendar: cal)
        let inWindow = withLoad.filter { $0.date >= window.start && $0.date <= window.end }

        let bucketStarts = generateBucketStarts(
            for: range,
            windowStart: window.start,
            windowEnd: window.end,
            calendar: cal
        ).sorted()

        guard !bucketStarts.isEmpty else { return [] }

        var loadByKey: [Date: Int] = [:]
        for key in bucketStarts {
            loadByKey[key] = 0
        }

        for workout in inWindow {
            guard let load = workout.sessionLoad, load > 0 else { continue }
            guard let key = loadBucketKey(
                for: workout.date,
                range: range,
                bucketStarts: bucketStarts,
                calendar: cal
            ),
                loadByKey[key] != nil
            else { continue }
            loadByKey[key, default: 0] += load
        }

        return bucketStarts.map { start in
            LoadBucket(date: start, totalLoad: loadByKey[start] ?? 0)
        }
    }

    /// Etiqueta del eje X para un inicio de bucket (misma presentación que insights temporales).
    static func bucketAxisLabel(
        intervalStart: Date,
        range: StatsRange,
        calendar: Calendar = .current
    ) -> String {
        axisLabelForBucket(
            intervalStart: intervalStart,
            range: range,
            calendar: insightsCalendar(from: calendar)
        )
    }

    // MARK: - Calendar y ventanas móviles

    /// Semana lunes–domingo para insights (independiente del locale del dispositivo).
    private static func insightsCalendar(from calendar: Calendar) -> Calendar {
        var c = calendar
        c.firstWeekday = 2
        return c
    }

    private struct TimeWindow: Equatable {
        let start: Date
        let end: Date
    }

    /// Lunes de la semana que contiene `date`.
    static func mondayWeekStart(containing date: Date, calendar: Calendar) -> Date? {
        let cal = insightsCalendar(from: calendar)
        let day = cal.startOfDay(for: date)
        let weekday = cal.component(.weekday, from: day)
        let daysFromMonday = (weekday - cal.firstWeekday + 7) % 7
        return cal.date(byAdding: .day, value: -daysFromMonday, to: day)
    }

    /// Últimos 7 días (incluye hoy).
    static func lastSevenDayStarts(endingAt now: Date, calendar: Calendar) -> [Date] {
        let cal = calendar
        guard let first = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: now)) else {
            return []
        }
        var result: [Date] = []
        var d = first
        let last = cal.startOfDay(for: now)
        while d <= last {
            result.append(d)
            guard let next = cal.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return result
    }

    /// Últimas 5 semanas reales (lunes–domingo) terminando en la semana actual.
    static func lastFiveWeekStarts(endingAt now: Date, calendar: Calendar) -> [Date] {
        let cal = insightsCalendar(from: calendar)
        guard var monday = mondayWeekStart(containing: now, calendar: cal) else { return [] }
        var result: [Date] = []
        for _ in 0..<5 {
            result.insert(monday, at: 0)
            guard let previous = cal.date(byAdding: .day, value: -7, to: monday) else { break }
            monday = previous
        }
        return result
    }

    /// Inicios de mes para los últimos `count` meses móviles terminando en el mes de `now`.
    static func lastMonthStarts(count: Int, endingAt now: Date, calendar: Calendar) -> [Date] {
        guard count > 0,
              let currentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let oldest = calendar.date(byAdding: .month, value: -(count - 1), to: currentMonth)
        else {
            return []
        }
        var result: [Date] = []
        var cursor = oldest
        while cursor <= currentMonth {
            result.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// Etiqueta de semana lunes–domingo: solo días del mes (p. ej. `4–10`, `27–3`).
    static func weekAxisLabel(weekStartMonday: Date, calendar: Calendar) -> String {
        let cal = calendar
        guard let weekEnd = cal.date(byAdding: .day, value: 6, to: weekStartMonday) else { return "" }
        let startDay = cal.component(.day, from: weekStartMonday)
        let endDay = cal.component(.day, from: weekEnd)
        return "\(startDay)–\(endDay)"
    }

    // MARK: - Presentación del eje X (sin mezclar con buckets de datos)

    /// Una guía vertical por bucket (independiente de cuántas etiquetas se muestren).
    static func allBucketAxisIndices(bucketCount: Int) -> [Int] {
        guard bucketCount > 0 else { return [] }
        return Array(0..<bucketCount)
    }

    /// Índices con etiqueta visible en el eje X; el último bucket (periodo actual) siempre se incluye.
    static func visibleAxisLabelIndices(bucketCount: Int, range: StatsRange) -> [Int] {
        guard bucketCount > 0 else { return [] }
        let last = bucketCount - 1
        let useSparse: Bool = switch range {
        case .oneYear:
            bucketCount > 7
        case .oneMonth:
            bucketCount > 5
        case .sixMonths, .sevenDays:
            false
        }
        var indices: [Int]
        if useSparse {
            indices = sparseAxisLabelIndicesEnsuringLast(bucketCount: bucketCount)
        } else {
            indices = Array(0..<bucketCount)
        }
        if !indices.contains(last) {
            indices.append(last)
        }
        return indices.sorted()
    }

    /// Primer bucket, alternos intermedios y siempre el último índice (solo etiquetas, no guías).
    static func sparseAxisLabelIndicesEnsuringLast(bucketCount: Int) -> [Int] {
        guard bucketCount > 0 else { return [] }
        if bucketCount == 1 { return [0] }
        let last = bucketCount - 1
        var indices = [0]
        var i = 2
        while i < last - 1 {
            indices.append(i)
            i += 2
        }
        if indices.last != last {
            indices.append(last)
        }
        return indices.sorted()
    }

    @available(*, deprecated, renamed: "visibleAxisLabelIndices")
    static func visibleAxisMarkIndices(bucketCount: Int, range: StatsRange) -> [Int] {
        visibleAxisLabelIndices(bucketCount: bucketCount, range: range)
    }

    @available(*, deprecated, renamed: "sparseAxisLabelIndicesEnsuringLast")
    static func sparseAxisMarkIndicesEnsuringLast(bucketCount: Int) -> [Int] {
        sparseAxisLabelIndicesEnsuringLast(bucketCount: bucketCount)
    }

    private static func timeWindow(for range: StatsRange, now: Date, calendar: Calendar) -> TimeWindow {
        let end = now
        let startInstant: Date
        switch range {
        case .sevenDays:
            startInstant = lastSevenDayStarts(endingAt: now, calendar: calendar).first ?? now
        case .oneMonth:
            startInstant = lastFiveWeekStarts(endingAt: now, calendar: calendar).first ?? now
        case .sixMonths:
            startInstant = lastMonthStarts(count: 6, endingAt: now, calendar: calendar).first ?? now
        case .oneYear:
            startInstant = lastMonthStarts(count: 12, endingAt: now, calendar: calendar).first ?? now
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
            return lastSevenDayStarts(endingAt: windowEnd, calendar: calendar)
        case .oneMonth:
            return lastFiveWeekStarts(endingAt: windowEnd, calendar: calendar)
        case .sixMonths:
            return lastMonthStarts(count: 6, endingAt: windowEnd, calendar: calendar)
        case .oneYear:
            return lastMonthStarts(count: 12, endingAt: windowEnd, calendar: calendar)
        }
    }

    private static func bucketKey(
        for endedAt: Date,
        range: StatsRange,
        bucketStarts: [Date],
        calendar: Calendar
    ) -> Date? {
        loadBucketKey(for: endedAt, range: range, bucketStarts: bucketStarts, calendar: calendar)
    }

    private static func loadBucketKey(
        for sessionDate: Date,
        range: StatsRange,
        bucketStarts: [Date],
        calendar: Calendar
    ) -> Date? {
        switch range {
        case .sevenDays:
            return calendar.startOfDay(for: sessionDate)

        case .oneMonth:
            guard let monday = mondayWeekStart(containing: sessionDate, calendar: calendar) else {
                return nil
            }
            return bucketStarts.first { calendar.isDate($0, inSameDayAs: monday) }

        case .sixMonths, .oneYear:
            let c = calendar.dateComponents([.year, .month], from: sessionDate)
            guard let monthStart = calendar.date(from: c) else { return nil }
            return bucketStarts.first { calendar.isDate($0, equalTo: monthStart, toGranularity: .month) }
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

    /// Diminutivos de mes en español (6M / 1A), mayúsculas.
    private static func monthAxisAbbreviationUppercase(date: Date, calendar: Calendar) -> String {
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
        calendar: Calendar
    ) -> String {
        switch range {
        case .sevenDays:
            return weekdayAxisLetter(date: intervalStart, calendar: calendar)
        case .oneMonth:
            return weekAxisLabel(weekStartMonday: intervalStart, calendar: calendar)
        case .sixMonths:
            return monthAxisAbbreviationUppercase(date: intervalStart, calendar: calendar)
        case .oneYear:
            return monthAxisAbbreviationUppercase(date: intervalStart, calendar: calendar)
        }
    }
}
