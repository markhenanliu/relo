/// A relocation repayment ("clawback") clause: what you owe if you leave within a window.
///
/// Models the common pattern "repay 1/N of relocation costs for each month short of N,
/// not to exceed a cap". PRD requirements CLAW-1 through CLAW-3.
public struct ClawbackRule: Hashable, Sendable, Codable {
    /// Length of the window in months, counted from the start date (e.g. 12).
    public var windowMonths: Int
    /// The day the window starts (usually the start date in the new location).
    public var startDate: CalendarDate
    /// Upper limit on the amount owed, if any (e.g. one month's salary).
    public var cap: Money?

    public init(windowMonths: Int, startDate: CalendarDate, cap: Money? = nil) {
        precondition(windowMonths > 0, "Window must be at least one month")
        self.windowMonths = windowMonths
        self.startDate = startDate
        self.cap = cap
    }

    /// The first day on which nothing is owed.
    public var windowEnd: CalendarDate {
        startDate.adding(months: windowMonths)
    }

    /// Estimates what would be owed if employment ended on `departure`.
    ///
    /// Assumption (shown to the user): only *complete* months count as served, so leaving
    /// mid-month owes as if that month were not served. This errs on the side of the
    /// larger amount, which is the safer number to plan around.
    public func estimate(departure: CalendarDate, relocationCosts: Money) -> ClawbackEstimate {
        let served = min(startDate.completeMonths(until: departure), windowMonths)
        let remaining = windowMonths - served
        let prorated = relocationCosts.scaled(by: Int64(remaining), over: Int64(windowMonths))

        var owed = prorated
        var capApplied = false
        if let cap, cap < prorated {
            owed = cap
            capApplied = true
        }

        return ClawbackEstimate(
            monthsServed: served,
            monthsRemaining: remaining,
            proratedAmount: prorated,
            amountOwed: owed,
            capApplied: capApplied,
            windowEnd: windowEnd
        )
    }
}

public struct ClawbackEstimate: Hashable, Sendable, Codable {
    public var monthsServed: Int
    public var monthsRemaining: Int
    /// Amount before any cap.
    public var proratedAmount: Money
    /// Amount after the cap.
    public var amountOwed: Money
    public var capApplied: Bool
    public var windowEnd: CalendarDate
}
