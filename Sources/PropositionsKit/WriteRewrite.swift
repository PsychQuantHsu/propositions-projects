import Foundation

/// Rewriting a finished manuscript from a revised outline (issue 115): `write prepare --rewrite`.
///
/// Unlike a new paragraph, a rewrite may change every file of the input tree. What it may not do
/// is lose a proposition: every line of the ledger keeps its id and everything but `location` and
/// `cites`, and may gain `retired`; new propositions are added. The structure sidecars are rebuilt
/// and left to the structure validator. The paragraphs written from the outline are listed, one
/// per line, in `outline-map.jsonl` of the staging directory, and `commit` copies them into
/// `outline-trace.jsonl`.
public enum WriteRewrite {
    public static let mapFile = "outline-map.jsonl"

    static func fail(_ message: String) -> WriteParagraph.Failure { WriteParagraph.Failure(message: message) }

    /// What `prepare --rewrite` records about the outline.
    struct Plan: Codable, Equatable {
        var directory: String
        /// The SHA-256 of `outline-trace.jsonl` at prepare; nil when there was no such file.
        var traceHash: String?
    }

    /// Refuses unless the outline passes `outline check` and stands as approved as a whole: every
    /// section, the order of sections, no section removed since its approval waiting, no paragraph
    /// record outside a section. Judged from `bytes`, the three files read once.
    static func gate(directory: URL, bytes: [Data]) throws -> Plan {
        let text = bytes.map { String(decoding: $0, as: UTF8.self) }
        let outline = Outline(sections: text[0], paragraphs: text[1], approvals: text[2])
        if let first = OutlineCheck.findings(outline).first {
            throw fail("the outline does not pass outline check: \(first)")
        }
        let status: [String]
        do { status = try OutlineStatus.lines(outline) } catch { throw fail("\(error)") }
        let summary = ["order of sections", "sections removed since their approval", "paragraph records that name no section",
                       "points that carry pending", "records that carry dropped", "ok status"]
        let names = status.map { $0.components(separatedBy: "\t").first ?? "" }
        guard names.last == "ok status", ["order of sections", "sections removed since their approval",
                                          "paragraph records that name no section"].allSatisfy(names.contains),
              names.contains(where: { !summary.contains($0) })
        else { throw fail("outline status did not report every section and the order of sections") }
        for line in status {
            let name = line.components(separatedBy: "\t").first ?? ""
            if name == "order of sections" {
                guard line.hasSuffix("\tstands as approved") else { throw fail("the order of sections does not stand as approved; a rewrite follows an outline approved as a whole") }
            } else if name == "sections removed since their approval" || name == "paragraph records that name no section" {
                guard line.hasSuffix("\t0") else { throw fail("\(name): not 0; a rewrite follows an outline approved as a whole") }
            } else if !summary.contains(name) {
                guard line.hasSuffix("\tstands as approved") else {
                    throw fail("the section \(CiteOrder.visible(name)) does not stand as approved; a rewrite follows an outline approved as a whole")
                }
            }
        }
        let trace = directory.appendingPathComponent(WriteFromOutline.traceFile)
        let hash = try WriteFromOutline.absent(trace) ? nil : WriteParagraph.sha256(try WriteFromOutline.regular(trace).data)
        return Plan(directory: directory.path, traceHash: hash)
    }

    // MARK: check

    static let changeable: Set<String> = ["location", "cites", "retired"]

    /// The members of a ledger line other than the ones a rewrite may change, by key.
    static func fixed(_ members: [JSONMember]) -> JSONValue {
        .object(Revise.deduplicated(members).filter { !changeable.contains($0.key) })
    }

