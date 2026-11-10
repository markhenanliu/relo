/// A short, human-readable box label such as `K-014`. PRD BOX-1.
///
/// The prefix comes from the origin room so a box's code hints where it belongs;
/// the number is sequential per prefix within a move.
public struct BoxCode: Hashable, Sendable, Codable, CustomStringConvertible, Comparable {
    public let prefix: String
    public let number: Int

    public init(prefix: String, number: Int) {
        precondition(!prefix.isEmpty && prefix.allSatisfy { $0.isASCII && $0.isUppercase }, "Prefix must be uppercase ASCII letters")
        precondition((1...999).contains(number), "Box number must be 1–999")
        self.prefix = prefix
        self.number = number
    }

    /// Parses codes like `K-014` or `lr-7` (case-insensitive). Returns nil if malformed.
    public init?(_ text: String) {
        let parts = text.uppercased().split(separator: "-")
        guard parts.count == 2,
              !parts[0].isEmpty, parts[0].allSatisfy({ $0.isASCII && $0.isUppercase }),
              let n = Int(parts[1]), (1...999).contains(n)
        else { return nil }
        self.init(prefix: String(parts[0]), number: n)
    }

    public var description: String {
        let digits = String(number)
        return "\(prefix)-\(String(repeating: "0", count: max(0, 3 - digits.count)))\(digits)"
    }

    public static func < (lhs: BoxCode, rhs: BoxCode) -> Bool {
        (lhs.prefix, lhs.number) < (rhs.prefix, rhs.number)
    }

    /// Derives a prefix from a room name: initials of up to two words ("Living Room" → "LR",
    /// "Kitchen" → "K"). Words that don't start with a letter ("2nd") are skipped.
    /// Falls back to "X" when no word starts with a letter.
    public static func prefix(forRoom room: String) -> String {
        let words = room
            .split(whereSeparator: { $0.isWhitespace || $0 == "-" || $0 == "_" || $0 == "/" })
            .filter { $0.first.map { $0.isASCII && $0.isLetter } ?? false }
        let initials = words.prefix(2).compactMap(\.first)
        let prefix = String(initials).uppercased()
        return prefix.isEmpty ? "X" : prefix
    }

    /// The next free code for `prefix`, given codes already used in the move.
    public static func next(prefix: String, existing: some Sequence<BoxCode>) -> BoxCode {
        let highest = existing.filter { $0.prefix == prefix }.map(\.number).max() ?? 0
        return BoxCode(prefix: prefix, number: highest + 1)
    }
}
