import Foundation

enum MoneyCalculator {
    static func sum<T>(_ values: [T], amount: (T) -> Int) -> Int {
        values.map(amount).reduce(0, +)
    }

    static func ratio(numerator: Double, denominator: Double) -> Double? {
        guard denominator > 0 else { return nil }
        return numerator / denominator
    }
}

enum TaxRoundingRule: String, CaseIterable, Identifiable, Codable {
    case floor
    case round
    case ceil

    var id: String { rawValue }

    var label: String {
        switch self {
        case .floor: return "切り捨て"
        case .round: return "四捨五入"
        case .ceil: return "切り上げ"
        }
    }

    func apply(_ value: Double) -> Int {
        let normalized = normalizedIntegerBoundary(value)
        switch self {
        case .floor:
            return Int(normalized.rounded(.down))
        case .round:
            return Int(normalized.rounded())
        case .ceil:
            return Int(normalized.rounded(.up))
        }
    }

    private func normalizedIntegerBoundary(_ value: Double) -> Double {
        let nearest = value.rounded()
        return abs(value - nearest) < 0.000_000_1 ? nearest : value
    }
}

struct TaxCalculationResult: Hashable, Codable {
    var subtotalExclTax: Int
    var taxAmount: Int
    var totalInclTax: Int
}

enum TaxCalculator {
    static func fromTaxIncluded(totalInclTax: Int, rate: Double, rounding: TaxRoundingRule) -> TaxCalculationResult {
        guard rate > 0 else {
            return TaxCalculationResult(
                subtotalExclTax: totalInclTax,
                taxAmount: 0,
                totalInclTax: totalInclTax
            )
        }

        let tax = rounding.apply(Double(totalInclTax) * rate / (1.0 + rate))
        return TaxCalculationResult(
            subtotalExclTax: totalInclTax - tax,
            taxAmount: tax,
            totalInclTax: totalInclTax
        )
    }

    static func fromTaxExcluded(subtotalExclTax: Int, rate: Double, rounding: TaxRoundingRule) -> TaxCalculationResult {
        let tax = rounding.apply(Double(subtotalExclTax) * max(rate, 0))
        return TaxCalculationResult(
            subtotalExclTax: subtotalExclTax,
            taxAmount: tax,
            totalInclTax: subtotalExclTax + tax
        )
    }
}

struct MatchCheckResult: Hashable, Codable {
    var code: String
    var left: Int
    var right: Int
    var tolerance: Int

    var difference: Int {
        left - right
    }

    var isMatched: Bool {
        abs(difference) <= tolerance
    }
}

enum MatchChecker {
    static func compare(code: String, left: Int, right: Int, tolerance: Int = 0) -> MatchCheckResult {
        MatchCheckResult(code: code, left: left, right: right, tolerance: max(tolerance, 0))
    }
}
