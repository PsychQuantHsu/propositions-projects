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
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
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
            let cites = (object["cites"] as? [Any])?.compactMap { $0 as? String } ?? []
            // `retired` is an object from schema v1.4 on; any value but null and false retires.
            let retiredValue = object["retired"]
            let retired = !(retiredValue == nil || retiredValue is NSNull || (retiredValue as? Bool) == false)
            propositions.append(LedgerProposition(
                id: id, rawLocation: raw, location: raw.flatMap(Location.parse),
                cites: cites, retired: retired, ledgerLine: number))
        }
        self.propositions = propositions
        self.unreadable = unreadable
    }
}
