import XCTest
@testable import Xkala

final class ActivityInsightResolverTests: XCTestCase {

    /// Construye un `GlobalStatsSnapshot` real con el inicializador de producción.
    /// Solo expone los campos relevantes para el resolver; el resto usa valores neutros.
    private func makeSnapshot(
        workoutsLast30Days: Int = 0,
        workoutsLast30DaysDelta: Int = 0,
        sessionLoadLast30Days: Int? = nil,
        sessionLoadLast30DaysDelta: Int? = nil
    ) -> GlobalStatsSnapshot {
        GlobalStatsSnapshot(
            totalWorkouts: 0,
            workoutsLast30Days: workoutsLast30Days,
            workoutsLast30DaysDelta: workoutsLast30DaysDelta,
            totalCompletedExercises: 0,
            favoriteCategory: "Sin datos",
            totalTrainingTime: 0,
            sessionLoadLast7Days: nil,
            sessionLoadLast30Days: sessionLoadLast30Days,
            sessionLoadLast30DaysDelta: sessionLoadLast30DaysDelta,
            lastTrainingMethod: nil,
            climbingStats: nil
        )
    }

    // MARK: - Inactividad

    func test_inactive_at7Days_returnsInactive() {
        let result = ActivityInsightResolver.resolve(
            snapshot: makeSnapshot(),
            daysSinceLastRealSession: 7
        )
        XCTAssertEqual(result, .inactive(days: 7))
    }

    func test_notInactive_below7Days() {
        // 6 días no dispara inactividad; con ambos periodos activos cae a estable.
        let snapshot = makeSnapshot(workoutsLast30Days: 5, workoutsLast30DaysDelta: 0)
        let result = ActivityInsightResolver.resolve(
            snapshot: snapshot,
            daysSinceLastRealSession: 6
        )
        XCTAssertEqual(result, .stable)
    }

    func test_inactivity_hasPriorityOverLoadAndFrequency() {
        // Carga y frecuencia al alza, pero la inactividad manda.
        let snapshot = makeSnapshot(
            workoutsLast30Days: 10,
            workoutsLast30DaysDelta: 5,
            sessionLoadLast30Days: 200,
            sessionLoadLast30DaysDelta: 150
        )
        let result = ActivityInsightResolver.resolve(
            snapshot: snapshot,
            daysSinceLastRealSession: 10
        )
        XCTAssertEqual(result, .inactive(days: 10))
    }

    func test_intMax_withEmptySnapshot_returnsNil() {
        let result = ActivityInsightResolver.resolve(
            snapshot: makeSnapshot(),
            daysSinceLastRealSession: Int.max
        )
        XCTAssertNil(result)
    }

    func test_intMax_doesNotBlockValidComparativeInsight() {
        // Int.max solo desactiva inactividad; el insight comparativo sí se evalúa.
        let snapshot = makeSnapshot(workoutsLast30Days: 6, workoutsLast30DaysDelta: 2)
        let result = ActivityInsightResolver.resolve(
            snapshot: snapshot,
            daysSinceLastRealSession: Int.max
        )
        XCTAssertEqual(result, .workoutsIncreased)
    }

    // MARK: - Carga

