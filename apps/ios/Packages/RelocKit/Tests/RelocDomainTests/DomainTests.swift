import Testing
@testable import RelocDomain

@Suite("Money")
struct MoneyTests {
    @Test func scalingRoundsHalfUp() {
        #expect(Money(cents: 1).scaled(by: 1, over: 2).cents == 1)   // 0.5 → 1
        #expect(Money(cents: 1).scaled(by: 1, over: 3).cents == 0)   // 0.33 → 0
        #expect(Money(cents: 2).scaled(by: 1, over: 3).cents == 1)   // 0.67 → 1
        #expect(Money(dollars: 8_500).scaled(by: 8, over: 12).cents == 566_667)
    }

    @Test func sumOfEmptyIsZero() {
        #expect([Money]().sum() == .zero())
    }
}

@Suite("CalendarDate")
struct CalendarDateTests {
    @Test func parsesAndFormatsISO() throws {
        let date = try #require(CalendarDate(iso: "2027-03-15"))
        #expect(date.description == "2027-03-15")
    }

    @Test(arguments: ["2027-02-29", "2027-13-01", "2027-00-10", "27-1-1x", "", "2027-04-31"])
    func rejectsInvalidDates(_ text: String) {
        #expect(CalendarDate(iso: text) == nil)
    }

    @Test func acceptsLeapDay() {
        #expect(CalendarDate(iso: "2028-02-29") != nil)
    }

    @Test func addingMonthsClampsToMonthEnd() {
        let jan31 = CalendarDate(year: 2028, month: 1, day: 31)
        #expect(jan31.adding(months: 1).description == "2028-02-29")
        #expect(jan31.adding(months: 13).description == "2029-02-28")
    }

    @Test func completeMonthsCountsOnlyFullMonths() {
        let start = CalendarDate(year: 2027, month: 3, day: 15)
        #expect(start.completeMonths(until: CalendarDate(year: 2027, month: 4, day: 14)) == 0)
        #expect(start.completeMonths(until: CalendarDate(year: 2027, month: 4, day: 15)) == 1)
        #expect(start.completeMonths(until: CalendarDate(year: 2026, month: 12, day: 1)) == 0)
    }
}

@Suite("Allowance")
struct AllowanceTests {
    let day = CalendarDate(year: 2026, month: 12, day: 1)

    func expense(_ dollars: Int64, _ category: String, _ payer: Payer = .me) -> Expense {
        Expense(amount: Money(dollars: dollars), occurredOn: day, merchant: "Test", categoryID: category, payer: payer)
    }

    @Test func lumpSumRemainingCountsOnlyMyPayments() {
        let allowance = Allowance(total: Money(dollars: 8_500))
        let summary = allowance.summarize([
            expense(100, "packing"),
            expense(2_400, "movers"),
            expense(3_000, "movers", .vendorDirect),
        ])

        #expect(summary.spent == Money(dollars: 2_500))
        #expect(summary.remaining == Money(dollars: 6_000))
        #expect(summary.paidByEmployerOrVendor == Money(dollars: 3_000))
        #expect(summary.status == .ok)
    }

    @Test func warnsAtEightyPercentAndFlagsOverspend() {
        let allowance = Allowance(total: Money(dollars: 1_000))
        #expect(allowance.summarize([expense(799, "a")]).status == .ok)
        #expect(allowance.summarize([expense(800, "a")]).status == .warning)
        #expect(allowance.summarize([expense(1_000, "a")]).status == .warning)
        #expect(allowance.summarize([expense(1_001, "a")]).status == .over)
    }

    @Test func categoryCapsAreReportedEvenWithNoSpend() {
        let allowance = Allowance(total: nil, categoryCaps: ["storage": Money(dollars: 2_000), "fuel": Money(dollars: 300)])
        let summary = allowance.summarize([expense(1_700, "storage"), expense(50, "meals")])

        #expect(summary.remaining == nil)
        #expect(summary.byCategory.map(\.categoryID) == ["fuel", "meals", "storage"])
        let storage = summary.byCategory.first { $0.categoryID == "storage" }
        #expect(storage?.status == .warning)
        let fuel = summary.byCategory.first { $0.categoryID == "fuel" }
        #expect(fuel?.spent == .zero())
        #expect(fuel?.status == .ok)
    }
}

@Suite("BoxCode")
struct BoxCodeTests {
    @Test func formatsWithThreeDigits() {
        #expect(BoxCode(prefix: "K", number: 14).description == "K-014")
        #expect(BoxCode(prefix: "LR", number: 123).description == "LR-123")
    }

    @Test func parsesCaseInsensitively() {
        #expect(BoxCode("lr-7") == BoxCode(prefix: "LR", number: 7))
        #expect(BoxCode("K014") == nil)
        #expect(BoxCode("K-0") == nil)
        #expect(BoxCode("K-1000") == nil)
    }

    @Test(arguments: [
        ("Kitchen", "K"),
        ("Living Room", "LR"),
        ("Primary bedroom closet", "PB"),
        ("2nd-floor bath", "FB"),
        ("???", "X"),
    ])
    func derivesPrefixFromRoom(room: String, expected: String) {
        #expect(BoxCode.prefix(forRoom: room) == expected)
    }

    @Test func nextCodeIsSequentialPerPrefix() {
        let existing = [BoxCode(prefix: "K", number: 1), BoxCode(prefix: "K", number: 4), BoxCode(prefix: "B", number: 9)]
        #expect(BoxCode.next(prefix: "K", existing: existing) == BoxCode(prefix: "K", number: 5))
        #expect(BoxCode.next(prefix: "LR", existing: existing) == BoxCode(prefix: "LR", number: 1))
    }
}
