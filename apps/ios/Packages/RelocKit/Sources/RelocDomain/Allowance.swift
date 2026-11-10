/// The kinds of relocation package the app supports. PRD POL-2.
public enum PackageType: String, Hashable, Sendable, Codable, CaseIterable {
    /// A fixed amount the employee spends as they see fit.
    case lumpSum = "lump_sum"
    /// Receipts reimbursed against category caps.
    case itemized
    /// The employer's vendor pays for services directly.
    case vendorManaged = "vendor_managed"
    /// A mix, e.g. vendor-paid movers plus a smaller lump sum.
    case hybrid
}

/// What the user can spend under their policy. PRD EXP-6.
public struct Allowance: Hashable, Sendable, Codable {
    /// Overall amount available (the lump sum, or an overall itemized cap). Nil if unlimited.
    public var total: Money?
    /// Optional per-category limits, keyed by category ID.
    public var categoryCaps: [String: Money]

    public init(total: Money?, categoryCaps: [String: Money] = [:]) {
        self.total = total
        self.categoryCaps = categoryCaps
    }
}

public enum SpendStatus: String, Hashable, Sendable, Codable {
    case ok
    /// At or above the warning threshold (80% by default).
    case warning
    /// Above the limit.
    case over
}

public struct CategorySpend: Hashable, Sendable, Codable {
    public var categoryID: String
    public var spent: Money
    public var cap: Money?
    public var status: SpendStatus
}

public struct AllowanceSummary: Hashable, Sendable, Codable {
    /// Spending that uses the allowance (payer `.me` only).
    public var spent: Money
    /// Nil when there is no overall total.
    public var remaining: Money?
    public var status: SpendStatus
    /// Sorted by category ID for stable display and testing.
    public var byCategory: [CategorySpend]
    /// Paid directly by the employer or its vendors; doesn't use the allowance but may count toward clawback.
    public var paidByEmployerOrVendor: Money
}

extension Allowance {
    public func summarize(
        _ expenses: [Expense],
        currency: String = "USD",
        warningPercent: Int64 = 80
    ) -> AllowanceSummary {
        let mine = expenses.filter { $0.payer == .me }
        let spent = mine.map(\.amount).sum(currency: currency)
        let others = expenses.filter { $0.payer != .me }.map(\.amount).sum(currency: currency)

        var perCategory: [String: Money] = [:]
        for expense in mine {
            perCategory[expense.categoryID, default: .zero(currency)] =
                perCategory[expense.categoryID, default: .zero(currency)] + expense.amount
        }
        let categoryIDs = Set(perCategory.keys).union(categoryCaps.keys).sorted()
        let byCategory = categoryIDs.map { id in
            let amount = perCategory[id] ?? .zero(currency)
            let cap = categoryCaps[id]
            return CategorySpend(
                categoryID: id,
                spent: amount,
                cap: cap,
                status: Self.status(spent: amount, limit: cap, warningPercent: warningPercent)
            )
        }

        return AllowanceSummary(
            spent: spent,
            remaining: total.map { $0 - spent },
            status: Self.status(spent: spent, limit: total, warningPercent: warningPercent),
            byCategory: byCategory,
            paidByEmployerOrVendor: others
        )
    }

    static func status(spent: Money, limit: Money?, warningPercent: Int64) -> SpendStatus {
        guard let limit else { return .ok }
        if spent > limit { return .over }
        if spent.cents * 100 >= limit.cents * warningPercent { return .warning }
        return .ok
    }
}