    func test_load_increaseBeyondBothThresholds_returnsLoadIncreased() {
        // anterior 100 → actual 140 (delta +40): abs 40 y 40% superan ambos umbrales.
        let snapshot = makeSnapshot(
            sessionLoadLast30Days: 140,
            sessionLoadLast30DaysDelta: 40
        )
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .loadIncreased)
    }

    func test_load_decreaseBeyondBothThresholds_returnsLoadDecreased() {
        // anterior 140 → actual 100 (delta -40): abs 40 y ~28.6% superan ambos umbrales.
        let snapshot = makeSnapshot(
            sessionLoadLast30Days: 100,
            sessionLoadLast30DaysDelta: -40
        )
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .loadDecreased)
    }

    func test_load_exactly25Percent_triggers() {
        // anterior 100 → actual 125 (delta +25): rel exactamente 0.25.
        let snapshot = makeSnapshot(
            sessionLoadLast30Days: 125,
            sessionLoadLast30DaysDelta: 25
        )
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .loadIncreased)
    }

    func test_load_below25Percent_doesNotTrigger() {
        // anterior 100 → actual 120 (delta +20): abs 20 pero rel 0.20 < 0.25 → no carga.
        // Con entrenos comparables cae a estable.
        let snapshot = makeSnapshot(
            workoutsLast30Days: 5,
            workoutsLast30DaysDelta: 0,
            sessionLoadLast30Days: 120,
            sessionLoadLast30DaysDelta: 20
        )
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .stable)
    }

    func test_load_exactly10PointsWith25Percent_triggers() {
        // anterior 40 → actual 50 (delta +10): abs exactamente 10 y rel exactamente 0.25.
        let snapshot = makeSnapshot(
            sessionLoadLast30Days: 50,
            sessionLoadLast30DaysDelta: 10
        )
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .loadIncreased)
    }

    func test_load_below10Points_doesNotTrigger() {
        // anterior 20 → actual 25 (delta +5): rel 0.25 pero abs 5 < 10 → no carga.
        let snapshot = makeSnapshot(
            workoutsLast30Days: 3,
            workoutsLast30DaysDelta: 0,
            sessionLoadLast30Days: 25,
            sessionLoadLast30DaysDelta: 5
        )
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .stable)
    }

    func test_load_currentNil_skipsLoadRule() {
        // Sin carga actual la regla de carga se salta; con entrenos comparables → estable.
        let snapshot = makeSnapshot(
            workoutsLast30Days: 5,
            workoutsLast30DaysDelta: 0,
            sessionLoadLast30Days: nil,
            sessionLoadLast30DaysDelta: nil
        )
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .stable)
    }

    func test_load_previousNotPositive_skipsLoadRule() {
        // actual 150, delta +150 → anterior 0: no cumple previousLoad > 0.
        let snapshot = makeSnapshot(
            workoutsLast30Days: 3,
            workoutsLast30DaysDelta: 0,
            sessionLoadLast30Days: 150,
            sessionLoadLast30DaysDelta: 150
        )
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .stable)
    }

    func test_load_hasPriorityOverFrequency() {
        // Carga notable + entrenos al alza: gana la carga.
        let snapshot = makeSnapshot(
            workoutsLast30Days: 10,
            workoutsLast30DaysDelta: 5,
            sessionLoadLast30Days: 140,
            sessionLoadLast30DaysDelta: 40
        )
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .loadIncreased)
    }

    // MARK: - Frecuencia

    func test_workouts_deltaPlus2_returnsWorkoutsIncreased() {
        let snapshot = makeSnapshot(workoutsLast30Days: 6, workoutsLast30DaysDelta: 2)
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .workoutsIncreased)
    }

    func test_workouts_deltaMinus2_returnsWorkoutsDecreased() {
        let snapshot = makeSnapshot(workoutsLast30Days: 4, workoutsLast30DaysDelta: -2)
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .workoutsDecreased)
    }

    func test_workouts_deltaPlus1_doesNotTriggerChange() {
        // delta +1 no alcanza el umbral; ambos periodos activos → estable.
        let snapshot = makeSnapshot(workoutsLast30Days: 5, workoutsLast30DaysDelta: 1)
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .stable)
    }

    // MARK: - Estable y nil

    func test_stable_bothPeriodsActive_smallChanges() {
        // Cambios pequeños en carga y frecuencia dentro de banda → estable.
        let snapshot = makeSnapshot(
            workoutsLast30Days: 5,
            workoutsLast30DaysDelta: 1,
            sessionLoadLast30Days: 105,
            sessionLoadLast30DaysDelta: 5
        )
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertEqual(result, .stable)
    }

    func test_nil_previousEmpty_insufficientChange() {
        // actual 1 entreno, anterior 0, delta +1 (< 2), sin carga → sin base fiable.
        let snapshot = makeSnapshot(workoutsLast30Days: 1, workoutsLast30DaysDelta: 1)
        let result = ActivityInsightResolver.resolve(snapshot: snapshot, daysSinceLastRealSession: 0)
        XCTAssertNil(result)
    }

    func test_nil_emptySnapshot() {
        let result = ActivityInsightResolver.resolve(
            snapshot: makeSnapshot(),
            daysSinceLastRealSession: 0
        )
        XCTAssertNil(result)
    }
}
