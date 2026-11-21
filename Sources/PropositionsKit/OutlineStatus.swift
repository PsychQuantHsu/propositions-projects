import Foundation

/// Whether each section still stands as approved, and whether the order of sections does.
///
/// The lines are those of the status command of the outline skill, so that the skill can call
/// this in its place: a name and an answer separated by a tab, and `ok status` last.
public enum OutlineStatus {
    public struct Failure: Error, CustomStringConvertible {
        public let description: String
    }

    public static func lines(_ outline: Outline) throws -> [String] {
        func records(_ lines: [OutlineLine], _ name: String) throws -> [JSONValue] {
            try lines.map { line in
                guard let value = line.value, value.isObject else {
                    throw Failure(description: "\(name) line \(line.number) is not a JSON object")
                }
                return value
            }
        }
        let sections = try records(outline.sections, Outline.sectionFile)
        let paragraphs = try records(outline.paragraphs, Outline.paragraphFile)
        let approvals = try records(outline.approvals ?? [], Outline.approvalFile)

        struct Entry { let section: JSONValue; let paragraphs: [JSONValue] }
        var entries: [[Entry]] = []
        for approval in approvals {
            guard let list = approval["sections"]?.array else {
                throw Failure(description: "a record of the approvals file does not hold a list of sections, each with its section and its paragraphs")
            }
            entries.append(try list.map { item in
                guard let section = item["section"], section.isObject, let copies = item["paragraphs"]?.array,
                      copies.allSatisfy(\.isObject) else {
                    throw Failure(description: "a record of the approvals file does not hold a list of sections, each with its section and its paragraphs")
                }
                return Entry(section: section, paragraphs: copies)
            })
        }
        func id(_ record: JSONValue) -> JSONValue { record["id"] ?? .null }
        func shown(_ value: JSONValue) -> String {
            if let text = value.string { return JSONValue.quoted(text) }
            return "null"
        }

        var out: [String] = []
        for section in sections {
            let current = paragraphs.filter { ($0["section"] ?? .null) == id(section) }
            let latest = entries.joined().last { id($0.section) == id(section) }
            if let latest {
                let stands = latest.section == section && latest.paragraphs == current
                out.append("\(shown(id(section)))\t\(stands ? "stands as approved" : "differs from its latest approved copy")")
            } else {
                out.append("\(shown(id(section)))\tnever approved")
            }
        }

        let currentOrder = sections.map(id)
        let whole = approvals.indices.last { approvals[$0]["whole"] == .bool(true) }
        if let whole {
            let same = entries[whole].map { id($0.section) } == currentOrder
            out.append("order of sections\t\(same ? "stands as approved" : "differs from the last approval of the whole outline")")
        } else {
            out.append("order of sections\tno approval of the whole outline is on record")
        }

        // A section removed since its approval: its latest approved copy is in the last approval
        // of the whole outline or in a record after it, and it is no longer in the section file.
        var latestIndex: [(id: JSONValue, index: Int)] = []
        for (index, list) in entries.enumerated() {
            for entry in list {
                if let at = latestIndex.firstIndex(where: { $0.id == id(entry.section) }) {
                    latestIndex[at].index = index
                } else {
                    latestIndex.append((id(entry.section), index))
                }
            }
        }
        var removed = latestIndex.filter { $0.index >= (whole ?? -1) && !currentOrder.contains($0.id) }.map(\.id)
        if let whole, entries[whole].map({ id($0.section) }) == currentOrder { removed = [] }
        removed.sort { ($0.string ?? "").unicodeScalars.lexicographicallyPrecedes(($1.string ?? "").unicodeScalars) }
        out.append("sections removed since their approval\t\(removed.count)" + (removed.isEmpty ? "" : "\t[" + removed.map(shown).joined(separator: ",") + "]"))

        let orphans = paragraphs.filter { record in !sections.contains { id($0) == (record["section"] ?? .null) } }.map(id)
        out.append("paragraph records that name no section\t\(orphans.count)" + (orphans.isEmpty ? "" : "\t[" + orphans.map(shown).joined(separator: ",") + "]"))

        let pending = paragraphs.reduce(0) { count, record in
            count + (record["points"]?.array ?? []).filter { $0.isObject && $0.has("pending") }.count
        }
        out.append("points that carry pending\t\(pending)")
        out.append("records that carry dropped\t\((sections + paragraphs).filter { $0.has("dropped") }.count)")
        let unread = sections.filter { $0.has("unread") && !$0.has("dropped") }.map(id)
        out.append("sections that carry unread\t\(unread.count)" + (unread.isEmpty ? "" : "\t[" + unread.map(shown).joined(separator: ",") + "]"))
        out.append("ok status")
        return out
    }
}
