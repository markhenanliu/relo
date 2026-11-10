/// A calendar date with no time or time zone (e.g. a start date written in a contract).
///
/// Contract dates are calendar days, not instants. Modelling them as `Date` invites
/// off-by-one-day bugs when the device's time zone changes, so the domain uses this instead.
public struct CalendarDate: Hashable, Sendable, Codable, Comparable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(year: Int, month: Int, day: Int) {
        precondition((1...12).contains(month), "Month out of range: \(month)")
        precondition((1...CalendarDate.daysIn(year: year, month: month)).contains(day), "Day out of range: \(day)")
        self.year = year
        self.month = month
        self.day = day
    }

    /// Parses `YYYY-MM-DD`. Returns nil for anything else.
    public init?(iso: String) {
        let parts = iso.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(m), d >= 1, d <= CalendarDate.daysIn(year: y, month: m)
        else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var description: String {
        func pad(_ n: Int, _ width: Int) -> String {
            let s = String(n)
            return String(repeating: "0", count: max(0, width - s.count)) + s
        }
        return "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    public static func < (lhs: CalendarDate, rhs: CalendarDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Adds whole months, clamping the day to the target month's length (Jan 31 + 1 month = Feb 28/29).
    public func adding(months: Int) -> CalendarDate {
        let zeroBased = (year * 12 + (month - 1)) + months
        let y = zeroBased / 12
        let m = zeroBased % 12 + 1
        return CalendarDate(year: y, month: m, day: min(day, CalendarDate.daysIn(year: y, month: m)))
    }

    /// Number of complete months from `self` to `other` (0 if `other` is not after `self`).
    ///
    /// A month is complete once the same day-of-month is reached (clamped for short months),
    /// so 2027-03-15 → 2027-07-14 is 3 complete months and → 2027-07-15 is 4.
    public func completeMonths(until other: CalendarDate) -> Int {
        guard other > self else { return 0 }
        var months = (other.year - year) * 12 + (other.month - month)
        if adding(months: months) > other { months -= 1 }
        return max(0, months)
    }

    static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    static func daysIn(year: Int, month: Int) -> Int {
        switch month {
        case 2: return isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }
}
