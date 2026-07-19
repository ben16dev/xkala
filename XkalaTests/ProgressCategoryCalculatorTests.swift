import XCTest
@testable import Xkala

@MainActor
final class ProgressCategoryCalculatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        c.firstWeekday = 2
        return c
    }

    private func makeExercise(name: String, category: String) -> Exercise {
        Exercise(name: name, category: category, mode: "reps", loadAllowed: false)
    }

    private func makeEntry(exercise: Exercise, isDone: Bool) -> WorkoutEntry {
        WorkoutEntry(exercise: exercise, isDone: isDone, sets: [SetRecord(reps: 5, seconds: nil, loadKg: nil)])
    }

    private func bucketId(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    func test_countsOnlyCompletedEntries_byCategory() {
        let fuerza = makeExercise(name: "Dominadas", category: "Fuerza general")
        let recuperacion = makeExercise(name: "Estiramientos", category: "Recuperación")

        let workout = WorkoutDay(
            date: now,
            name: "",
            notes: "",
            entries: [
                makeEntry(exercise: fuerza, isDone: true),
                makeEntry(exercise: recuperacion, isDone: true),
                makeEntry(exercise: fuerza, isDone: false)
            ]
        )

        let snapshot = ProgressCategoryCalculator.snapshot(
            from: [workout],
            range: .sevenDays,
            now: now
        )

        XCTAssertTrue(snapshot.hasAnyData)
        XCTAssertEqual(snapshot.series.count, 2)

        let fuerzaSeries = snapshot.series.first { $0.displayName == "Fuerza general" }
        let recuperacionSeries = snapshot.series.first { $0.displayName == "Recuperación" }
        XCTAssertEqual(fuerzaSeries?.totalInRange, 1)
        XCTAssertEqual(recuperacionSeries?.totalInRange, 1)
    }

    func test_emptyWhenNoCompletedEntries() {
        let exercise = makeExercise(name: "Test", category: "Técnica")
        let workout = WorkoutDay(
            date: now,
            name: "",
            notes: "",
            entries: [makeEntry(exercise: exercise, isDone: false)]
        )

        let snapshot = ProgressCategoryCalculator.snapshot(
            from: [workout],
            range: .sevenDays,
            now: now
        )

        XCTAssertFalse(snapshot.hasAnyData)
        XCTAssertTrue(snapshot.series.isEmpty)
        XCTAssertTrue(ProgressCategoryCalculator.allCategoryOptions(from: [workout]).isEmpty)
    }

    func test_bucketsReturnZerosWhenNoActivityInRange() {
        let exercise = makeExercise(name: "Dominadas", category: "Fuerza general")
        let oldDate = Date(timeIntervalSince1970: 0)
        let workout = WorkoutDay(
            date: oldDate,
            name: "",
            notes: "",
            entries: [makeEntry(exercise: exercise, isDone: true)]
        )

        let options = ProgressCategoryCalculator.allCategoryOptions(from: [workout])
        XCTAssertEqual(options.count, 1)

        let buckets = ProgressCategoryCalculator.buckets(
            forCategoryKey: options[0].id,
            from: [workout],
            range: .sevenDays,
            now: now
        )

        XCTAssertFalse(buckets.isEmpty)
        XCTAssertTrue(buckets.allSatisfy { $0.completedCount == 0 })
    }

    func test_threeMonths_returnsThirteenBucketsWithSameStartsAsInsights() {
        guard let refNow = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 12)) else {
            XCTFail("dates")
            return
        }
        let exercise = makeExercise(name: "Dominadas", category: "Fuerza general")
        let workout = WorkoutDay(
            date: refNow,
            name: "",
            notes: "",
            entries: [makeEntry(exercise: exercise, isDone: true)]
        )
        let options = ProgressCategoryCalculator.allCategoryOptions(from: [workout])
        XCTAssertEqual(options.count, 1)

        let progressBuckets = ProgressCategoryCalculator.buckets(
            forCategoryKey: options[0].id,
            from: [workout],
            range: .threeMonths,
            now: refNow,
            calendar: calendar
        )
        let insightBuckets = InsightsCalculator.snapshot(
            from: [],
            range: .threeMonths,
            now: refNow,
            calendar: calendar
        ).buckets

        XCTAssertEqual(progressBuckets.count, 13)
        XCTAssertEqual(progressBuckets.map(\.id), insightBuckets.map { bucketId(for: $0.intervalStart) })
        XCTAssertEqual(progressBuckets.last?.axisLabel, insightBuckets.last?.axisLabel)
        XCTAssertEqual(progressBuckets.last?.axisLabel, "10–16")
    }

    func test_threeMonths_assignsCompletedExercisesAndExcludesOutsideRange() {
        guard
            let refNow = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 12)),
            let insideWeek = calendar.date(from: DateComponents(year: 2024, month: 4, day: 10, hour: 8)),
            let oldDay = calendar.date(from: DateComponents(year: 2024, month: 3, day: 17, hour: 8))
        else {
            XCTFail("dates")
            return
        }

        let fuerza = makeExercise(name: "Dominadas", category: "Fuerza general")
        let movilidad = makeExercise(name: "Movilidad", category: "Movilidad")
        let inside = WorkoutDay(
            date: insideWeek,
            name: "",
            notes: "",
            entries: [
                makeEntry(exercise: fuerza, isDone: true),
                makeEntry(exercise: fuerza, isDone: true),
                makeEntry(exercise: fuerza, isDone: false),
                makeEntry(exercise: movilidad, isDone: true)
            ]
        )
        let older = WorkoutDay(
            date: oldDay,
            name: "",
            notes: "",
            entries: [makeEntry(exercise: fuerza, isDone: true)]
        )

        let options = ProgressCategoryCalculator.allCategoryOptions(from: [inside, older])
        guard let fuerzaOption = options.first(where: { $0.displayName == "Fuerza general" }) else {
            XCTFail("category")
            return
        }

        let buckets = ProgressCategoryCalculator.buckets(
            forCategoryKey: fuerzaOption.id,
            from: [inside, older],
            range: .threeMonths,
            now: refNow,
            calendar: calendar
        )
        let snapshot = ProgressCategoryCalculator.snapshot(
            from: [inside, older],
            range: .threeMonths,
            now: refNow,
            calendar: calendar
        )

        XCTAssertEqual(buckets.count, 13)
        let bucket = buckets.first { $0.axisLabel == "8–14" }
        XCTAssertEqual(bucket?.completedCount, 2)
        XCTAssertEqual(buckets.reduce(0) { $0 + $1.completedCount }, 2)
        XCTAssertEqual(snapshot.series.first { $0.displayName == "Fuerza general" }?.totalInRange, 2)
        XCTAssertEqual(
            snapshot.series.first { $0.displayName == "Fuerza general" }?.buckets.reduce(0) { $0 + $1.completedCount },
            2
        )
    }
}
