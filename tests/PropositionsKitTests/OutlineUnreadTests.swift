import Foundation
import Testing
@testable import PropositionsKit

/// Included files that derive did not read (issue 117): the key `unread` of a section record.
struct OutlineUnreadTests {
    typealias Box = LedgerOrderTests.Box
    let base = WriteParagraphTests()

    static func section(_ id: String, _ extra: String = "") -> String { #"{"id":"\#(id)","heading":"H","says":"It says this."\#(extra)}"# }
    static func paragraph(_ id: String, _ section: String) -> String {
        #"{"id":"\#(id)","section":"\#(section)","points":[{"id":"\#(id).1","text":"A point."}]}"#
    }
    static let numbers = #"{"file": "generated/numbers", "why": "ignored by git"}"#

    // spec-example: article-outline / a file included twice, and sections with nothing else
    @Test func `A file included twice, and sections with nothing else`() throws {
        let box = try Box()
        let sections = [Self.section("s-a", #","unread":[\#(Self.numbers),\#(Self.numbers)]"#),
                        Self.section("s-b", #","unread":[{"file": "../shared/methods.tex", "why": "outside the repository"}]"#)]
        _ = try box.write(sections.joined(separator: "\n") + "\n", to: "o/outline-sections.jsonl")
        _ = try box.write("", to: "o/outline-paragraphs.jsonl")
        #expect(PropositionsCLI.run(["outline", "check", "o"], workingDirectory: box.url) == CommandResult(stdout: ["ok outline check"], exitCode: 0))
        let status = PropositionsCLI.run(["outline", "status", "o"], workingDirectory: box.url)
        #expect(status.exitCode == 0)
        #expect(status.stdout.suffix(2) == ["sections that carry unread\t2\t[\"s-a\",\"s-b\"]", "ok status"])
    }

    // spec-example: article-outline / an unread list that is not in the format
    @Test func `An unread list that is not in the format`() {
        let list = "unread is not a list of one or more files that were not read"
        let entry = "unread has an entry that is not an object with a file and a why that are non-empty strings"
        for (value, expected) in [("[]", list), (#""generated/numbers""#, list), (#"[{"file": "generated/numbers"}]"#, entry),
                                  (#"[{"file": "", "why": "x"}]"#, entry), (#"["generated/numbers"]"#, entry),
                                  (#"[{"file": "a b", "why": "x"}]"#, entry)] {
            let found = OutlineCheck.findings(Outline(sections: Self.section("s-a", #","unread":\#(value)"#) + "\n", paragraphs: "", approvals: nil))
            #expect(found.contains { $0.hasSuffix(expected) }, "\(value) → \(found)")
        }
    }

    // spec-example: article-outline / a dropped section is not counted
    @Test func `A dropped section is not counted`() throws {
        let outline = Outline(sections: Self.section("s-a") + "\n" + Self.section("s-b", #","dropped":"cut","unread":[\#(Self.numbers)]"#) + "\n",
                              paragraphs: "", approvals: nil)
        #expect(try OutlineStatus.lines(outline).suffix(2) == ["sections that carry unread\t0", "ok status"])
    }

    func write(_ arguments: [String], in box: Box) -> CommandResult { PropositionsCLI.run(["write"] + arguments, workingDirectory: box.url) }

    func outline(in box: Box, sections: [String], paragraphs: [(String, String)], whole: Bool) throws {
        _ = try box.write(sections.joined(separator: "\n") + "\n", to: "paper/outline/outline-sections.jsonl")
        let records = paragraphs.map { Self.paragraph($0.0, $0.1) }
        _ = try box.write(records.joined(separator: "\n") + "\n", to: "paper/outline/outline-paragraphs.jsonl")
        let entries = sections.enumerated().map { index, section in
            let id = "s-" + section.components(separatedBy: #""id":"s-"#)[1].prefix { $0 != "\"" }
            let own = paragraphs.filter { $0.1 == id }.map { Self.paragraph($0.0, $0.1) }
            return #"{"section":\#(section),"paragraphs":[\#(own.joined(separator: ","))]}"#
        }
        _ = try box.write(#"{"approved_at":"2026-11-22T10:00:00+08:00","statement":"approved",\#(whole ? #""whole":true,"# : "")"sections":[\#(entries.joined(separator: ","))]}"# + "\n",
                          to: "paper/outline/outline-approvals.jsonl")
    }

    // spec-example: write / prepare names the unread files of the section and of the section above it
    @Test func `Prepare names the unread files of the section and of the section above it`() throws {
        let box = try base.setUp()
        try outline(in: box, sections: [Self.section("s-a", #","unread":[\#(Self.numbers)]"#), Self.section("s-a1", #","parent":"s-a""#),
                                        Self.section("s-b", #","unread":[{"file": "other", "why": "missing"}]"#)],
                    paragraphs: [("p-1", "s-a1")], whole: false)
        let result = write(WriteParagraphTests.prepare + ["--outline", "paper/outline", "--outline-paragraph", "p-1"], in: box)
        #expect(result.exitCode == 0)
        #expect(result.stderr.filter { $0.hasPrefix("[unread]") } == [
            "[unread] section s-a: the included file generated/numbers was not read when the outline was derived (ignored by git); the outline does not say what it holds",
        ])
    }

    // spec-example: write / a rewrite names every unread file
    @Test func `A rewrite names every unread file`() throws {
        let box = try base.setUp()
        try outline(in: box, sections: [Self.section("s-a", #","unread":[\#(Self.numbers),\#(Self.numbers)]"#)], paragraphs: [("p-1", "s-a")], whole: true)
        let result = write(WriteRewriteTests.prepare, in: box)
        #expect(result.exitCode == 0, "\(result.stderr)")
        #expect(result.stderr.filter { $0.hasPrefix("[unread]") }.count == 2)
    }
}
