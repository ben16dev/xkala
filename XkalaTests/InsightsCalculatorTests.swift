import XCTest
@testable import Xkala

@MainActor
final class InsightsCalculatorTests: XCTestCase {

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
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
    }

    func test_oneMonth_groupsIntoWeekChunksWithSemLabels() {
        let e = Exercise(name: "T", category: "C", mode: "reps", loadAllowed: false)
        let entry = WorkoutEntry(exercise: e, isDone: true, sets: [])
        let day0 = calendar.startOfDay(for: refNow)
        guard
            let anchor = calendar.date(byAdding: .day, value: -29, to: day0),
            let secondWeek = calendar.date(byAdding: .day, value: 7, to: anchor)
        else {
            XCTFail("dates")
            return
        }

        let w0 = WorkoutDay(
            date: anchor,
            entries: [entry],
            startedAt: anchor,
            endedAt: anchor.addingTimeInterval(3600)
        )
        let w1 = WorkoutDay(
            date: secondWeek,
            entries: [entry],
            startedAt: secondWeek,
            endedAt: secondWeek.addingTimeInterval(600)
        )

        let snap = InsightsCalculator.snapshot(
            from: [w0, w1],
            range: .oneMonth,
            now: refNow,
            calendar: calendar
        )

        XCTAssertEqual(snap.buckets.count, 5)
        XCTAssertEqual(snap.buckets[0].sessionCount, 1)
        XCTAssertEqual(snap.buckets[1].sessionCount, 1)
        XCTAssertEqual(snap.buckets[0].axisLabel, "SEM 1")
        XCTAssertEqual(snap.buckets[1].axisLabel, "SEM 2")
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

    func test_oneYear_bucketsAreChronologicalByIntervalStart() {
        let snap = InsightsCalculator.snapshot(
            from: [],
            range: .oneYear,
            now: refNow,
            calendar: calendar
        )
        guard snap.buckets.count >= 2 else {
            XCTFail("expected at least 2 monthly buckets")
            return
        }
        for i in 0..<snap.buckets.count {
            XCTAssertEqual(snap.buckets[i].chronologicalIndex, i)
        }
        for i in 0..<(snap.buckets.count - 1) {
            XCTAssertLessThanOrEqual(
                snap.buckets[i].intervalStart,
                snap.buckets[i + 1].intervalStart
            )
        }
    }
}
