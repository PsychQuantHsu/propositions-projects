import Foundation
import CryptoKit

/// Writing a paragraph from an approved outline (issue 51): the gate `write prepare` passes before
/// it stages anything, the record `write commit` appends to `outline-trace.jsonl`, and the check
/// of that file (`propositions outline trace`).
public enum WriteFromOutline {
    public static let traceFile = "outline-trace.jsonl"

    /// What `prepare` records when the paragraph is written from an outline record.
    struct Plan: Codable, Equatable {
        /// The outline directory, the paragraph record's id and the id of its section.
        var directory: String
        var paragraph: String
        var section: String
        /// The line of `outline-approvals.jsonl` that holds the approval the section stands on.
        var approvalLine: Int
        /// The SHA-256 of `outline-trace.jsonl` at prepare; nil when there was no such file.
        var traceHash: String?
        /// The part the section goes to, when `article.json` names destinations (issue 120).
        var part: String? = nil
    }

    static func fail(_ message: String) -> WriteParagraph.Failure { WriteParagraph.Failure(message: message) }

    static func same(_ a: String?, _ b: String) -> Bool { a.map { $0.unicodeScalars.elementsEqual(b.unicodeScalars) } ?? false }

    static let files = [Outline.sectionFile, Outline.paragraphFile, Outline.approvalFile]

    /// Whether nothing is at `url` (not even a dangling link); throws when it cannot be looked at.
    static func absent(_ url: URL) throws -> Bool {
        var info = stat()
        if lstat(url.path, &info) == 0 { return false }
        guard errno == ENOENT else { throw fail("\(CiteOrder.visible(url.path)) cannot be looked at") }
        return true
    }

    /// A regular file at `url`, read once; a link or anything else is refused.
    static func regular(_ url: URL) throws -> LedgerOrder.Snapshot {
        var info = stat()
        guard lstat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG, let snapshot = LedgerOrder.read(url) else {
            throw fail("\(CiteOrder.visible(url.path)) is not a regular file that can be read")
        }
        return snapshot
    }

    /// The three outline files, each read once, in the order of `files`.
    static func read(_ directory: URL) throws -> [Data] {
        try files.map { try regular(directory.appendingPathComponent($0)).data }
    }

    /// Refuses unless the outline passes `outline check`, names `paragraph` in exactly one paragraph
    /// record that is not dropped, and that record's section stands as approved. The outline is
    /// judged from `bytes`, the three files as they were read once, so that what is judged is what
    /// is copied and hashed.
    static func gate(directory: URL, paragraph: String, bytes: [Data]) throws -> Plan {
        let text = bytes.map { String(decoding: $0, as: UTF8.self) }
        let outline = Outline(sections: text[0], paragraphs: text[1], approvals: text[2])
        if let first = OutlineCheck.findings(outline).first {
            throw fail("the outline does not pass outline check: \(first)")
        }
        let records = outline.paragraphs.compactMap(\.value).filter { same($0["id"]?.string, paragraph) }
        guard records.count == 1, let record = records.first else {
            throw fail("\(records.isEmpty ? "no" : "more than one") paragraph record of the outline has the id \(CiteOrder.visible(paragraph))")
        }
        guard !record.has("dropped") else { throw fail("the paragraph record \(CiteOrder.visible(paragraph)) is dropped") }
        guard let section = record["section"]?.string else {
            throw fail("the paragraph record \(CiteOrder.visible(paragraph)) names no section")
        }
        let status: [String]
        do { status = try OutlineStatus.lines(outline) } catch { throw fail("\(error)") }
        guard status.contains(JSONValue.quoted(section) + "\tstands as approved") else {
            throw fail("the section \(CiteOrder.visible(section)) does not stand as approved; text is written from an outline only after the author approves it")
        }
        let approval = (outline.approvals ?? []).last { line in
            (line.value?["sections"]?.array ?? []).contains { same($0["section"]?["id"]?.string, section) }
        }
        guard let approval else { throw fail("no approval record holds the section \(CiteOrder.visible(section))") }
        let trace = directory.appendingPathComponent(traceFile)
        let hash = try absent(trace) ? nil : WriteParagraph.sha256(try regular(trace).data)
        return Plan(directory: directory.path, paragraph: paragraph, section: section, approvalLine: approval.number, traceHash: hash)
    }

