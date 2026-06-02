import XCTest
@testable import Xkala

@MainActor
final class InsightsCalculatorTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        c.firstWeekday = 2
        return c
    }

    /// 2024-06-15 12:00:00 UTC
    private let refNow = Date(timeIntervalSince1970: 1_718_452_800)

    func test_isValidTimedSession_requiresStartedEndedAndOrder() {
        let e = Exercise(name: "T", category: "C", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: e, isDone: true, sets: [])
        let w1 = WorkoutDay(date: refNow, entries: [entry], startedAt: nil, endedAt: refNow)
        XCTAssertFalse(InsightsCalculator.isValidTimedSession(w1))

        let w2 = WorkoutDay(date: refNow, entries: [entry], startedAt: refNow, endedAt: nil)
        XCTAssertFalse(InsightsCalculator.isValidTimedSession(w2))

        let w3 = WorkoutDay(
            date: refNow,
            entries: [entry],
            startedAt: refNow,
            endedAt: refNow.addingTimeInterval(-1)
        )
        XCTAssertFalse(InsightsCalculator.isValidTimedSession(w3))

        let w4 = WorkoutDay(
            date: refNow,
            entries: [entry],
            startedAt: refNow.addingTimeInterval(-3600),
            endedAt: refNow
        )
        XCTAssertTrue(InsightsCalculator.isValidTimedSession(w4))
    }

    func test_sevenDays_aggregatesSessionsAndTimeByDay() {
        let e = Exercise(name: "T", category: "C", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: e, isDone: true, sets: [])

        let day0 = calendar.startOfDay(for: refNow)
        guard
            let dMinus2 = calendar.date(byAdding: .day, value: -2, to: day0),
            let dMinus1 = calendar.date(byAdding: .day, value: -1, to: day0)
        else {
            XCTFail("dates")
            return
        }

        let wA = WorkoutDay(
            date: dMinus2,
            entries: [entry],
            startedAt: dMinus2,
            endedAt: dMinus2.addingTimeInterval(1800)
        )
        let wB = WorkoutDay(
            date: dMinus2,
            entries: [entry],
            startedAt: dMinus2.addingTimeInterval(3600),
            endedAt: dMinus2.addingTimeInterval(7200)
        )
        let wC = WorkoutDay(
            date: dMinus1,
            entries: [entry],
            startedAt: dMinus1,
            endedAt: dMinus1.addingTimeInterval(600)
        )

        let snap = InsightsCalculator.snapshot(
            from: [wA, wB, wC],
            range: .sevenDays,
            now: refNow,
            calendar: calendar
        )

        XCTAssertEqual(snap.buckets.count, 7)

        let bucketMinus2 = snap.buckets.first { calendar.isDate($0.intervalStart, inSameDayAs: dMinus2) }
        XCTAssertEqual(bucketMinus2?.sessionCount, 2)
        XCTAssertEqual(bucketMinus2?.trainingTimeSeconds, 1800 + 3600, accuracy: 0.01)

        let bucketMinus1 = snap.buckets.first { calendar.isDate($0.intervalStart, inSameDayAs: dMinus1) }
        XCTAssertEqual(bucketMinus1?.sessionCount, 1)
        XCTAssertEqual(bucketMinus1?.trainingTimeSeconds, 600, accuracy: 0.01)
    }

    func test_sessionTypeSplit_tracksTrainingAndClimbing() {
        let e = Exercise(name: "T", category: "C", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: e, isDone: true, sets: [])
        let day0 = calendar.startOfDay(for: refNow)

        let train = WorkoutDay(
            date: day0,
            entries: [entry],
            startedAt: day0,
            endedAt: day0.addingTimeInterval(1000),
            sessionType: "training"
        )
        let climb = WorkoutDay(
            date: day0,
            entries: [entry],
            startedAt: day0.addingTimeInterval(2000),
            endedAt: day0.addingTimeInterval(3000),
            sessionType: "climbing"
        )

        let snap = InsightsCalculator.snapshot(
            from: [train, climb],
            range: .sevenDays,
            now: refNow,
            calendar: calendar
        )
        let today = snap.buckets.first { calendar.isDate($0.intervalStart, inSameDayAs: day0) }
        XCTAssertEqual(today?.trainingSessions, 1)
        XCTAssertEqual(today?.climbingSessions, 1)
        XCTAssertEqual(today?.trainingTypeTimeSeconds, 1000, accuracy: 0.01)
        XCTAssertEqual(today?.climbingTypeTimeSeconds, 1000, accuracy: 0.01)
        XCTAssertEqual(today?.sessionCount, (today?.trainingSessions ?? 0) + (today?.climbingSessions ?? 0))
        XCTAssertEqual(
            today?.trainingTimeSeconds ?? 0,
            (today?.trainingTypeTimeSeconds ?? 0) + (today?.climbingTypeTimeSeconds ?? 0),
            accuracy: 0.01
        )
    }

    func test_oneMonth_groupsIntoMondayWeeksWithRealRangeLabels() {
        let e = Exercise(name: "T", category: "C", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: e, isDone: true, sets: [])
        guard
            let weekA = calendar.date(from: DateComponents(year: 2024, month: 6, day: 4)),
            let weekB = calendar.date(from: DateComponents(year: 2024, month: 6, day: 11))
        else {
            XCTFail("dates")
            return
        }

        let w0 = WorkoutDay(
            date: weekA,
            entries: [entry],
            startedAt: weekA,
            endedAt: weekA.addingTimeInterval(3600)
        )
        let w1 = WorkoutDay(
            date: weekB,
            entries: [entry],
            startedAt: weekB,
            endedAt: weekB.addingTimeInterval(600)
        )

        let snap = InsightsCalculator.snapshot(
            from: [w0, w1],
            range: .oneMonth,
            now: refNow,
            calendar: calendar
        )

        XCTAssertEqual(snap.buckets.count, 5)
        XCTAssertEqual(snap.buckets.last?.axisLabel, "10–16")
        XCTAssertTrue(snap.buckets.contains { $0.axisLabel == "3–9" && $0.sessionCount == 1 })
        XCTAssertTrue(snap.buckets.contains { $0.axisLabel == "10–16" && $0.sessionCount == 1 })
        XCTAssertFalse(snap.buckets.contains { $0.axisLabel.hasPrefix("SEM") })
        XCTAssertFalse(snap.buckets.contains { $0.axisLabel == "1–7" })
    }

    func test_weekAxisLabel_sameMonth_and_crossMonth() {
        guard
            let mondayApr20 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 20)),
            let mondayApr27 = calendar.date(from: DateComponents(year: 2026, month: 4, day: 27))
        else {
            XCTFail("dates")
            return
        }
        XCTAssertEqual(
            InsightsCalculator.weekAxisLabel(weekStartMonday: mondayApr20, calendar: calendar),
            "20–26"
        )
        XCTAssertEqual(
            InsightsCalculator.weekAxisLabel(weekStartMonday: mondayApr27, calendar: calendar),
            "27–3"
        )
    }

    func test_oneMonth_may2026_includesCrossMonthWeekEndingCurrentWeek() {
        guard let may24 = calendar.date(from: DateComponents(year: 2026, month: 5, day: 24, hour: 12)) else {
            XCTFail("dates")
            return
        }
        let snap = InsightsCalculator.snapshot(
            from: [],
            range: .oneMonth,
            now: may24,
            calendar: calendar
        )
        XCTAssertEqual(snap.buckets.count, 5)
        XCTAssertTrue(snap.buckets.contains { $0.axisLabel == "27–3" })
        XCTAssertEqual(snap.buckets.last?.axisLabel, "18–24")
    }

    func test_sixMonths_showsSixRollingMonthsEndingCurrent() {
        let snap = InsightsCalculator.snapshot(
            from: [],
            range: .sixMonths,
            now: refNow,
            calendar: calendar
        )
        XCTAssertEqual(snap.buckets.count, 6)
        XCTAssertEqual(snap.buckets.last?.axisLabel, "JUN")
    }

    func test_sixMonths_aggregatesByCalendarMonth() {
        let e = Exercise(name: "T", category: "C", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: e, isDone: true, sets: [])
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: refNow))!
        guard let day5 = calendar.date(byAdding: .day, value: 5, to: monthStart) else {
            XCTFail("dates")
            return
        }

        let wA = WorkoutDay(
            date: monthStart,
            entries: [entry],
            startedAt: monthStart,
            endedAt: monthStart.addingTimeInterval(1000)
        )
        let wB = WorkoutDay(
            date: day5,
            entries: [entry],
            startedAt: day5,
            endedAt: day5.addingTimeInterval(2000)
        )

        let snap = InsightsCalculator.snapshot(
            from: [wA, wB],
            range: .sixMonths,
            now: refNow,
            calendar: calendar
        )

        let withTwo = snap.buckets.filter { $0.sessionCount == 2 }
        XCTAssertEqual(withTwo.count, 1)
        XCTAssertEqual(withTwo.first?.axisLabel, "JUN")
    }

    func test_sparseAxisMarkIndicesEnsuringLast_includesLastIndex() {
        XCTAssertEqual(InsightsCalculator.sparseAxisMarkIndicesEnsuringLast(bucketCount: 12), [0, 2, 4, 6, 8, 11])
        XCTAssertEqual(InsightsCalculator.sparseAxisMarkIndicesEnsuringLast(bucketCount: 1), [0])
        XCTAssertEqual(InsightsCalculator.sparseAxisMarkIndicesEnsuringLast(bucketCount: 2), [0, 1])
    }

    func test_allBucketAxisIndices_coversEveryBucket() {
        XCTAssertEqual(InsightsCalculator.allBucketAxisIndices(bucketCount: 0), [])
        XCTAssertEqual(InsightsCalculator.allBucketAxisIndices(bucketCount: 7), [0, 1, 2, 3, 4, 5, 6])
        XCTAssertEqual(InsightsCalculator.allBucketAxisIndices(bucketCount: 12), Array(0..<12))
    }

    func test_visibleAxisLabelIndices_alwaysIncludesLastIndex() {
        for range in StatsRange.allCases {
            let count: Int = switch range {
            case .sevenDays: 7
            case .oneMonth: 5
            case .sixMonths: 6
            case .oneYear: 12
            }
            let indices = InsightsCalculator.visibleAxisLabelIndices(bucketCount: count, range: range)
            XCTAssertEqual(indices.last, count - 1, "falta etiqueta del periodo actual en \(range.rawValue)")
            XCTAssertTrue(indices.contains(0), "falta etiqueta del primer periodo en \(range.rawValue)")
        }
    }

    func test_oneYear_twelveBucketsFewerVisibleLabels_lastIsCurrentMonth() {
        let bucketCount = 12
        let labelIndices = InsightsCalculator.visibleAxisLabelIndices(bucketCount: bucketCount, range: .oneYear)
        let guideIndices = InsightsCalculator.allBucketAxisIndices(bucketCount: bucketCount)

        XCTAssertEqual(guideIndices.count, 12)
        XCTAssertEqual(guideIndices, Array(0..<12))
        XCTAssertLessThan(labelIndices.count, bucketCount)
        XCTAssertEqual(labelIndices.last, 11)
        XCTAssertEqual(labelIndices, [0, 2, 4, 6, 8, 11])
    }

    func test_sevenDays_lastBucketIsTodayWithCorrectLetter() {
        let snap = InsightsCalculator.snapshot(
            from: [],
            range: .sevenDays,
            now: refNow,
            calendar: calendar
        )
        XCTAssertEqual(snap.buckets.count, 7)
        let today = calendar.startOfDay(for: refNow)
        XCTAssertTrue(calendar.isDate(snap.buckets.last!.intervalStart, inSameDayAs: today))
        XCTAssertEqual(snap.buckets.last?.axisLabel, "S")
        XCTAssertEqual(snap.buckets.map(\.axisLabel), ["D", "L", "M", "X", "J", "V", "S"])
    }

    func test_oneMonthBucketsEndInCurrentWeekAndLabelsIncludeLastIndex() {
        let snap = InsightsCalculator.snapshot(
            from: [],
            range: .oneMonth,
            now: refNow,
            calendar: calendar
        )
        guard let currentMonday = InsightsCalculator.mondayWeekStart(containing: refNow, calendar: calendar) else {
            XCTFail("No se pudo calcular el lunes de la semana actual")
            return
        }

        XCTAssertEqual(snap.buckets.count, 5)
        XCTAssertTrue(calendar.isDate(snap.buckets.last!.intervalStart, inSameDayAs: currentMonday))

        let lastIndex = snap.buckets.count - 1
        let labelIndices = InsightsCalculator.visibleAxisLabelIndices(
            bucketCount: snap.buckets.count,
            range: .oneMonth
        )
        let markIndices = InsightsCalculator.visibleAxisMarkIndices(
            bucketCount: snap.buckets.count,
            range: .oneMonth
        )
        XCTAssertEqual(labelIndices.last, lastIndex)
        XCTAssertTrue(labelIndices.contains(lastIndex))
        XCTAssertEqual(markIndices, labelIndices)
    }

    // MARK: - Carga (loadBuckets)

    func test_loadBuckets_excludesNilOrZeroLoad() {
        let e = Exercise(name: "T", category: "C", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: e, isDone: true, sets: [])
        let day0 = calendar.startOfDay(for: refNow)

        let noPlanning = WorkoutDay(date: day0, entries: [entry])
        let zeroMinutes = WorkoutDay(date: day0, entries: [entry])
        zeroMinutes.durationMinutes = 0
        zeroMinutes.rpe = 7

        let withLoad = WorkoutDay(date: day0, entries: [entry])
        withLoad.durationMinutes = 30
        withLoad.rpe = 7

        let buckets = InsightsCalculator.loadBuckets(
            from: [noPlanning, zeroMinutes, withLoad],
            range: .sevenDays,
            now: refNow,
            calendar: calendar
        )

        let today = buckets.last
        XCTAssertEqual(today?.totalLoad, 210)
        XCTAssertEqual(buckets.filter { $0.totalLoad > 0 }.count, 1)
    }

    func test_loadBuckets_sumsCorrectlyAcrossDays() {
        let e = Exercise(name: "T", category: "C", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: e, isDone: true, sets: [])
        let day0 = calendar.startOfDay(for: refNow)
        guard let dMinus1 = calendar.date(byAdding: .day, value: -1, to: day0) else {
            XCTFail("dates")
            return
        }

        let wToday = WorkoutDay(date: day0, entries: [entry])
        wToday.durationMinutes = 20
        wToday.rpe = 5

        let wYesterday = WorkoutDay(date: dMinus1, entries: [entry])
        wYesterday.durationMinutes = 10
        wYesterday.rpe = 6

        let buckets = InsightsCalculator.loadBuckets(
            from: [wToday, wYesterday],
            range: .sevenDays,
            now: refNow,
            calendar: calendar
        )

        XCTAssertEqual(buckets.count, 7)
        let todayBucket = buckets.first { calendar.isDate($0.date, inSameDayAs: day0) }
        let yesterdayBucket = buckets.first { calendar.isDate($0.date, inSameDayAs: dMinus1) }
        XCTAssertEqual(todayBucket?.totalLoad, 100)
        XCTAssertEqual(yesterdayBucket?.totalLoad, 60)
    }

    func test_loadBuckets_lastBucketIsCurrentPeriod_sevenDays() {
        let buckets = InsightsCalculator.loadBuckets(
            from: [],
            range: .sevenDays,
            now: refNow,
            calendar: calendar
        )
        let today = calendar.startOfDay(for: refNow)
        XCTAssertEqual(buckets.count, 7)
        XCTAssertTrue(calendar.isDate(buckets.last!.date, inSameDayAs: today))
    }

    func test_loadBuckets_lastBucketIsCurrentPeriod_oneMonth() {
        let buckets = InsightsCalculator.loadBuckets(
            from: [],
            range: .oneMonth,
            now: refNow,
            calendar: calendar
        )
        guard let currentMonday = InsightsCalculator.mondayWeekStart(containing: refNow, calendar: calendar) else {
            XCTFail("monday")
            return
        }
        XCTAssertEqual(buckets.count, 5)
        XCTAssertTrue(calendar.isDate(buckets.last!.date, inSameDayAs: currentMonday))
    }

    func test_loadBuckets_splitsLoadBySessionOrigin() {
        let e = Exercise(name: "T", category: "C", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: e, isDone: true, sets: [])
        let day0 = calendar.startOfDay(for: refNow)

        let climbing = WorkoutDay(date: day0, entries: [entry])
        climbing.sessionType = WorkoutDay.SessionType.climbing.rawValue
        climbing.durationMinutes = 20
        climbing.rpe = 5

        let training = WorkoutDay(date: day0, entries: [entry])
        training.sessionType = WorkoutDay.SessionType.training.rawValue
        training.durationMinutes = 10
        training.rpe = 6

        let buckets = InsightsCalculator.loadBuckets(
            from: [climbing, training],
            range: .sevenDays,
            now: refNow,
            calendar: calendar
        )

        let today = buckets.last
        XCTAssertEqual(today?.totalLoad, 160)
        XCTAssertEqual(today?.rockLoad, 100)
        XCTAssertEqual(today?.gymLoad, 60)
        XCTAssertEqual((today?.rockLoad ?? 0) + (today?.gymLoad ?? 0), today?.totalLoad)
    }

    func test_loadBuckets_oneMonth_groupsByMondayWeeks() {
        let e = Exercise(name: "T", category: "C", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: e, isDone: true, sets: [])
        guard
            let weekA = calendar.date(from: DateComponents(year: 2024, month: 6, day: 4)),
            let weekB = calendar.date(from: DateComponents(year: 2024, month: 6, day: 11))
        else {
            XCTFail("dates")
            return
        }

        let w0 = WorkoutDay(date: weekA, entries: [entry])
        w0.durationMinutes = 60
        w0.rpe = 7

        let w1 = WorkoutDay(date: weekB, entries: [entry])
        w1.durationMinutes = 30
        w1.rpe = 6

        let buckets = InsightsCalculator.loadBuckets(
            from: [w0, w1],
            range: .oneMonth,
            now: refNow,
            calendar: calendar
        )

        XCTAssertEqual(buckets.count, 5)
        guard let mondayA = InsightsCalculator.mondayWeekStart(containing: weekA, calendar: calendar) else {
            XCTFail("monday")
            return
        }
        let weekABucket = buckets.first { calendar.isDate($0.date, inSameDayAs: mondayA) }
        XCTAssertEqual(weekABucket?.totalLoad, 420)
        XCTAssertTrue(buckets.contains { $0.totalLoad == 180 })
    }

    func test_oneYear_showsTwelveRollingMonthsEndingCurrent() {
        let snap = InsightsCalculator.snapshot(
            from: [],
            range: .oneYear,
            now: refNow,
            calendar: calendar
        )
        XCTAssertEqual(snap.buckets.count, 12)
        XCTAssertEqual(
            snap.buckets.map(\.axisLabel),
            ["JUL", "AGO", "SEP", "OCT", "NOV", "DIC", "ENE", "FEB", "MAR", "ABR", "MAY", "JUN"]
        )
        XCTAssertEqual(snap.buckets.last?.axisLabel, "JUN")
        for i in 0..<snap.buckets.count {
            XCTAssertEqual(snap.buckets[i].chronologicalIndex, i)
            XCTAssertEqual(snap.buckets[i].sessionCount, 0)
        }
        for i in 0..<(snap.buckets.count - 1) {
            XCTAssertLessThanOrEqual(
                snap.buckets[i].intervalStart,
                snap.buckets[i + 1].intervalStart
            )
        }
    }
}
