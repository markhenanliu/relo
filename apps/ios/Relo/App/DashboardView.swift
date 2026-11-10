import RelocDomain
import SwiftUI

/// M0 placeholder dashboard (PRD MOVE-2). Shows that the app target links RelocDomain
/// and renders domain results. Real data arrives with the local database in M1.
@Observable
@MainActor
final class DashboardModel {
    var allowance: Allowance
    var expenses: [Expense]
    var clawback: ClawbackRule
    var today: CalendarDate

    init(allowance: Allowance, expenses: [Expense], clawback: ClawbackRule, today: CalendarDate) {
        self.allowance = allowance
        self.expenses = expenses
        self.clawback = clawback
        self.today = today
    }

    var summary: AllowanceSummary { allowance.summarize(expenses) }

    var clawbackIfLeavingToday: ClawbackEstimate {
        clawback.estimate(departure: today, relocationCosts: allowance.total ?? .zero())
    }

    /// Fictional sample data until persistence exists.
    static var preview: DashboardModel {
        let day = CalendarDate(year: 2026, month: 11, day: 20)
        return DashboardModel(
            allowance: Allowance(total: Money(dollars: 8_500)),
            expenses: [
                Expense(amount: Money(cents: 8_742), occurredOn: day, merchant: "Home Depot", categoryID: "packing"),
                Expense(amount: Money(dollars: 250), occurredOn: day, merchant: "Storage deposit", categoryID: "storage"),
            ],
            clawback: ClawbackRule(windowMonths: 12, startDate: CalendarDate(year: 2027, month: 3, day: 15)),
            today: day
        )
    }
}

struct DashboardView: View {
    let model: DashboardModel

    var body: some View {
        NavigationStack {
            List {
                Section("Allowance") {
                    LabeledContent("Spent", value: model.summary.spent.formatted)
                    if let remaining = model.summary.remaining {
                        LabeledContent("Remaining", value: remaining.formatted)
                    }
                }
                Section {
                    LabeledContent("Window ends", value: model.clawback.windowEnd.description)
                    LabeledContent("If you left today", value: model.clawbackIfLeavingToday.amountOwed.formatted)
                } header: {
                    Text("Repayment (clawback)")
                } footer: {
                    Text("Estimate only. Counts complete months served and assumes relocation costs equal the allowance.")
                }
            }
            .navigationTitle("Relo")
        }
    }
}

extension Money {
    var formatted: String {
        (Decimal(cents) / 100).formatted(.currency(code: currency))
    }
}

#Preview {
    DashboardView(model: .preview)
}
