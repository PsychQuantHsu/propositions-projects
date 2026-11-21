import Foundation
import Testing
@testable import PropositionsKit

/// `write prepare --rewrite`: a whole manuscript rewritten from an outline approved as a whole (issue 115).
struct WriteRewriteTests {
    typealias Box = LedgerOrderTests.Box
    let base = WriteParagraphTests()

    static let section = #"{"id":"s-a","heading":"A","says":"Section A says this."}"#
    static func paragraph(_ id: String) -> String { #"{"id":"\#(id)","section":"s-a","points":[{"id":"\#(id).1","text":"A point."}]}"# }
    static func approval(whole: Bool) -> String {
        #"{"approved_at":"2026-11-21T23:30:00+08:00","statement":"approved",\#(whole ? #""whole":true,"# : "")"sections":[{"section":\#(section),"paragraphs":[\#(paragraph("p-1")),\#(paragraph("p-2"))]}]}"#
    }
    static let old = "019a3c5e-7a00-7000-8000-00000000000c"
    static let new = "019a3c5e-7a00-7000-8000-00000000000d"
    static let prepare = WriteParagraphTests.prepare + ["--outline", "paper/outline", "--rewrite"]

    func setUp(whole: Bool = true) throws -> Box {
        let box = try base.setUp()
        _ = try box.write(Self.section + "\n", to: "paper/outline/outline-sections.jsonl")
        _ = try box.write(Self.paragraph("p-1") + "\n" + Self.paragraph("p-2") + "\n", to: "paper/outline/outline-paragraphs.jsonl")
        _ = try box.write(Self.approval(whole: whole) + "\n", to: "paper/outline/outline-approvals.jsonl")
        return box
    }

    func run(_ arguments: [String], in box: Box) -> CommandResult { PropositionsCLI.run(["write"] + arguments, workingDirectory: box.url) }

    func edit(_ box: Box, _ path: String, _ change: (String) -> String) throws {
        let url = box.url.appendingPathComponent(path)
        try change(try String(contentsOf: url, encoding: .utf8)).write(to: url, atomically: true, encoding: .utf8)
    }

    /// The last paragraph rewritten: its proposition retired, a new one in its place, the ledger
    /// lines in another order, and the map of both outline records.
    func rewrite(_ box: Box, map: [String]? = nil) throws {
        try edit(box, "stage/manuscript/main.tex") {
            $0.replacingOccurrences(of: "In addition, future studies could test whether the advantage lasts beyond one week.",
                                    with: "Future studies could test a longer interval.")
        }
        try edit(box, "stage/ledger/main.jsonl") { text in
            var lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            let i = lines.firstIndex { $0.contains(Self.old) }!
            lines[i] = String(lines[i].dropLast()) + #", "retired": {"since": "2026-11-21", "mechanism": "removed", "match": "exact", "reason": "rewritten", "replaced_by": ["\#(Self.new)"]}}"#
            lines.swapAt(0, 1)
            lines.append(#"{"id": "\#(Self.new)", "text": "Future studies could test a longer interval.", "location": "main.tex:L30", "claim_type": "commentary", "asserts": ["x"], "cites": []}"#)
            return lines.joined(separator: "\n") + "\n"
        }
        let lines = map ?? [#"{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-000000000001"}"#,
                            #"{"outline": "p-2", "first_prop": "\#(Self.new)"}"#]
        _ = try box.write(lines.joined(separator: "\n") + "\n", to: "stage/outline-map.jsonl")
    }

    // spec-example: write / a manuscript is rewritten from an outline approved as a whole
    @Test func `A rewrite keeps every proposition, writes the changed files and traces every record`() throws {
        let box = try setUp()
        #expect(run(Self.prepare, in: box).exitCode == 0)
        try rewrite(box)
        #expect(run(["check", "--stage", "stage"], in: box)
            == CommandResult(stdout: ["rewrite: 1 file(s) changed, 1 new proposition(s), 2 outline record(s) listed"], exitCode: 0))
        let committed = run(["commit", "--stage", "stage"], in: box)
        #expect(committed.exitCode == 0)
        #expect(try String(contentsOf: box.url.appendingPathComponent("paper/main.tex"), encoding: .utf8).contains("Future studies could test a longer interval."))
        let trace = try String(contentsOf: box.url.appendingPathComponent("paper/outline/outline-trace.jsonl"), encoding: .utf8)
        #expect(trace.components(separatedBy: "\n").filter { !$0.isEmpty } == [
            #"{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-000000000001", "section": "s-a", "approval_line": 1}"#,
            #"{"outline": "p-2", "first_prop": "\#(Self.new)", "section": "s-a", "approval_line": 1}"#,
        ])
        #expect(FileManager.default.fileExists(atPath: box.url.appendingPathComponent("stage/backup/ledger").path))
    }

    // spec-example: write / a rewrite that loses or changes a proposition is refused
    @Test func `A rewrite may not change a proposition's text, drop a line, or leave a record unwritten`() throws {
        let box = try setUp()
        #expect(run(Self.prepare, in: box).exitCode == 0)
        try rewrite(box, map: [#"{"outline": "p-2", "first_prop": "\#(Self.new)"}"#])
        try edit(box, "stage/ledger/main.jsonl") { text in
            var lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
            lines.removeAll { $0.contains("019a3c5e-7a00-7000-8000-000000000002") }
            return lines.joined(separator: "\n").replacingOccurrences(of: "Spaced review", with: "Spacing") + "\n"
        }
        let result = run(["check", "--stage", "stage"], in: box)
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains { $0.contains("000000000002 is not one line of the staged ledger") })
        #expect(result.stdout.contains { $0.contains("changed in more than location, cites and retired") })
        #expect(result.stdout.contains { $0.contains("the paragraph record p-1 of the outline was not written") })
        #expect(run(["commit", "--stage", "stage"], in: box).exitCode == 2)
    }

    // spec-example: write / a rewrite needs the outline approved as a whole
    @Test func `A rewrite needs the outline approved as a whole, and takes neither a record nor a heading`() throws {
        let box = try setUp(whole: false)
        let result = run(Self.prepare, in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr.first?.contains("order of sections does not stand as approved") == true)
        let other = try setUp()
        #expect(run(Self.prepare + ["--outline-paragraph", "p-1"], in: other).exitCode == 2)
        #expect(run(Self.prepare + ["--heading"], in: other).exitCode == 2)
    }
}
