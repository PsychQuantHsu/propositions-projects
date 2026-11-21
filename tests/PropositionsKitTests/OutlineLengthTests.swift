import Foundation
import Testing
@testable import PropositionsKit

/// Length targets and `propositions outline length` (issue 119).
struct OutlineLengthTests {
    typealias Box = LedgerOrderTests.Box

    static func section(_ id: String, _ extra: String = "") -> String { #"{"id":"\#(id)","heading":"H","says":"It says this."\#(extra)}"# }
    static func paragraph(_ id: String, _ section: String) -> String {
        #"{"id":"\#(id)","section":"\#(section)","points":[{"id":"\#(id).1","text":"A point."}]}"#
    }

    func run(_ arguments: [String], in box: Box) -> CommandResult { PropositionsCLI.run(["outline", "length"] + arguments, workingDirectory: box.url) }

    // spec-example: article-outline / targets are reported against the limit before anything is written
    @Test func `Targets are reported against the limit before anything is written`() throws {
        let box = try Box()
        let sections = [Self.section("s-a", #","length":300"#), Self.section("s-b", #","length":500"#), Self.section("s-b1", #","parent":"s-b","length":600"#),
                        Self.section("s-x", #","part":"appendix","length":200"#), Self.section("s-gone", #","dropped":"cut","length":900"#)]
        _ = try box.write(sections.joined(separator: "\n") + "\n", to: "o/outline-sections.jsonl")
        _ = try box.write(Self.paragraph("p-1", "s-a") + "\n", to: "o/outline-paragraphs.jsonl")
        _ = try box.write(#"{"length": {"limit": 700}}"#, to: "o/article.json")
        #expect(run(["o"], in: box) == CommandResult(stdout: [
            "\"s-a\"\tmain\ttarget 300", "\"s-b\"\tmain\ttarget 500\tits subsections plan 600", "\"s-b1\"\tmain\ttarget 600",
            "\"s-x\"\tappendix\ttarget 200", "part main\ttargets 800", "part appendix\ttargets 200",
            "limit 700\tmain\ttargets 800 (over by 100)", "ok length",
        ], exitCode: 0))
        // Both parts under the limit, and a subsection takes the part of its section.
        _ = try box.write(#"{"length": {"limit": 1000, "parts": ["main", "appendix"]}}"#, to: "o/article.json")
        _ = try box.write([Self.section("s-x", #","part":"appendix""#), Self.section("s-x1", #","parent":"s-x","length":200"#)].joined(separator: "\n") + "\n", to: "o/outline-sections.jsonl")
        _ = try box.write("", to: "o/outline-paragraphs.jsonl")
        #expect(run(["o"], in: box).stdout == ["\"s-x\"\tappendix\ttarget -", "\"s-x1\"\tappendix\ttarget 200", "part appendix\ttargets 200",
                                               "limit 1000\tmain,appendix\ttargets 200", "ok length"])
        #expect(run(["o", "--jsonl", "x"], in: box).exitCode == 2)
    }

    // spec-example: article-outline / what was written is counted from the trace
    @Test func `What was written is counted from the trace`() throws {
        let box = try WriteParagraphTests().setUp()
        _ = try box.write(Self.section("s-a", #","length":5"#) + "\n", to: "paper/outline/outline-sections.jsonl")
        _ = try box.write(Self.paragraph("p-1", "s-a") + "\n" + Self.paragraph("p-2", "s-a") + "\n", to: "paper/outline/outline-paragraphs.jsonl")
        let arguments = ["paper/outline", "--jsonl", "paper/propositions/main.jsonl", "--tex", "paper/main.tex"]
        // Nothing written yet: no trace file.
        #expect(run(arguments, in: box).stdout == ["\"s-a\"\tmain\ttarget 5\twritten 0\t0 of 2 record(s)", "part main\ttargets 5\twritten 0", "ok length"])
        let trace = [#"{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-00000000000c", "section": "s-a", "approval_line": 1}"#,
                     #"{"outline": "p-2", "first_prop": "019a3c5e-7a00-7000-8000-0000000000ff", "section": "s-a", "approval_line": 1}"#]
        _ = try box.write(trace[0] + "\n", to: "paper/outline/outline-trace.jsonl")
        #expect(run(arguments, in: box) == CommandResult(stdout: [
            "\"s-a\"\tmain\ttarget 5\twritten 13\t1 of 2 record(s)\tover its target by 8", "part main\ttargets 5\twritten 13", "ok length",
        ], exitCode: 0))
        // A record whose proposition the ledger does not have is not counted, and is said.
        _ = try box.write(trace.joined(separator: "\n") + "\n", to: "paper/outline/outline-trace.jsonl")
        _ = try box.write(#"{"length": {"limit": 10}}"#, to: "paper/outline/article.json")
        let result = run(arguments, in: box)
        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("limit 10\tmain\ttargets 5\twritten 13 (over by 3)"))
        #expect(result.stdout.contains { $0.hasPrefix("1 record(s) of the trace name no live proposition") })
    }

    // spec-example: article-outline / how words are counted
    @Test func `How words are counted`() {
        #expect(OutlineLength.words(in: ["The well-known effect ($d = 0.8$) isn't small~\\cite{smith2020}. % not this"]) == 5)
        #expect(OutlineLength.words(in: ["\\begin{equation}", "x = y + z", "\\end{equation}"]) == 0)
        #expect(OutlineLength.words(in: ["\\begin{align*}", "a &= b", "\\end{align*}", "after it"]) == 2)
        #expect(OutlineLength.words(in: ["\\emph{Recall} was 0.62."]) == 3)
        #expect(OutlineLength.words(in: ["間隔複習有效"]) == 6)
        #expect(OutlineLength.words(in: ["間隔 spacing 有效"]) == 5)
        #expect(OutlineLength.words(in: ["Costs \\$5 and 10\\% more \\[ x \\] done \\( y \\) end"]) == 7)
        #expect(OutlineLength.words(in: ["See Figure~\\ref{fig:a} and \\citep[p.~3]{k} here.", "$$ a", "b $$ tail"]) == 5)
        #expect(OutlineLength.words(in: ["\\begin{itemize}", "\\item one two", "\\end{itemize}"]) == 2)
        #expect(OutlineLength.words(in: ["unclosed $ math never ends"]) == 1)
    }

    // spec-example: article-outline / a length that is not in the format
    @Test func `A length that is not in the format`() throws {
        for bad in ["0", "1.5", #""300""#, "1e9", "-3"] {
            let outline = Outline(sections: Self.section("s-a", #","length":\#(bad)"#) + "\n", paragraphs: "", approvals: nil)
            #expect(OutlineCheck.findings(outline).contains { $0.hasSuffix("length is not a whole number from 1 to 999999999") }, "\(bad)")
        }
        #expect(OutlineCheck.findings(Outline(sections: Self.section("s-a", #","length":3e2"#) + "\n", paragraphs: "", approvals: nil)).isEmpty)
        for bad in [#"{"length": {"limit": 0}}"#, #"{"length": 700}"#, #"{"length": {"limit": 700, "parts": ["online"]}}"#,
                    #"{"length": {"limit": 700, "parts": []}}"#, #"{"length": {"limit": 700, "parts": ["main", "main"]}}"#] {
            let box = try Box()
            _ = try box.write(Self.section("s-a") + "\n", to: "o/outline-sections.jsonl")
            _ = try box.write("", to: "o/outline-paragraphs.jsonl")
            _ = try box.write(bad, to: "o/article.json")
            let result = run(["o"], in: box)
            #expect(result.exitCode == 2)
            #expect(result.stderr.first?.contains("article.json") == true, "\(bad)")
        }
        // An outline that does not pass the check is refused.
        let box = try Box()
        _ = try box.write(Self.section("s-a", #","length":0"#) + "\n", to: "o/outline-sections.jsonl")
        _ = try box.write("", to: "o/outline-paragraphs.jsonl")
        #expect(run(["o"], in: box).exitCode == 2)
    }

    // MARK: fix round 1

    // spec-example: article-outline / names with spaces, groups after a name, and a spaced end
    @Test func `Names with spaces, groups after a name, and a spaced end`() {
        #expect(OutlineLength.words(in: ["See \\cite {smith2020} and \\label{eq:r}{visible words} here."]) == 5)
        #expect(OutlineLength.words(in: ["\\begin{equation}", "x = y", "\\end {equation}", "After it."]) == 2)
        #expect(OutlineLength.words(in: ["カ・ナ ｶﾅ ¼ cup"]) == 5)
        #expect(OutlineLength.words(in: ["a \\[ x \\\\ y \\] b"]) == 2)
        #expect(OutlineLength.words(in: ["\\includegraphics [width=1cm] {fig/a} shown"]) == 1)
    }

    // spec-example: article-outline / a stale record, a repeated record and an unreadable file
    @Test func `A stale record, a repeated record and an unreadable file`() throws {
        let box = try WriteParagraphTests().setUp()
        _ = try box.write(Self.section("s-a") + "\n", to: "paper/outline/outline-sections.jsonl")
        _ = try box.write(#"{"id":"p-old","section":"s-a","points":[{"id":"p-old.1","text":"A point."}],"dropped":"cut"}"# + "\n" + Self.paragraph("p-1", "s-a") + "\n",
                          to: "paper/outline/outline-paragraphs.jsonl")
        func record(_ id: String) -> String { #"{"outline": "\#(id)", "first_prop": "019a3c5e-7a00-7000-8000-00000000000c", "section": "s-a", "approval_line": 1}"# }
        _ = try box.write([record("p-old"), record("p-1"), record("p-1")].joined(separator: "\n") + "\n", to: "paper/outline/outline-trace.jsonl")
        let arguments = ["paper/outline", "--jsonl", "paper/propositions/main.jsonl", "--tex", "paper/main.tex"]
        #expect(run(arguments, in: box).stdout.first == "\"s-a\"\tmain\ttarget -\twritten 13\t1 of 1 record(s)")
        try Data([0xFF, 0xFE, 0x0A]).write(to: box.url.appendingPathComponent("paper/main.tex"))
        let unreadable = run(arguments, in: box)
        #expect(unreadable.exitCode == 2)
        #expect(unreadable.stdout.isEmpty)
    }

    // MARK: review round 2

    @Test func `Unfinished LaTeX and arguments on the next line`() {
        #expect(OutlineLength.words(in: ["Text \\begin{equation} x=y \\end{"]) == 1)
        #expect(OutlineLength.words(in: ["Text \\begin{"]) == 1)
        #expect(OutlineLength.words(in: ["Text \\cite{"]) == 1)
        #expect(OutlineLength.words(in: ["See \\cite", "[see also]", "{smith2020} here."]) == 2)
        #expect(OutlineLength.words(in: ["See \\cite", "", "{smith2020} here."]) == 3)
        #expect(OutlineLength.words(in: ["See \\cite[see {A] B}]{smith2020} here."]) == 2)
    }

    @Test func `Two propositions of one paragraph count the paragraph once`() throws {
        let box = try WriteParagraphTests().setUp()
        _ = try box.write(Self.section("s-a") + "\n", to: "paper/outline/outline-sections.jsonl")
        _ = try box.write(Self.paragraph("p-1", "s-a") + "\n" + Self.paragraph("p-2", "s-a") + "\n", to: "paper/outline/outline-paragraphs.jsonl")
        // Propositions 1 and 2 of the fixture stand in the same paragraph.
        let ledger = try String(contentsOf: box.url.appendingPathComponent("paper/propositions/main.jsonl"), encoding: .utf8).components(separatedBy: "\n")
        func location(_ line: String) throws -> Location {
            let text = try JSONValue.parse(line)["location"]?.string
            return try #require(text.flatMap(Location.parse))
        }
        let first = try location(ledger[0]), second = try location(ledger[1])
        let text = LatexLine.splitLines(try String(contentsOf: box.url.appendingPathComponent("paper/main.tex"), encoding: .utf8))
        let runs = Paragraphs.runs(text)
        try #require(runs[first.start - 1] == runs[second.start - 1])
        func record(_ id: String, _ prop: String) -> String { #"{"outline": "\#(id)", "first_prop": "019a3c5e-7a00-7000-8000-00000000000\#(prop)", "section": "s-a", "approval_line": 1}"# }
        _ = try box.write(record("p-1", "1") + "\n", to: "paper/outline/outline-trace.jsonl")
        let arguments = ["paper/outline", "--jsonl", "paper/propositions/main.jsonl", "--tex", "paper/main.tex"]
        let one = run(arguments, in: box).stdout[0]
        _ = try box.write(record("p-1", "1") + "\n" + record("p-2", "2") + "\n", to: "paper/outline/outline-trace.jsonl")
        #expect(run(arguments, in: box).stdout[0] == one)
    }
}
