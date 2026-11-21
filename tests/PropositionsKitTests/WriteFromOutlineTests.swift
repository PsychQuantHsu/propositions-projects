import Foundation
import Testing
@testable import PropositionsKit

/// Writing from an empty draft, with a heading, and from an approved outline (issue 51).
struct WriteFromOutlineTests {
    typealias Box = LedgerOrderTests.Box
    let base = WriteParagraphTests()

    static let sectionA = #"{"id":"s-a","heading":"A","says":"Section A says this."}"#
    static let sectionB = #"{"id":"s-b","heading":"B","says":"Section B says that."}"#
    static func paragraph(_ id: String, _ section: String) -> String {
        #"{"id":"\#(id)","section":"\#(section)","points":[{"id":"\#(id).1","text":"A point."}]}"#
    }
    /// s-a is approved; s-b never was.
    static let approval = #"{"approved_at":"2026-11-21T22:00:00+08:00","statement":"approved","sections":[{"section":\#(sectionA),"paragraphs":[\#(paragraph("p-1", "s-a"))]}]}"#

    func outline(in box: Box) throws {
        _ = try box.write(Self.sectionA + "\n" + Self.sectionB + "\n", to: "paper/outline/outline-sections.jsonl")
        _ = try box.write(Self.paragraph("p-1", "s-a") + "\n" + Self.paragraph("p-3", "s-b") + "\n", to: "paper/outline/outline-paragraphs.jsonl")
        _ = try box.write(Self.approval + "\n", to: "paper/outline/outline-approvals.jsonl")
    }

    func run(_ arguments: [String], in box: Box) -> CommandResult {
        PropositionsCLI.run(["write"] + arguments, workingDirectory: box.url)
    }

    // spec-example: write / an empty draft gets its first paragraph before \end{document}
    @Test func `An empty ledger puts the paragraph after the last text before end document`() throws {
        let box = try Box()
        _ = try box.write("\\documentclass{article}\n\\begin{document}\n\\section{Intro}\n\n\\end{document}\n", to: "paper/main.tex")
        _ = try box.write(#"{"schema_version": "1.8", "profile": "default"}"# + "\n", to: "paper/propositions/_meta.json")
        _ = try box.write("", to: "paper/propositions/main.jsonl")
        _ = try box.write(#"{"structure_version": "2.0", "thesis": [], "sections": [], "paragraphs": []}"# + "\n", to: "paper/propositions/structure.json")
        _ = try box.write("", to: "paper/propositions/discourse.jsonl")
        let result = run(WriteParagraphTests.prepare, in: box)
        #expect(result.exitCode == 0)
        #expect(result.stdout.first == "the new paragraph goes after line 3 of main.tex")
        let none = try Box()
        _ = try none.write("\\begin{document}\nText.\n", to: "paper/main.tex")
        for name in ["main.jsonl", "discourse.jsonl"] { _ = try none.write("", to: "paper/propositions/\(name)") }
        _ = try none.write("{}", to: "paper/propositions/structure.json")
        #expect(run(WriteParagraphTests.prepare, in: none).stderr.first?.contains("no line \\end{document}") == true)
    }

    // spec-example: write / a heading line is allowed only when prepare was asked for one
    @Test func `A heading line before the paragraph needs --heading`() throws {
        for heading in [false, true] {
            let box = try base.setUp()
            #expect(run(WriteParagraphTests.prepare + (heading ? ["--heading"] : []), in: box).exitCode == 0)
            try base.draft(box, text: "\\section{Outlook}\n\nThe effect was large.")
            let result = run(["check", "--stage", "stage"], in: box)
            if heading {
                #expect(result.exitCode == 0)
                #expect(result.stdout.first == "heading: \\section{Outlook}")
            } else {
                #expect(result.exitCode == 1)
                #expect(result.stdout.contains { $0.contains("hold 2 paragraphs, not one") })
            }
        }
    }

    // spec-example: write / a paragraph is written from an approved outline record and traced
    @Test func `Writing from an outline record needs its section approved, and commit records the trace`() throws {
        let box = try base.setUp()
        try outline(in: box)
        let refused = run(WriteParagraphTests.prepare + ["--outline", "paper/outline", "--outline-paragraph", "p-3"], in: box)
        #expect(refused.exitCode == 2)
        #expect(refused.stderr.first?.contains("does not stand as approved") == true)
        #expect(run(WriteParagraphTests.prepare + ["--outline", "paper/outline"], in: box).exitCode == 2)
        #expect(run(WriteParagraphTests.prepare + ["--outline", "paper/outline", "--outline-paragraph", "p-1"], in: box).exitCode == 0)
        try base.draft(box)
        let committed = run(["commit", "--stage", "stage"], in: box)
        #expect(committed.exitCode == 0)
        #expect(committed.stdout.contains { $0.hasSuffix("outline-trace.jsonl") })
        let trace = try String(contentsOf: box.url.appendingPathComponent("paper/outline/outline-trace.jsonl"), encoding: .utf8)
        #expect(trace == #"{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-00000000000d", "section": "s-a", "approval_line": 1}"# + "\n")
        let listed = PropositionsCLI.run(["outline", "trace", "paper/outline", "--jsonl", "paper/propositions/main.jsonl"], workingDirectory: box.url)
        #expect(listed == CommandResult(stdout: ["p-1\t019a3c5e-7a00-7000-8000-00000000000d\tmain.tex:L32", "1 record(s), 0 problem(s)"], exitCode: 0))
    }

    @Test func `A change to the outline after prepare is refused`() throws {
        let box = try base.setUp()
        try outline(in: box)
        #expect(run(WriteParagraphTests.prepare + ["--outline", "paper/outline", "--outline-paragraph", "p-1"], in: box).exitCode == 0)
        try base.draft(box)
        let url = box.url.appendingPathComponent("paper/outline/outline-paragraphs.jsonl")
        try (try String(contentsOf: url, encoding: .utf8) + Self.paragraph("p-4", "s-a") + "\n").write(to: url, atomically: true, encoding: .utf8)
        let result = run(["commit", "--stage", "stage"], in: box)
        #expect(result.exitCode == 2)
        #expect(!FileManager.default.fileExists(atPath: box.url.appendingPathComponent("paper/outline/outline-trace.jsonl").path))
    }

    @Test func `The trace check reports a record it cannot follow`() throws {
        let box = try base.setUp()
        try outline(in: box)
        let good = #"{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-00000000000c", "section": "s-a", "approval_line": 1}"#
        _ = try box.write([good, good, #"{"outline": "p-9", "first_prop": "nobody", "section": "s-a", "approval_line": 1}"#, #"{"outline": "p-1"}"#]
            .joined(separator: "\n") + "\n", to: "paper/outline/outline-trace.jsonl")
        let result = PropositionsCLI.run(["outline", "trace", "paper/outline", "--jsonl", "paper/propositions/main.jsonl"], workingDirectory: box.url)
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains { $0.contains("line 2:") && $0.contains("recorded already on line 1") })
        #expect(result.stdout.contains { $0.contains("p-9 is no paragraph record") })
        #expect(result.stdout.contains { $0.contains("nobody is no proposition of the ledger") })
        #expect(result.stdout.contains { $0.contains("line 4: not a record") })
    }
}
