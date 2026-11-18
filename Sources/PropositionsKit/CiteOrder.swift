import Foundation

/// One citation that points to a proposition later in reading order.
public struct ForwardCitation: Equatable, Sendable {
    public let from: String
    public let fromLocation: String
    public let to: String
    public let toLocation: String
}

/// The result of the citation-order check.
public struct CiteOrderReport: Equatable, Sendable {
    /// How many citations were compared.
    public let checked: Int
    public let forward: [ForwardCitation]
    /// What could not be read. When this is not empty the check is incomplete.
    public let unreadable: [String]

    public var isComplete: Bool { unreadable.isEmpty }
}

/// The check behind the obligation `dependence.cites-backward`: every proposition a
/// proposition cites comes earlier in reading order. It reports; it does not judge which
/// forward citations are a roadmap or a promissory note.
public enum CiteOrder {
    public static func check(ledger: Ledger, order: ReadingOrder) -> CiteOrderReport {
        var unreadable = ledger.unreadable
        var positions: [String: [Int]] = [:]
        var shown: [String: String] = [:]
        var active: [LedgerProposition] = []

        for proposition in ledger.propositions where !proposition.retired {
            guard let location = proposition.location else {
                let raw = proposition.rawLocation.map { "'\($0)'" } ?? "missing"
                unreadable.append(
                    "line \(proposition.ledgerLine): the location of \(proposition.id) is \(raw), not [<file>.tex:]L<a>[-L<b>]")
                continue
            }
            guard let position = order.position(file: location.file, line: location.start) else {
                unreadable.append(
                    "line \(proposition.ledgerLine): the location of \(proposition.id) names \(location.file ?? "main.tex"), which the input tree does not hold")
                continue
            }
            // A second proposition with the same id is R8's concern; the first one keeps the id.
            if positions[proposition.id] == nil {
                positions[proposition.id] = position
                shown[proposition.id] = proposition.rawLocation ?? ""
            }
            active.append(proposition)
        }

        var checked = 0
        var forward: [ForwardCitation] = []
        for proposition in active {
            guard let here = positions[proposition.id] else { continue }
            for cited in proposition.cites {
                // An id the ledger does not hold, a retired one, or one whose position is unknown.
                guard let there = positions[cited] else { continue }
                checked += 1
                if ReadingOrder.precedes(here, there) {
                    forward.append(ForwardCitation(
                        from: proposition.id, fromLocation: shown[proposition.id] ?? "",
                        to: cited, toLocation: shown[cited] ?? ""))
                }
            }
        }
        return CiteOrderReport(checked: checked, forward: forward, unreadable: unreadable)
    }

    /// The lines the command prints: one per unreadable item, one per warning, then the count.
    public static func render(_ report: CiteOrderReport) -> [String] {
        var lines = report.unreadable.map { "UNREADABLE cite-order: \($0)" }
        lines += report.forward.map {
            "WARN cite-order: \($0.from) (\($0.fromLocation)) cites \($0.to) (\($0.toLocation)), which comes later"
        }
        lines.append("cite-order: \(report.forward.count) forward citation(s) among \(report.checked) citation(s) checked")
        if !report.isComplete {
            lines.append("cite-order: incomplete, \(report.unreadable.count) item(s) could not be read")
        }
        return lines
    }

    /// The object the command prints with `--json`.
    public static func renderJSON(_ report: CiteOrderReport) throws -> String {
        let object: [String: Any] = [
            "checked": report.checked,
            "forward": report.forward.map {
                ["from": $0.from, "fromLocation": $0.fromLocation, "to": $0.to, "toLocation": $0.toLocation]
            },
            "unreadable": report.unreadable,
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        return String(decoding: data, as: UTF8.self)
    }
}
