import XCTest
@testable import datotabe

final class FifthBatchUtilityTests: XCTestCase {
    func testTaxIncludedCalculationUsesConfiguredRounding() {
        let result = TaxCalculator.fromTaxIncluded(
            totalInclTax: 1_100,
            rate: 0.10,
            rounding: .floor
        )

        XCTAssertEqual(result.subtotalExclTax, 1_000)
        XCTAssertEqual(result.taxAmount, 100)
        XCTAssertEqual(result.totalInclTax, 1_100)
    }

    func testBusinessDateUsesBoundaryHour() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let beforeBoundary = calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 25,
            hour: 4,
            minute: 30
        ))!
        let afterBoundary = calendar.date(from: DateComponents(
            year: 2026,
            month: 4,
            day: 25,
            hour: 5,
            minute: 0
        ))!

        XCTAssertEqual(
            BusinessDate.dayKey(BusinessDate.businessDate(
                for: beforeBoundary,
                calendar: calendar,
                policy: BusinessDatePolicy(dayBoundaryHour: 5)
            ), calendar: calendar),
            "2026-04-24"
        )
        XCTAssertEqual(
            BusinessDate.dayKey(BusinessDate.businessDate(
                for: afterBoundary,
                calendar: calendar,
                policy: BusinessDatePolicy(dayBoundaryHour: 5)
            ), calendar: calendar),
            "2026-04-25"
        )
    }

    func testMatchCheckerAllowsTolerance() {
        let matched = MatchChecker.compare(code: "cash", left: 10_000, right: 9_999, tolerance: 1)
        let mismatched = MatchChecker.compare(code: "cash", left: 10_000, right: 9_998, tolerance: 1)

        XCTAssertTrue(matched.isMatched)
        XCTAssertFalse(mismatched.isMatched)
    }

    func testJSONStoreRoundTripsCodableValue() {
        let suiteName = "FifthBatchUtilityTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        AppJSONStore.save(["a", "b"], key: "items", defaults: defaults)
        let loaded = AppJSONStore.load([String].self, key: "items", fallback: [], defaults: defaults)

        XCTAssertEqual(loaded, ["a", "b"])
    }
}