    /// One note for each included file that was not read when the outline was derived (issue 117),
    /// for the section `only` and the sections above it, or for every section that is not dropped.
    static func unreadNotes(_ outline: Outline, only section: String? = nil) -> [String] {
        let records = outline.sections.compactMap(\.value)
        var wanted: [String]? = nil
        if var at = section {
            var chain = [at]
            while let parent = records.first(where: { same($0["id"]?.string, at) })?["parent"]?.string, !chain.contains(parent) {
                chain.append(parent); at = parent
            }
            wanted = chain
        }
        var out: [String] = []
        for record in records where !record.has("dropped") {
            guard let id = record["id"]?.string, wanted?.contains(where: { same($0, id) }) ?? true else { continue }
            for item in record["unread"]?.array ?? [] {
                guard let file = item["file"]?.string, let why = item["why"]?.string else { continue }
                out.append("[unread] section \(CiteOrder.visible(id)): the included file \(CiteOrder.visible(file)) was not read when the outline was derived (\(CiteOrder.visible(why))); the outline does not say what it holds")
            }
        }
        return out
    }

    /// The record of one written paragraph, with its line feed.
    static func record(_ plan: Plan, firstProposition: String) -> Data {
        Data(("{\"outline\": \(Revise.quoted(plan.paragraph)), \"first_prop\": \(Revise.quoted(firstProposition)), "
              + "\"section\": \(Revise.quoted(plan.section)), \"approval_line\": \(plan.approvalLine)"
              + (plan.part.map { ", \"part\": \(Revise.quoted($0))" } ?? "") + "}\n").utf8)
    }

    static func traceURL(_ plan: Plan) -> URL { URL(fileURLWithPath: plan.directory).appendingPathComponent(traceFile) }

    /// The trace file as `prepare` found it; refuses when it changed.
    static func traceSnapshot(_ plan: Plan) throws -> LedgerOrder.Snapshot? {
        let url = traceURL(plan)
        if plan.traceHash == nil {
            guard try absent(url) else {
                throw fail("\(CiteOrder.visible(url.path)) appeared after prepare; nothing was written. Prepare again")
            }
            return nil
        }
        let current = try? regular(url)
        guard let current, WriteParagraph.sha256(current.data) == plan.traceHash else {
            throw fail("\(CiteOrder.visible(url.path)) changed after prepare; nothing was written. Prepare again")
        }
        return current
    }

    /// Appends the record: a new file when there was none, else the file with one line more.
    static func append(_ plan: Plan, firstProposition: String, to snapshot: LedgerOrder.Snapshot?) throws {
        let line = record(plan, firstProposition: firstProposition)
        guard let snapshot else { try WriteParagraph.create(line, at: traceURL(plan)); return }
        var data = snapshot.data
        if !data.isEmpty, !WriteParagraph.endsWithLineBreak(data) { data.append(0x0A) }
        _ = try LedgerOrder.write(data + line, to: traceURL(plan), replacing: snapshot)
    }

    /// The plan of a manifest, judged again at commit from the outline files: they have to be the
    /// inputs `prepare` recorded, and the gate has to give the same section and approval line.
    static func confirm(_ plan: Plan, inputs: [WriteParagraph.Input]) throws {
        let directory = URL(fileURLWithPath: plan.directory)
        let recorded = files.map { name in inputs.first { $0.original == directory.appendingPathComponent(name).path } }
        guard recorded.allSatisfy({ $0 != nil }) else {
            throw fail("write.json names an outline whose files prepare did not record; nothing was written")
        }
        let again = try gate(directory: directory, paragraph: plan.paragraph, bytes: try read(directory))
        guard again.section == plan.section, again.approvalLine == plan.approvalLine else {
            throw fail("the outline record no longer stands as prepare found it; nothing was written. Prepare again")
        }
    }

    /// Whether the trace already names a proposition.
    static func names(_ snapshot: LedgerOrder.Snapshot?, _ id: String) -> Bool {
        guard let snapshot else { return false }
        return Outline.lines(of: snapshot.data).contains { same($0.value?["first_prop"]?.string, id) }
    }

    // MARK: outline trace

    static let keys = ["outline", "first_prop", "section", "approval_line"]

    static func isNumber(_ value: JSONValue?) -> Bool { if case .number = value { return true } else { return false } }

    /// One line per record (`<outline id>\t<first_prop>\t<location>`), then the problems.
    /// The part a trace record belongs to: its `part`, or `main` when it has none.
    static func part(of record: JSONValue?) -> String { record?["part"]?.string ?? "main" }

