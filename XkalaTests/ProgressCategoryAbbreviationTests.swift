import XCTest
@testable import Xkala

final class ProgressCategoryAbbreviationTests: XCTestCase {
    func test_acondicionamientoUsesAC() {
        XCTAssertEqual(ProgressCategoryAbbreviation.shortLabel(for: "Acondicionamiento"), "AC")
    }

    func test_fixedAbbreviations_ignoreCaseAndAccents() {
        XCTAssertEqual(ProgressCategoryAbbreviation.shortLabel(for: "Fuerza máxima"), "FM")
        XCTAssertEqual(ProgressCategoryAbbreviation.shortLabel(for: "fuerza maxima"), "FM")
        XCTAssertEqual(ProgressCategoryAbbreviation.shortLabel(for: "Resistencia"), "RE")
        XCTAssertEqual(ProgressCategoryAbbreviation.shortLabel(for: "Recuperación"), "RP")
        XCTAssertEqual(ProgressCategoryAbbreviation.shortLabel(for: "Técnica"), "TC")
    }

    func test_distinctFixedLabels_doNotCollide() {
        let labels = ["Resistencia", "Recuperación", "Técnica", "Acondicionamiento"]
        let shorts = Set(labels.map { ProgressCategoryAbbreviation.shortLabel(for: $0) })
        XCTAssertEqual(shorts, ["RE", "RP", "TC", "AC"])
    }

    func test_fallbackInitials_twoWords() {
        XCTAssertEqual(ProgressCategoryAbbreviation.shortLabel(for: "Movilidad articular"), "MA")
        XCTAssertEqual(ProgressCategoryAbbreviation.shortLabel(for: "Fuerza dedos"), "FD")
    }

    func test_fallbackInitials_singleWord() {
        XCTAssertEqual(ProgressCategoryAbbreviation.shortLabel(for: "Continuidad"), "CO")
    }
}
