import XCTest
@testable import Xkala

@MainActor
final class CurrentTestStateCalculatorTests: XCTestCase {

    private let dayOld = Date(timeIntervalSince1970: 0)
    private let dayMid = Date(timeIntervalSince1970: 86_400 * 10)
    private let dayNew = Date(timeIntervalSince1970: 86_400 * 20)

    // MARK: - Helpers

    private func makeExercise(
        name: String,
        category: String = "Test",
        mode: String = "reps",
        loadAllowed: Bool = false
    ) -> Exercise {
        Exercise(name: name, category: category, mode: mode, loadAllowed: loadAllowed)
    }

    private func makeEntry(
        exercise: Exercise,
        reps: Int? = nil,
        seconds: Int? = nil,
        loadKg: Double? = nil,
        isDone: Bool = true
    ) -> WorkoutEntry {
        WorkoutEntry(
            exercise: exercise,
            isDone: isDone,
            sets: [SetRecord(reps: reps, seconds: seconds, loadKg: loadKg)]
        )
    }

    private func makeWorkout(date: Date, entries: [WorkoutEntry]) -> WorkoutDay {
        WorkoutDay(date: date, entries: entries)
    }

    // MARK: - Vacío / exclusión

    func test_snapshot_withoutTests_isEmpty() {
        let exercise = makeExercise(name: "Dominadas", category: "Fuerza")
        let entry = makeEntry(exercise: exercise, reps: 10)
        let workouts = [makeWorkout(date: dayNew, entries: [entry])]

        let snapshot = CurrentTestStateCalculator.snapshot(from: workouts)

        XCTAssertFalse(snapshot.hasData)
        XCTAssertTrue(snapshot.resultsByCapacity.isEmpty)
    }

    func test_snapshot_excludesIncompleteAndInvalidSets() {
        let exercise = makeExercise(name: "Test de dominadas libres")
        let incomplete = makeEntry(exercise: exercise, reps: 20, isDone: false)
        let invalid = makeEntry(exercise: exercise, reps: 0, isDone: true)
        let workouts = [
            makeWorkout(date: dayOld, entries: [incomplete]),
            makeWorkout(date: dayNew, entries: [invalid]),
        ]

        let snapshot = CurrentTestStateCalculator.snapshot(from: workouts)

        XCTAssertFalse(snapshot.hasData)
    }

    // MARK: - Agrupación por capacidad

    func test_snapshot_groupsByTestCapacity() {
        let pull = makeExercise(name: "Test de dominadas con lastre", loadAllowed: true)
        let fingers = makeExercise(
            name: "Test de hangboard con lastre",
            mode: "seconds",
            loadAllowed: true
        )
        let pullEntry = makeEntry(exercise: pull, reps: 3, loadKg: 40)
        let fingerEntry = makeEntry(exercise: fingers, seconds: 50, loadKg: 18)
        let workouts = [
            makeWorkout(date: dayNew, entries: [pullEntry, fingerEntry]),
        ]

        let snapshot = CurrentTestStateCalculator.snapshot(from: workouts)

        XCTAssertTrue(snapshot.hasData)
        XCTAssertNotNil(snapshot.resultsByCapacity[.pullingStrength])
        XCTAssertNotNil(snapshot.resultsByCapacity[.fingerStrength])
        XCTAssertNil(snapshot.resultsByCapacity[.pullingEndurance])

        XCTAssertEqual(
            snapshot.resultsByCapacity[.pullingStrength]?.resultText,
            "+40 kg × 3 reps"
        )
        XCTAssertEqual(
            snapshot.resultsByCapacity[.fingerStrength]?.resultText,
            "+18 kg · 50 s"
        )
        XCTAssertEqual(snapshot.resultsByCapacity[.pullingStrength]?.lastTestDate, dayNew)
        XCTAssertEqual(snapshot.resultsByCapacity[.fingerStrength]?.lastTestDate, dayNew)
    }

    // MARK: - Fecha más reciente por capacidad

    func test_snapshot_selectsMostRecentValidResultPerCapacity() {
        // Dos tests de la misma capacidad (fuerza de tracción).
        let weighted = makeExercise(name: "Test de dominadas con lastre", loadAllowed: true)
        let weightedNeg = makeExercise(name: "Test de dominadas con lastre negativo", loadAllowed: true)

        let oldEntry = makeEntry(exercise: weighted, reps: 3, loadKg: 30)
        let newEntry = makeEntry(exercise: weightedNeg, reps: 2, loadKg: 35)
        // Entrada inválida más reciente no debe ganar
        let invalidNewer = makeEntry(exercise: weighted, reps: 0)
        let workouts = [
            makeWorkout(date: dayOld, entries: [oldEntry]),
            makeWorkout(date: dayMid, entries: [newEntry]),
            makeWorkout(date: dayNew, entries: [invalidNewer]),
        ]

        let snapshot = CurrentTestStateCalculator.snapshot(from: workouts)

        let result = snapshot.resultsByCapacity[.pullingStrength]
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.testName, "Test de dominadas con lastre negativo")
        XCTAssertEqual(result?.resultText, "+35 kg × 2 reps")
        XCTAssertEqual(result?.lastTestDate, dayMid)
    }

    func test_snapshot_hidesCapacitiesWithoutUsableResults() {
        let pull = makeExercise(name: "Test de dominadas libres")
        let press = makeExercise(name: "Test de press banca", loadAllowed: true)
        let validPull = makeEntry(exercise: pull, reps: 18)
        let invalidPress = makeEntry(exercise: press, reps: 0, loadKg: 60)
        let workouts = [makeWorkout(date: dayNew, entries: [validPull, invalidPress])]

        let snapshot = CurrentTestStateCalculator.snapshot(from: workouts)

        XCTAssertNotNil(snapshot.resultsByCapacity[.pullingEndurance])
        XCTAssertNil(snapshot.resultsByCapacity[.pushingStrength])
        XCTAssertEqual(snapshot.orderedCapacities, [.pullingEndurance])
    }

    // MARK: - Antigüedad compacta

    func test_ageText_formatsTodayDaysWeeksMonths() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let now = Date(timeIntervalSince1970: 86_400 * 60) // día ancla

        func result(daysAgo: Int) -> CurrentTestStateSnapshot.TestCapacityResult {
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
            return CurrentTestStateSnapshot.TestCapacityResult(
                testName: "Test",
                resultText: "10 reps",
                lastTestDate: date
            )
        }

        XCTAssertEqual(result(daysAgo: 0).ageText(relativeTo: now, calendar: calendar), "Hoy")
        XCTAssertEqual(result(daysAgo: 1).ageText(relativeTo: now, calendar: calendar), "Hace 1 día")
        XCTAssertEqual(result(daysAgo: 3).ageText(relativeTo: now, calendar: calendar), "Hace 3 días")
        XCTAssertEqual(result(daysAgo: 7).ageText(relativeTo: now, calendar: calendar), "Hace 1 semana")
        XCTAssertEqual(result(daysAgo: 14).ageText(relativeTo: now, calendar: calendar), "Hace 2 semanas")
        XCTAssertEqual(result(daysAgo: 30).ageText(relativeTo: now, calendar: calendar), "Hace 1 mes")
        XCTAssertEqual(result(daysAgo: 90).ageText(relativeTo: now, calendar: calendar), "Hace 3 meses")
    }
}
