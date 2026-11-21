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
    }

    static func fail(_ message: String) -> WriteParagraph.Failure { WriteParagraph.Failure(message: message) }

    static func same(_ a: String?, _ b: String) -> Bool { a.map { $0.unicodeScalars.elementsEqual(b.unicodeScalars) } ?? false }

    /// Refuses unless the outline passes `outline check`, names `paragraph` in exactly one paragraph
    /// record that is not dropped, and that record's section stands as approved.
    static func gate(directory: URL, paragraph: String) throws -> Plan {
        let outline: Outline
        do { outline = try Outline(directory: directory) } catch {
            throw fail("the outline in \(CiteOrder.visible(directory.path)): \(error)")
        }
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
        var hash: String?
        var info = stat()
        if lstat(trace.path, &info) == 0 {
            guard let snapshot = LedgerOrder.read(trace), info.st_mode & S_IFMT == S_IFREG else {
                throw fail("\(CiteOrder.visible(trace.path)) is not a regular file that can be read")
            }
            hash = WriteParagraph.sha256(snapshot.data)
        } else if errno != ENOENT {
            throw fail("\(CiteOrder.visible(trace.path)) cannot be looked at")
        }
        return Plan(directory: directory.path, paragraph: paragraph, section: section, approvalLine: approval.number, traceHash: hash)
    }

    /// The record of one written paragraph, with its line feed.
    static func record(_ plan: Plan, firstProposition: String) -> Data {
        Data(("{\"outline\": \(Revise.quoted(plan.paragraph)), \"first_prop\": \(Revise.quoted(firstProposition)), "
              + "\"section\": \(Revise.quoted(plan.section)), \"approval_line\": \(plan.approvalLine)}\n").utf8)
    }

    static func traceURL(_ plan: Plan) -> URL { URL(fileURLWithPath: plan.directory).appendingPathComponent(traceFile) }

    /// The trace file as `prepare` found it; refuses when it changed.
    static func traceSnapshot(_ plan: Plan) throws -> LedgerOrder.Snapshot? {
        let url = traceURL(plan)
        let current = LedgerOrder.read(url)
        if plan.traceHash == nil {
            guard current == nil, !FileManager.default.fileExists(atPath: url.path) else {
                throw fail("\(CiteOrder.visible(url.path)) appeared after prepare; nothing was written. Prepare again")
            }
            return nil
        }
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

    // MARK: outline trace

    static let keys = ["outline", "first_prop", "section", "approval_line"]

    static func isNumber(_ value: JSONValue?) -> Bool { if case .number = value { return true } else { return false } }

    /// One line per record (`<outline id>\t<first_prop>\t<location>`), then the problems.
    static func trace(directory: URL, ledger: Data) throws -> (rows: [String], problems: [String]) {
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
            guard let value = line.value, case .object(let members) = value,
                  Set(members.map(\.key)) == Set(keys), members.count == keys.count,
                  let outlineID = value["outline"]?.string, let first = value["first_prop"]?.string,
                  value["section"]?.string != nil, isNumber(value["approval_line"])
            else { problems.append("\(at): not a record with exactly the keys \(keys.joined(separator: ", "))"); continue }
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
            let (rows, problems) = try WriteFromOutline.trace(directory: dir, ledger: ledger.data)
            return CommandResult(stdout: rows + problems + ["\(rows.count) record(s), \(problems.count) problem(s)"],
                                 exitCode: problems.isEmpty ? 0 : 1)
        } catch {
            return WriteParagraphRun.refuse(error, "the trace could not be read")
        }
    }
}
