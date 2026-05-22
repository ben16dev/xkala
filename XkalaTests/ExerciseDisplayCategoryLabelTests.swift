import XCTest
@testable import Xkala

final class ExerciseDisplayCategoryLabelTests: XCTestCase {

    func testLegacyFuerzaDisplaysAsFuerzaGeneral() {
        let exercise = Exercise(name: "Dominadas", category: "Fuerza", mode: "reps", loadAllowed: false)
        XCTAssertEqual(exercise.displayCategoryLabel, "Fuerza general")
        XCTAssertEqual(exercise.category, "Fuerza")
    }

    func testLegacyResistenciaDisplaysAsAcondicionamiento() {
        let exercise = Exercise(name: "Circuito fluido", category: "Resistencia", mode: "reps", loadAllowed: false)
        XCTAssertEqual(exercise.displayCategoryLabel, "Acondicionamiento")
    }

    func testCanonicalCategoryNamesUnchanged() {
        let exercise = Exercise(name: "Suspensiones", category: "Hangboard", mode: "seconds", loadAllowed: false)
        XCTAssertEqual(exercise.displayCategoryLabel, "Hangboard")
    }

    func testUnknownCategoryFallsBackToPersistedValue() {
        let exercise = Exercise(name: "Custom", category: "Mi categoría", mode: "reps", loadAllowed: false)
        XCTAssertEqual(exercise.displayCategoryLabel, "Mi categoría")
    }
}
