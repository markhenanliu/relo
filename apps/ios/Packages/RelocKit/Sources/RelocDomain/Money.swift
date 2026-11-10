/// An amount of money stored as integer minor units (cents), never floating point.
public struct Money: Hashable, Sendable, Codable, Comparable {
    public var cents: Int64
    public var currency: String

    public init(cents: Int64, currency: String = "USD") {
        self.cents = cents
        self.currency = currency
    }

    /// Convenience for whole-dollar amounts, e.g. `Money(dollars: 8_500)`.
    public init(dollars: Int64, currency: String = "USD") {
        self.init(cents: dollars * 100, currency: currency)
    }

    public static func zero(_ currency: String = "USD") -> Money {
        Money(cents: 0, currency: currency)
    }

    public static func + (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Currency mismatch: \(lhs.currency) vs \(rhs.currency)")
        return Money(cents: lhs.cents + rhs.cents, currency: lhs.currency)
    }

    public static func - (lhs: Money, rhs: Money) -> Money {
        precondition(lhs.currency == rhs.currency, "Currency mismatch: \(lhs.currency) vs \(rhs.currency)")
        return Money(cents: lhs.cents - rhs.cents, currency: lhs.currency)
    }

    public static func < (lhs: Money, rhs: Money) -> Bool {
        precondition(lhs.currency == rhs.currency, "Currency mismatch: \(lhs.currency) vs \(rhs.currency)")
        return lhs.cents < rhs.cents
    }

    /// Multiplies by `numerator / denominator`, rounding half up to the nearest cent.
    public func scaled(by numerator: Int64, over denominator: Int64) -> Money {
        precondition(denominator > 0, "Denominator must be positive")
        let product = cents * numerator
        let rounded = (product * 2 + denominator) / (denominator * 2)
        return Money(cents: rounded, currency: currency)
    }
}

extension Sequence where Element == Money {
    /// Sums amounts; returns zero in `currency` for an empty sequence.
    public func sum(currency: String = "USD") -> Money {
        reduce(.zero(currency), +)
    }
}
