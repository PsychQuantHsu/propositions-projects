import Foundation
import Testing
@testable import PropositionsKit

/// Several destination documents (issue 120): `destinations` of `article.json`, the part in the
/// trace, a rewrite of one document, and `outline trace` and `outline length` with them.
struct DestinationsTests {
    typealias Box = LedgerOrderTests.Box
    let base = WriteParagraphTests()

    static func section(_ id: String, _ extra: String = "") -> String { #"{"id":"\#(id)","heading":"H","says":"It says this."\#(extra)}"# }
    static func paragraph(_ id: String, _ section: String) -> String {
        #"{"id":"\#(id)","section":"\#(section)","points":[{"id":"\#(id).1","text":"A point."}]}"#
    }
    static let article = #"{"destinations": {"main": {"tex": "../main.tex", "jsonl": "../propositions/main.jsonl"}, "supplement": {"tex": "../supp/supp.tex", "jsonl": "../supp/propositions/main.jsonl"}}}"#
    static let suppProp = "019a3c5e-7a00-7000-8000-0000000000e1"

    /// The structure fixture as the main text, an empty second document, and an outline approved as a whole.
    func setUp(sections: [String] = [section("s-a"), section("s-sup", #","part":"supplement""#)],
               paragraphs: [(String, String)] = [("p-1", "s-a"), ("p-2", "s-a"), ("p-s", "s-sup")]) throws -> Box {
        let box = try base.setUp()
        _ = try box.write("\\documentclass{article}\n\\begin{document}\nSupplementary material.\n\n\\end{document}\n", to: "paper/supp/supp.tex")
        _ = try box.write("", to: "paper/supp/propositions/main.jsonl")
        _ = try box.write("", to: "paper/supp/propositions/discourse.jsonl")
        _ = try box.write(#"{"structure_version": "2.0", "thesis": [], "sections": [], "paragraphs": []}"# + "\n", to: "paper/supp/propositions/structure.json")
        _ = try box.write(sections.joined(separator: "\n") + "\n", to: "paper/outline/outline-sections.jsonl")
        _ = try box.write(paragraphs.map { Self.paragraph($0.0, $0.1) }.joined(separator: "\n") + "\n", to: "paper/outline/outline-paragraphs.jsonl")
        let entries = sections.map { section -> String in
            let id = "s-" + section.components(separatedBy: #""id":"s-"#)[1].prefix { $0 != "\"" }
            return #"{"section":\#(section),"paragraphs":[\#(paragraphs.filter { $0.1 == id }.map { Self.paragraph($0.0, $0.1) }.joined(separator: ","))]}"#
        }
        _ = try box.write(#"{"approved_at":"2026-11-22T11:00:00+08:00","statement":"approved","whole":true,"sections":[\#(entries.joined(separator: ","))]}"# + "\n",
                          to: "paper/outline/outline-approvals.jsonl")
        _ = try box.write(Self.article, to: "paper/outline/article.json")
        return box
    }

    func write(_ arguments: [String], in box: Box) -> CommandResult { PropositionsCLI.run(["write"] + arguments, workingDirectory: box.url) }

    static func prepare(_ document: String, stage: String, _ more: [String]) -> [String] {
        let dir = document == "main" ? "paper/propositions" : "paper/supp/propositions"
        return ["prepare", "--jsonl", "\(dir)/main.jsonl", "--tex", document == "main" ? "paper/main.tex" : "paper/supp/supp.tex",
                "--structure", "\(dir)/structure.json", "--discourse", "\(dir)/discourse.jsonl", "--stage", stage, "--outline", "paper/outline"] + more
    }

    /// Writes p-s into the supplement and commits it.
    func writeSupplement(_ box: Box) throws {
        #expect(write(Self.prepare("supp", stage: "stage-s", ["--outline-paragraph", "p-s"]), in: box).exitCode == 0)
        let staged = box.url.appendingPathComponent("stage-s/manuscript/supp.tex")
        let text = try String(contentsOf: staged, encoding: .utf8).replacingOccurrences(of: "Supplementary material.\n", with: "Supplementary material.\n\nThe extra analysis agrees.\n")
        try text.write(to: staged, atomically: true, encoding: .utf8)
        _ = try box.write(#"{"id": "\#(Self.suppProp)", "text": "The extra analysis agrees.", "location": "main.tex:L5", "claim_type": "claim", "evidence_class": "external", "asserts": ["x"], "cites": []}"# + "\n",
                          to: "stage-s/ledger/main.jsonl")
        _ = try box.write(#"{"prop_id": "\#(Self.suppProp)"}"# + "\n", to: "stage-s/ledger/discourse.jsonl")
        let committed = write(["commit", "--stage", "stage-s"], in: box)
        #expect(committed.exitCode == 0, "\(committed.stderr)")
    }

    func trace(_ box: Box) throws -> [String] {
        try String(contentsOf: box.url.appendingPathComponent("paper/outline/outline-trace.jsonl"), encoding: .utf8).components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    // spec-example: write / a paragraph goes to the document of its part
    @Test func `A paragraph goes to the document of its part`() throws {
        let box = try setUp()
        let refused = write(Self.prepare("main", stage: "stage-x", ["--outline-paragraph", "p-s"]), in: box)
        #expect(refused.exitCode == 2)
        #expect(refused.stderr.first?.contains("goes to the part supplement") == true)
        #expect(refused.stderr.first?.contains("supp/supp.tex") == true && refused.stderr.first?.contains("supp/propositions/main.jsonl") == true)
        #expect(write(Self.prepare("supp", stage: "stage-y", ["--outline-paragraph", "p-1"]), in: box).exitCode == 2)
        try writeSupplement(box)
        #expect(write(Self.prepare("main", stage: "stage", ["--outline-paragraph", "p-1"]), in: box).exitCode == 0)
        try base.draft(box)
        #expect(write(["commit", "--stage", "stage"], in: box).exitCode == 0)
        #expect(try trace(box) == [
            #"{"outline": "p-s", "first_prop": "\#(Self.suppProp)", "section": "s-sup", "approval_line": 1, "part": "supplement"}"#,
            #"{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-00000000000d", "section": "s-a", "approval_line": 1, "part": "main"}"#,
        ])

        // spec-example: article-outline / trace and length with two documents
        func outline(_ arguments: [String]) -> CommandResult { PropositionsCLI.run(["outline"] + arguments, workingDirectory: box.url) }
        #expect(outline(["trace", "paper/outline", "--jsonl", "paper/propositions/main.jsonl"]) == CommandResult(stdout: [
            "p-s\t\(Self.suppProp)\tin the document of the part supplement",
            "p-1\t019a3c5e-7a00-7000-8000-00000000000d\tmain.tex:L32", "2 record(s), 0 problem(s)",
        ], exitCode: 0))
        #expect(outline(["trace", "paper/outline", "--jsonl", "paper/supp/propositions/main.jsonl"]).stdout.first == "p-s\t\(Self.suppProp)\tmain.tex:L5")
        #expect(outline(["trace", "paper/outline", "--jsonl", "paper/propositions/discourse.jsonl"]).exitCode == 2)
        let length = outline(["length", "paper/outline", "--written"])
        #expect(length.exitCode == 0, "\(length.stderr)")
        #expect(length.stdout == [
            "\"s-a\"\tmain\ttarget -\twritten 8\t1 of 2 record(s)", "\"s-sup\"\tsupplement\ttarget -\twritten 4\t1 of 1 record(s)",
            "part main\ttargets 0\twritten 8", "part supplement\ttargets 0\twritten 4", "ok length",
        ])
        let single = outline(["length", "paper/outline", "--jsonl", "paper/propositions/main.jsonl", "--tex", "paper/main.tex"])
        #expect(single.exitCode == 2 && single.stderr.first?.contains("--written") == true)
        #expect(outline(["length", "paper/outline", "--written", "--jsonl", "x", "--tex", "y"]).exitCode == 2)
        // Without destinations --written has nothing to read.
        _ = try box.write("{}", to: "paper/outline/article.json")
        #expect(outline(["length", "paper/outline", "--written"]).exitCode == 2)
    }

