import Foundation
import Testing
@testable import RelocDomain

/// Runs the shared vectors in `schemas/test-vectors/clawback.json` so the Swift
/// implementation stays identical to the database and web implementations.
@Suite("Clawback estimate")
struct ClawbackTests {
    struct Vectors: Decodable {
        let cases: [Case]
    }

    struct Case: Decodable, CustomTestStringConvertible {
        let name: String
        let startDate: String
        let windowMonths: Int
        let relocationCostsCents: Int64
        let capCents: Int64?
        let departure: String
        let expected: Expected

        var testDescription: String { name }
    }

    struct Expected: Decodable {
        let monthsServed: Int
        let monthsRemaining: Int
        let proratedCents: Int64
        let owedCents: Int64
        let capApplied: Bool
        let windowEnd: String
    }

    static let vectors: [Case] = {
        // Tests/RelocDomainTests → repo root is six levels up.
        let url = URL(filePath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "../../../../../../schemas/test-vectors/clawback.json")
            .standardized
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(Vectors.self, from: Data(contentsOf: url)).cases
        } catch {
            fatalError("Could not load clawback test vectors at \(url.path): \(error)")
        }
    }()

    @Test("Shared vectors", arguments: vectors)
    func sharedVector(_ vector: Case) throws {
        let start = try #require(CalendarDate(iso: vector.startDate))
        let departure = try #require(CalendarDate(iso: vector.departure))
        let rule = ClawbackRule(
            windowMonths: vector.windowMonths,
            startDate: start,
            cap: vector.capCents.map { Money(cents: $0) }
        )

        let estimate = rule.estimate(departure: departure, relocationCosts: Money(cents: vector.relocationCostsCents))

        #expect(estimate.monthsServed == vector.expected.monthsServed)
        #expect(estimate.monthsRemaining == vector.expected.monthsRemaining)
        #expect(estimate.proratedAmount.cents == vector.expected.proratedCents)
        #expect(estimate.amountOwed.cents == vector.expected.owedCents)
        #expect(estimate.capApplied == vector.expected.capApplied)
        #expect(estimate.windowEnd.description == vector.expected.windowEnd)
    }

    @Test func vectorsAreLoaded() {
        #expect(Self.vectors.count >= 10)
    }
}
