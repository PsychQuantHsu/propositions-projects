import Foundation

/// Commitments planned on the outline (issue 116): the keys `opens` and `discharges` of a
/// paragraph record, and the comparison of a written paragraph with them.
enum OutlineCommitments {
    /// The kinds of the structure sidecars (`docs/STRUCTURE.md`).
    static let kinds: Set<String> = ["question", "aim", "hypothesis", "plan", "announcement", "setup", "future_work"]

    /// A commitment id as the structure sidecars write it: `[a-z0-9][a-z0-9-]{0,63}`.
    static func isID(_ text: String) -> Bool {
        let scalars = Array(text.unicodeScalars)
        func plain(_ s: Unicode.Scalar) -> Bool { ("a"..."z").contains(s) || ("0"..."9").contains(s) }
        guard let first = scalars.first, plain(first), scalars.count <= 64 else { return false }
        return scalars.allSatisfy { plain($0) || $0 == "-" }
    }

    struct Opened: Equatable {
        let id: String
        let kind: String?
    }

    /// What a record plans, or what a set of discourse records does: the commitments opened,
    /// with their kinds, and the ids discharged, each in the order written and once.
    struct Commitments: Equatable {
        var opens: [Opened] = []
        var discharges: [String] = []

        mutating func add(_ record: JSONValue) {
            for item in record["opens"]?.array ?? [] {
                guard let id = item["id"]?.string, !opens.contains(where: { $0.id == id }) else { continue }
                opens.append(Opened(id: id, kind: item["kind"]?.string))
            }
            for item in record["discharges"]?.array ?? [] {
                guard let id = item.string, !discharges.contains(id) else { continue }
                discharges.append(id)
            }
        }
    }

    /// What the discourse records of the propositions `ids` open and discharge.
    static func written(discourse: [JSONValue], propositions ids: [String]) -> Commitments {
        var out = Commitments()
        for record in discourse {
            guard let prop = record["prop_id"]?.string, ids.contains(where: { WriteFromOutline.same($0, prop) }) else { continue }
            out.add(record)
        }
        return out
    }

    /// The differences between what the paragraph record `record` plans and what its paragraph
    /// does, one line each; empty when they agree.
    static func differences(record: JSONValue, written: Commitments) -> [String] {
        var planned = Commitments()
        planned.add(record)
        let name = "the outline record \(CiteOrder.visible(record["id"]?.string ?? ""))"
        var out: [String] = []
        for open in planned.opens {
            guard let done = written.opens.first(where: { $0.id == open.id }) else {
                out.append("\(name) plans to open \(CiteOrder.visible(open.id)), and its paragraph does not open it")
                continue
            }
            if done.kind != open.kind {
                out.append("\(name) plans \(CiteOrder.visible(open.id)) as \(CiteOrder.visible(open.kind ?? "no kind")), and its paragraph opens it as \(CiteOrder.visible(done.kind ?? "no kind"))")
            }
        }
        for open in written.opens where !planned.opens.contains(where: { $0.id == open.id }) {
            out.append("the paragraph opens \(CiteOrder.visible(open.id)), which \(name) does not plan")
        }
        for id in planned.discharges where !written.discharges.contains(id) {
            out.append("\(name) plans to discharge \(CiteOrder.visible(id)), and its paragraph does not discharge it")
        }
        for id in written.discharges where !planned.discharges.contains(id) {
            out.append("the paragraph discharges \(CiteOrder.visible(id)), which \(name) does not plan")
        }
        return out
    }

    /// Whether the outline plans commitments at all: a record that is not dropped carries `opens`
    /// or `discharges`. An outline that plans none (one derived from a finished manuscript) is not
    /// compared: its records say nothing about commitments, which is not a plan of none.
    static func plansAny(_ records: [JSONValue]) -> Bool {
        records.contains { !$0.has("dropped") && ($0.has("opens") || $0.has("discharges")) }
    }

    /// The JSON objects of a file of one object per line; lines that are not objects are passed over.
    static func objects(_ data: Data) -> [JSONValue] {
        Outline.lines(of: data).compactMap { $0.value.flatMap { $0.isObject ? $0 : nil } }
    }
}
