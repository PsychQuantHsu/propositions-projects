import Foundation

/// What the citation-order check needs of one ledger line.
public struct LedgerProposition: Equatable, Sendable {
    public let id: String
    /// The raw `location`, kept so that a message can quote it.
    public let rawLocation: String?
    public let location: Location?
    public let cites: [String]
    public let retired: Bool
    /// The 1-based line of the ledger file the proposition was read from.
    public let ledgerLine: Int
}

/// A ledger read line by line. Lines that could not be read are reported, never guessed at.
public struct Ledger: Sendable {
    public let propositions: [LedgerProposition]
    /// One message per ledger line that is not a JSON object with a string `id`.
    public let unreadable: [String]

    public init(propositions: [LedgerProposition], unreadable: [String]) {
        self.propositions = propositions
        self.unreadable = unreadable
    }

    public init(jsonl text: String) {
        var propositions: [LedgerProposition] = []
        var unreadable: [String] = []
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        for (index, line) in lines.enumerated() {
            let number = index + 1
            // Empty lines and lines that begin with `//` are skipped, as docs/SCHEMA.md has it.
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("//") { continue }
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                unreadable.append("line \(number): not a JSON object")
                continue
            }
            guard let id = object["id"] as? String, !id.isEmpty else {
                unreadable.append("line \(number): no string id")
                continue
            }
            let raw = object["location"] as? String
            // A `cites` that is there and is not a list of strings is reported. The proposition is
            // kept, with no citation of its own, so that citations of it are still checked.
            var cites: [String] = []
            if let value = object["cites"] {
                if let strings = value as? [String] {
                    cites = strings
                } else {
                    unreadable.append("line \(number): the cites of \(id) is not a list of strings")
                }
            }
            let retired = Ledger.isRetired(object["retired"])
            propositions.append(LedgerProposition(
                id: id, rawLocation: raw, location: raw.flatMap(Location.parse),
                cites: cites, retired: retired, ledgerLine: number))
        }
        self.propositions = propositions
        self.unreadable = unreadable
    }

    /// Whether a `retired` value retires its proposition: only a well-formed block does, as
    /// `retired_problem` of the Python validator has it. A block that is not well formed buys no
    /// exemption, and the proposition is checked like any other.
    static func isRetired(_ value: Any?) -> Bool {
        guard let block = value as? [String: Any],
              let since = block["since"] as? String, isCalendarDate(since),
              let mechanism = block["mechanism"] as? String,
              ["comment_env", "line_comment", "removed"].contains(mechanism),
              let match = block["match"] as? String, ["exact", "by_reading"].contains(match),
              let reason = block["reason"] as? String,
              !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return false }
        return true
    }

    private static func isCalendarDate(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard text.count == 10, parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]), year >= 1
        else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components) else { return false }
        return calendar.dateComponents([.year, .month, .day], from: date) == components
    }
}