    // spec-example: write / a part without a destination
    @Test func `A part without a destination`() throws {
        let box = try setUp(sections: [Self.section("s-a"), Self.section("s-x", #","part":"appendix""#), Self.section("s-x1", #","parent":"s-x""#)],
                            paragraphs: [("p-1", "s-a"), ("p-2", "s-a"), ("p-x", "s-x1")])
        for arguments in [["--outline-paragraph", "p-x"], ["--rewrite"]] {
            let result = write(Self.prepare("main", stage: "stage", arguments), in: box)
            #expect(result.exitCode == 2)
            #expect(result.stderr.first?.contains("goes to the part appendix, for which article.json names no destination") == true, "\(result.stderr)")
        }
        // The files of no destination cannot be rewritten into.
        let other = try setUp()
        _ = try other.write(#"{"destinations": {"supplement": {"tex": "../supp/supp.tex", "jsonl": "../supp/propositions/main.jsonl"}}}"#, to: "paper/outline/article.json")
        #expect(write(Self.prepare("main", stage: "stage", ["--rewrite"]), in: other).stderr.first?.contains("the destination of no part") == true)
    }

    // spec-example: write / a rewrite of one document keeps the trace of the other
    @Test func `A rewrite of one document keeps the trace of the other`() throws {
        let rewrite = WriteRewriteTests()
        let kept = #"{"outline": "p-s", "first_prop": "\#(Self.suppProp)", "section": "s-sup", "approval_line": 1, "part": "supplement"}"#
        let main = [#"{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-000000000001"}"#, #"{"outline": "p-2", "first_prop": "\#(WriteRewriteTests.new)"}"#]
        let box = try setUp()
        // An old record of the main text is replaced; the supplement's stays.
        _ = try box.write(kept + "\n" + #"{"outline": "p-1", "first_prop": "old", "section": "s-a", "approval_line": 1}"# + "\n", to: "paper/outline/outline-trace.jsonl")
        #expect(write(Self.prepare("main", stage: "stage", ["--rewrite"]), in: box).exitCode == 0)
        try rewrite.rewrite(box, map: main)
        let check = write(["check", "--stage", "stage"], in: box)
        #expect(check.exitCode == 0, "\(check.stdout)")
        #expect(write(["commit", "--stage", "stage"], in: box).exitCode == 0)
        #expect(try trace(box) == [
            kept,
            #"{"outline": "p-1", "first_prop": "019a3c5e-7a00-7000-8000-000000000001", "section": "s-a", "approval_line": 1, "part": "main"}"#,
            #"{"outline": "p-2", "first_prop": "\#(WriteRewriteTests.new)", "section": "s-a", "approval_line": 1, "part": "main"}"#,
        ])

        let wrong = try setUp()
        #expect(write(Self.prepare("main", stage: "stage", ["--rewrite"]), in: wrong).exitCode == 0)
        try rewrite.rewrite(wrong, map: main + [#"{"outline": "p-s", "first_prop": "019a3c5e-7a00-7000-8000-000000000002"}"#])
        let refused = write(["check", "--stage", "stage"], in: wrong)
        #expect(refused.exitCode == 1)
        #expect(refused.stdout.contains { $0.contains("outline-map.jsonl line 3: p-s is no paragraph record of the outline that is not dropped and goes to this document") })
    }

    // spec-example: write / destinations that are not in the format
    @Test func `Destinations that are not in the format`() {
        for bad in [#"{"destinations": {}}"#, #"{"destinations": {"online": {"tex": "a.tex", "jsonl": "a.jsonl"}}}"#,
                    #"{"destinations": {"main": {"tex": "/abs/main.tex", "jsonl": "a.jsonl"}}}"#, #"{"destinations": {"main": {"tex": "a.tex"}}}"#,
                    #"{"destinations": []}"#, #"{"destinations": {"main": {"tex": "a.tex", "jsonl": "a.jsonl"}, "main": {"tex": "b.tex", "jsonl": "b.jsonl"}}}"#] {
            #expect(throws: Article.Failure.self, "\(bad)") { try Article.parse(Data(bad.utf8)) }
            let message = (try? Article.parse(Data(bad.utf8))).map { _ in "" } ?? ((try? { () throws -> String in
                do { _ = try Article.parse(Data(bad.utf8)); return "" } catch let failure as Article.Failure { return failure.message }
            }()) ?? "")
            #expect(message.contains("article.json") && message.contains("destinations"), "\(bad): \(message)")
        }
        // Two parts can name one document.
        let shared = try? Article.parse(Data(#"{"destinations": {"main": {"tex": "m.tex", "jsonl": "m.jsonl"}, "appendix": {"tex": "m.tex", "jsonl": "m.jsonl"}}}"#.utf8))
        #expect(shared?.destinations?.count == 2)
        // A trace record's part is one of the three.
        #expect(!WriteFromOutline.hasTraceKeys((try! JSONValue.parse(#"{"outline":"p","first_prop":"x","section":"s","approval_line":1,"part":"online"}"#)).members!))
    }
}
