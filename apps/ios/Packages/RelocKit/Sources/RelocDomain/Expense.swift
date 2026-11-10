import Foundation

/// Who paid for an expense. Determines whether it uses up the user's allowance
/// and whether it counts toward clawback "relocation costs". PRD EXP-4.
public enum Payer: String, Hashable, Sendable, Codable, CaseIterable {
    /// Paid out of pocket (or out of a lump sum already received).
    case me
    /// Paid by the employer, e.g. a reimbursement or company card.
    case employer
    /// Billed directly to the employer by a relocation vendor (e.g. movers).
    case vendorDirect = "vendor_direct"
}

public struct Expense: Hashable, Sendable, Codable, Identifiable {
    public var id: UUID
    public var amount: Money
    public var occurredOn: CalendarDate
    public var merchant: String
    public var categoryID: String
    public var payer: Payer
    public var missingReceipt: Bool

    public init(
        id: UUID = UUID(),
        amount: Money,
        occurredOn: CalendarDate,
        merchant: String,
        categoryID: String,
        payer: Payer = .me,
        missingReceipt: Bool = false
    ) {
        self.id = id
        self.amount = amount
        self.occurredOn = occurredOn
        self.merchant = merchant
        self.categoryID = categoryID
        self.payer = payer
        self.missingReceipt = missingReceipt
    }
}