    /// The problems of the ledger, and the ids of the live propositions it adds.
    static func ledger(old: Data, new: Data) -> (problems: [String], added: [String]) {
        guard let before = try? ReviseLedger.lines(old), let after = try? ReviseLedger.lines(new) else {
            return (["the ledger or its copy is not one JSON object per line"], [])
        }
        var problems: [String] = []
        var byID: [[UInt32]: [ReviseLedger.Line]] = [:]
        for line in after { if let id = line.id { byID[ReviseLedger.key(id), default: []].append(line) } }
        if after.contains(where: { $0.id == nil }) { problems.append("a line of the staged ledger has no id") }
        for (name, lines) in [("ledger", before), ("staged ledger", after)] {
            if lines.contains(where: { ($0.members.map { Revise.deduplicated($0).count != $0.count }) ?? false }) {
                problems.append("a line of the \(name) writes a key twice")
            }
        }
        if before.contains(where: { $0.id == nil }) { problems.append("a line of the ledger has no id: a rewrite needs every proposition named") }
        var oldIDs = Set<[UInt32]>()
        for line in before {
            guard let id = line.id, let members = line.members else { continue }
            let key = ReviseLedger.key(id)
            guard oldIDs.insert(key).inserted else {
                problems.append("\(CiteOrder.visible(id)) is the id of several lines of the ledger")
                continue
            }
            guard let matches = byID[key], matches.count == 1, let now = matches.first, let nowMembers = now.members else {
                problems.append("\(CiteOrder.visible(id)) is not one line of the staged ledger: a rewrite retires a proposition, it does not remove it")
                continue
            }
            if fixed(members) != fixed(nowMembers) {
                problems.append("\(CiteOrder.visible(id)) changed in more than location, cites and retired: a changed proposition is retired, and its new text is a new proposition")
            }
            if line.isRetired, let was = members.last(where: { $0.key == "retired" })?.value,
               nowMembers.last(where: { $0.key == "retired" })?.value != was {
                problems.append("\(CiteOrder.visible(id)) was retired, and its retirement changed")
            }
        }
        var added: [String] = []
        for line in after {
            guard let id = line.id, !oldIDs.contains(ReviseLedger.key(id)) else { continue }
            if (byID[ReviseLedger.key(id)]?.count ?? 0) > 1 { problems.append("\(CiteOrder.visible(id)) is the id of several lines of the staged ledger") }
            if line.isRetired { problems.append("the new proposition \(CiteOrder.visible(id)) is retired") } else { added.append(id) }
        }
        return (problems, added)
    }

    /// The problems of `outline-map.jsonl`, and its records as (outline id, first proposition).
    static func map(_ data: Data?, outline: Outline, ledger: Data) -> (problems: [String], records: [(String, String)]) {
        guard let data else { return (["the staging directory holds no \(mapFile): list each paragraph written from the outline"], []) }
        let records = outline.paragraphs.compactMap(\.value).filter { !$0.has("dropped") }
        let ids = records.compactMap { $0["id"]?.string }
        let rows = (try? ReviseLedger.lines(ledger)) ?? []
        var problems: [String] = [], out: [(String, String)] = []
        var seenOutline = Set<[UInt32]>(), seenProp = Set<[UInt32]>()
        for line in Outline.lines(of: data) {
            let at = "\(mapFile) line \(line.number)"
            guard let value = line.value, case .object(let members) = value, Set(members.map(\.key)) == ["outline", "first_prop"],
                  members.count == 2, let outlineID = value["outline"]?.string, let first = value["first_prop"]?.string
            else { problems.append("\(at): not a record with exactly the keys outline, first_prop"); continue }
            if !ids.contains(where: { WriteFromOutline.same($0, outlineID) }) {
                problems.append("\(at): \(CiteOrder.visible(outlineID)) is no paragraph record of the outline that is not dropped")
            }
            let live = rows.filter { WriteFromOutline.same($0.id, first) }
            if live.count != 1 || live[0].isRetired {
                problems.append("\(at): \(CiteOrder.visible(first)) is not exactly one live proposition of the staged ledger")
            }
            if !seenOutline.insert(ReviseLedger.key(outlineID)).inserted { problems.append("\(at): \(CiteOrder.visible(outlineID)) is listed twice") }
            if !seenProp.insert(ReviseLedger.key(first)).inserted { problems.append("\(at): \(CiteOrder.visible(first)) is listed twice") }
            out.append((outlineID, first))
        }
        for id in ids where !seenOutline.contains(ReviseLedger.key(id)) {
            problems.append("\(mapFile): the paragraph record \(CiteOrder.visible(id)) of the outline was not written")
        }
        return (problems, out)
    }

    /// The section of each paragraph record, and the line of the last approval that holds it.
    static func approvals(_ outline: Outline) -> [String: (section: String, line: Int)] {
        var out: [String: (String, Int)] = [:]
        for record in outline.paragraphs.compactMap(\.value) {
            guard let id = record["id"]?.string, let section = record["section"]?.string else { continue }
            let line = (outline.approvals ?? []).last { line in
                (line.value?["sections"]?.array ?? []).contains { WriteFromOutline.same($0["section"]?["id"]?.string, section) }
            }?.number ?? 0
            out[id] = (section, line)
        }
        return out
    }