    /// Whether a trace record has exactly the keys of the format: the four, and optionally `part`.
    static func hasTraceKeys(_ members: [JSONMember]) -> Bool {
        let names = members.map(\.key)
        return Set(names).count == names.count && Set(names).subtracting(["part"]) == Set(keys)
            && (members.first { $0.key == "part" }.map { $0.value.string.map(OutlineCheck.parts.contains) ?? false } ?? true)
    }

    /// `parts`: when `article.json` names destinations, the parts whose document the ledger is;
    /// the records of other parts are listed and not checked against this ledger.
    static func trace(directory: URL, ledger: Data, parts: [String]? = nil) throws -> (rows: [String], problems: [String]) {
        guard let snapshot = LedgerOrder.read(directory.appendingPathComponent(traceFile)) else {
            throw fail("cannot read \(CiteOrder.visible(directory.appendingPathComponent(traceFile).path))")
        }
        let outline: Outline
        do { outline = try Outline(directory: directory) } catch { throw fail("\(error)") }
        let outlineIDs = outline.paragraphs.compactMap { $0.value?["id"]?.string }
        let lines = try ReviseLedger.lines(ledger)
        var rows: [String] = [], problems: [String] = []
        var seen: [[UInt32]: Int] = [:]
        for line in Outline.lines(of: snapshot.data) {
            let at = "\(traceFile) line \(line.number)"
            guard let value = line.value, case .object(let members) = value, hasTraceKeys(members),
                  let outlineID = value["outline"]?.string, let first = value["first_prop"]?.string,
                  value["section"]?.string != nil, isNumber(value["approval_line"])
            else { problems.append("\(at): not a record with exactly the keys \(keys.joined(separator: ", ")), and optionally part"); continue }
            if let parts, !parts.contains(part(of: value)) {
                rows.append("\(CiteOrder.visible(outlineID))\t\(CiteOrder.visible(first))\tin the document of the part \(part(of: value))")
                continue
            }
            if !outlineIDs.contains(where: { same($0, outlineID) }) {
                problems.append("\(at): \(CiteOrder.visible(outlineID)) is no paragraph record of the outline")
            }
            let matches = lines.filter { same($0.id, first) }
            let live = matches.filter { !$0.isRetired }
            if live.count != 1 {
                problems.append("\(at): \(CiteOrder.visible(first)) is \(matches.isEmpty ? "no proposition of the ledger" : live.isEmpty ? "retired" : "the id of several lines")")
            }
            let key = ReviseLedger.key(first)
            if let earlier = seen[key] { problems.append("\(at): \(CiteOrder.visible(first)) is recorded already on line \(earlier)") }
            seen[key] = line.number
            let location = live.first?.location.map { "\($0.file ?? "main.tex"):L\($0.start)" } ?? "-"
            rows.append("\(CiteOrder.visible(outlineID))\t\(CiteOrder.visible(first))\t\(location)")
        }
        return (rows, problems)
    }
}

/// `propositions outline trace`. Exit codes: 0 every record holds; 1 a record does not; 2 a file
/// cannot be read.
public enum OutlineTraceRun {
    public static func run(directory: String, jsonl: String, workingDirectory: URL) -> CommandResult {
        let dir = WriteParagraphRun.resolve(directory, workingDirectory)
        guard let ledger = LedgerOrder.read(WriteParagraphRun.resolve(jsonl, workingDirectory)) else {
            return CommandResult(stderr: ["error: cannot read the ledger \(CiteOrder.visible(jsonl))"], exitCode: 2)
        }
        do {
            var parts: [String]?
            if let article = try Article.read(in: dir)?.article, article.destinations != nil {
                // Which document the ledger is: the parts whose destination names it.
                let url = WriteParagraphRun.resolve(jsonl, workingDirectory)
                parts = ["main", "appendix", "supplement"].filter { part in
                    article.destinations?[part].map { WriteParagraph.canonical(Article.resolve($0.jsonl, dir)) == WriteParagraph.canonical(url) } ?? false
                }
                if parts!.isEmpty {
                    return CommandResult(stderr: ["error: \(Article.fileName) names destinations, and \(CiteOrder.visible(jsonl)) is the ledger of none of them"], exitCode: 2)
                }
            }
            let (rows, problems) = try WriteFromOutline.trace(directory: dir, ledger: ledger.data, parts: parts)
            return CommandResult(stdout: rows + problems + ["\(rows.count) record(s), \(problems.count) problem(s)"],
                                 exitCode: problems.isEmpty ? 0 : 1)
        } catch {
            return WriteParagraphRun.refuse(error, "the trace could not be read")
        }
    }
}