    /// The trace `commit` writes for the map: a rewrite writes it anew, since the old records name
    /// paragraphs of the text it replaces (the old trace is kept in `backup/`).
    static func traceLines(_ records: [(String, String)], outline: Outline) -> Data {
        let where_ = approvals(outline)
        var data = Data()
        for (outlineID, first) in records {
            let (section, line) = where_[outlineID] ?? ("", 0)
            let plan = WriteFromOutline.Plan(directory: "", paragraph: outlineID, section: section, approvalLine: line, traceHash: nil)
            data += WriteFromOutline.record(plan, firstProposition: first)
        }
        return data
    }

    /// Every live proposition of the staged ledger has to be located in the staged tree, and each
    /// mapped proposition has to start a paragraph: its line follows a blank line or a sectioning line.
    static func locations(stagedMain: URL, ledger: Data, mapped: [String]) -> [String] {
        guard let order = try? ReadingOrder(mainFile: stagedMain), let rows = try? ReviseLedger.lines(ledger) else {
            return ["the staged manuscript or ledger cannot be read to check locations"]
        }
        let directory = stagedMain.deletingLastPathComponent()
        var problems: [String] = []
        for row in rows where !row.isRetired {
            guard let id = row.id, let location = row.location else { continue }
            guard order.position(file: location.file, line: location.start) != nil else {
                problems.append("\(CiteOrder.visible(id)) is located outside the staged manuscript"); continue
            }
            guard mapped.contains(where: { WriteFromOutline.same($0, id) }) else { continue }
            let name = location.file.flatMap { $0 == "main.tex" ? nil : ReadingOrder.normalise($0) }
            let url = name.map { directory.appendingPathComponent($0) } ?? stagedMain
            let lines = LatexLine.splitLines(String(decoding: (LedgerOrder.read(url)?.data ?? Data()), as: UTF8.self))
            // A paragraph starts after a blank line, or right after a sectioning line.
            let i = location.start - 1
            let starts = i < lines.count && !LedgerOrder.stripped(lines[i]).isEmpty
                && (i == 0 || LedgerOrder.stripped(lines[i - 1]).isEmpty || WriteParagraph.beginsHeading(lines[i - 1]))
            if !starts {
                problems.append("\(CiteOrder.visible(id)), listed in \(mapFile), does not start a paragraph")
            }
        }
        return problems
    }

    /// What each written paragraph opens and discharges, against what its outline record plans
    /// (issue 116). The propositions of a paragraph are the live ones from the proposition the
    /// map names up to the one the map names next, in reading order.
    static func commitments(records: [(String, String)], outline: Outline, stagedMain: URL, ledger: Data, discourse: Data) -> [String] {
        guard OutlineCommitments.plansAny(outline.paragraphs.compactMap(\.value)),
              let order = try? ReadingOrder(mainFile: stagedMain), let rows = try? ReviseLedger.lines(ledger) else { return [] }
        var placed: [(position: [Int], id: String)] = []
        for row in rows where !row.isRetired {
            guard let id = row.id, let location = row.location, let position = order.position(file: location.file, line: location.start) else { continue }
            placed.append((position, id))
        }
        // A stable order: reading order, and the ledger's order among propositions of one line.
        let sorted = placed.enumerated().sorted { a, b in
            if ReadingOrder.precedes(a.element.position, b.element.position) { return true }
            if ReadingOrder.precedes(b.element.position, a.element.position) { return false }
            return a.offset < b.offset
        }.map(\.element.id)
        let starts = records.compactMap { record in sorted.firstIndex { WriteFromOutline.same($0, record.1) } }
        let rowsOfDiscourse = OutlineCommitments.objects(discourse)
        let planned = outline.paragraphs.compactMap(\.value)
        var problems: [String] = []
        for (outlineID, first) in records {
            guard let start = sorted.firstIndex(where: { WriteFromOutline.same($0, first) }),
                  let record = planned.first(where: { WriteFromOutline.same($0["id"]?.string, outlineID) }) else { continue }
            let end = starts.filter { $0 > start }.min() ?? sorted.count
            let written = OutlineCommitments.written(discourse: rowsOfDiscourse, propositions: Array(sorted[start..<end]))
            problems += OutlineCommitments.differences(record: record, written: written)
        }
        return problems
    }

    static func outline(_ directory: URL) throws -> Outline {
        let text = try WriteFromOutline.read(directory).map { String(decoding: $0, as: UTF8.self) }
        return Outline(sections: text[0], paragraphs: text[1], approvals: text[2])
    }
}
