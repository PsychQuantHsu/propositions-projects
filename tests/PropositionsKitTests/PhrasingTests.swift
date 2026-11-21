import Foundation
import Testing
@testable import PropositionsKit

/// The banned phrasings of `article.json` (issue 118): the comparison, the write check and
/// `propositions phrasing`.
struct PhrasingTests {
    typealias Box = LedgerOrderTests.Box
    let base = WriteParagraphTests()
    static let article = #"{"banned": [{"phrase": "very  Large", "reason": "the effect is reported with its size"}]}"#

    func write(_ arguments: [String], in box: Box) -> CommandResult { PropositionsCLI.run(["write"] + arguments, workingDirectory: box.url) }

    // spec-example: write / a paragraph that holds a banned phrasing is refused
    @Test func `A paragraph that holds a banned phrasing is refused`() throws {
        let box = try base.setUp()
        _ = try box.write(Self.article + "\n", to: "paper/propositions/article.json")
        let main = try Data(contentsOf: box.url.appendingPathComponent("paper/main.tex"))
        #expect(write(WriteParagraphTests.prepare, in: box).exitCode == 0)
        try base.draft(box, text: "The effect was very\nlarge.")
        let check = write(["check", "--stage", "stage"], in: box)
        #expect(check.exitCode == 1)
        #expect(check.stdout.first == #"main.tex:L32: the banned phrasing "very  Large" (the effect is reported with its size)"#)
        let commit = write(["commit", "--stage", "stage"], in: box)
        #expect(commit.exitCode == 2)
        #expect(try Data(contentsOf: box.url.appendingPathComponent("paper/main.tex")) == main)
        // Without the phrasing the same run passes, and the file is an input like any other.
        let clean = try base.setUp()
        _ = try clean.write(Self.article + "\n", to: "paper/propositions/article.json")
        #expect(write(WriteParagraphTests.prepare, in: clean).exitCode == 0)
        try base.draft(clean)
        #expect(write(["check", "--stage", "stage"], in: clean).exitCode == 0)
        #expect(write(["commit", "--stage", "stage"], in: clean).exitCode == 0)
    }

    // spec-example: write / a comment, another paragraph and other text do not make a phrasing
    @Test func `A comment, another paragraph and other text do not make a phrasing`() {
        let banned = [Article.Banned(phrase: "very large", reason: "r")]
        func found(_ lines: [String]) -> [String] { Phrasing.occurrences(in: lines, file: "f.tex", banned: banned) }
        #expect(found(["The effect was very % large", "big."]).isEmpty)
        #expect(found(["It was very", "", "large."]).isEmpty)
        #expect(found(["It was very", "   ", "large."]).isEmpty)
        #expect(found(["A very largely held view."]).count == 1)   // literal: no word boundary
        #expect(found(["It was VERY", "  large."]) == [#"f.tex:L1: the banned phrasing "very large" (r)"#])
        #expect(found(["100\\% very large"]).count == 1)
        #expect(found(["a \\\\% very large"]).isEmpty)
        #expect(found(["very large and very\tlarge"]).count == 2)
        #expect(Phrasing.occurrences(in: ["x", "very large"], first: 10, file: "f.tex", banned: banned).first?.hasPrefix("f.tex:L11:") == true)
        // Form C on both sides, and CJK text.
        let composed = [Article.Banned(phrase: "caf\u{E9}", reason: "r"), Article.Banned(phrase: "顯著 提升", reason: "r")]
        #expect(Phrasing.occurrences(in: ["Cafe\u{301} 顯著　提升"], file: "f.tex", banned: composed).count == 2)
    }

    // spec-example: write / article.json changed after prepare, or not in the format
    @Test func `An article file that is not in the format, or changed after prepare, is refused`() throws {
        for bad in [#"{"banned": [{"phrase": " ", "reason": "x"}]}"#, #"{"banned": {}}"#, "[]", #"{"banned": [{"phrase": "x"}]}"#, "{"] {
            let box = try base.setUp()
            _ = try box.write(bad, to: "paper/propositions/article.json")
            let result = write(WriteParagraphTests.prepare, in: box)
            #expect(result.exitCode == 2)
            #expect(result.stderr.first?.contains("article.json") == true)
        }
        // Keys this version does not define are left alone, and a file without banned is fine.
        #expect(try Article.parse(Data(#"{"length": {"limit": 8000}, "other": 1}"#.utf8)).banned.isEmpty)
        let box = try base.setUp()
        _ = try box.write(Self.article + "\n", to: "paper/propositions/article.json")
        #expect(write(WriteParagraphTests.prepare, in: box).exitCode == 0)
        try base.draft(box)
        _ = try box.write(#"{"banned": []}"#, to: "paper/propositions/article.json")
        let check = write(["check", "--stage", "stage"], in: box)
        #expect(check.exitCode == 1)
        #expect(check.stdout.contains { $0.contains("article.json") && $0.contains("changed after prepare") })
        #expect(write(["commit", "--stage", "stage"], in: box).exitCode == 2)
        // A link in its place is not read.
        let linked = try base.setUp()
        _ = try linked.write(Self.article, to: "elsewhere.json")
        try FileManager.default.createSymbolicLink(at: linked.url.appendingPathComponent("paper/propositions/article.json"),
                                                   withDestinationURL: linked.url.appendingPathComponent("elsewhere.json"))
        #expect(write(WriteParagraphTests.prepare, in: linked).exitCode == 2)
    }

    // spec-example: write / a rewrite is compared over every file of the tree
    @Test func `A rewrite is compared over every file of the tree`() throws {
        let rewrite = WriteRewriteTests()
        let box = try rewrite.setUp()
        _ = try box.write(#"{"banned": [{"phrase": "confounded spacing", "reason": "say what was confounded with what"}]}"#, to: "paper/outline/article.json")
        // The article file beside the ledger is not the one a run with an outline reads.
        _ = try box.write("not json", to: "paper/propositions/article.json")
        #expect(write(WriteRewriteTests.prepare, in: box).exitCode == 0)
        try rewrite.rewrite(box)
        let lines = try String(contentsOf: box.url.appendingPathComponent("stage/manuscript/main.tex"), encoding: .utf8).components(separatedBy: "\n")
        let line = lines.firstIndex { $0.contains("confounded spacing") }! + 1
        let check = write(["check", "--stage", "stage"], in: box)
        #expect(check.exitCode == 1)
        #expect(check.stdout.contains { $0.hasPrefix("main.tex:L\(line): the banned phrasing \"confounded spacing\"") })
        #expect(write(["commit", "--stage", "stage"], in: box).exitCode == 2)
    }

    // spec-example: write / phrasing scans the input tree
    @Test func `Phrasing scans the input tree`() throws {
        let box = try Box()
        _ = try box.write("\\begin{document}\nIntro.\n\\input{sections/intro}\n\\end{document}\n", to: "main.tex")
        _ = try box.write("First line.\nThis Clearly  shows it.\n", to: "sections/intro.tex")
        _ = try box.write(#"{"banned": [{"phrase": "clearly shows", "reason": "say what the data show"}, {"phrase": "it is obvious", "reason": "show it"}]}"#, to: "article.json")
        func run(_ article: String = "article.json") -> CommandResult {
            PropositionsCLI.run(["phrasing", "--tex", "main.tex", "--article", article], workingDirectory: box.url)
        }
        #expect(run() == CommandResult(stdout: [
            #"sections/intro.tex:L2: the banned phrasing "clearly shows" (say what the data show)"#,
            "1 occurrence(s) of 2 banned phrasing(s) in 2 file(s)",
        ], exitCode: 1))
        _ = try box.write("First line.\n", to: "sections/intro.tex")
        #expect(run() == CommandResult(stdout: ["0 occurrence(s) of 2 banned phrasing(s) in 2 file(s)"], exitCode: 0))
        #expect(run("none.json").exitCode == 2)
        _ = try box.write("[]", to: "bad.json")
        #expect(run("bad.json").exitCode == 2)
    }

    // MARK: fix round 1

    /// Removes a key from the staged write.json, as an edit by hand would.
    static func remove(_ key: String, from box: Box, stage: String = "stage") throws {
        let url = box.url.appendingPathComponent("\(stage)/write.json")
        var object = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        object.removeValue(forKey: key)
        try JSONSerialization.data(withJSONObject: object).write(to: url)
    }

    // spec-example: write / how the comparison folds case, ends and overlaps
    @Test func `How the comparison folds case, ends and overlaps`() {
        let banned = [Article.Banned(phrase: "Straße", reason: "r"), Article.Banned(phrase: " cat ", reason: "r"), Article.Banned(phrase: "ana", reason: "r")]
        func found(_ lines: [String]) -> [String] { Phrasing.occurrences(in: lines, file: "f.tex", banned: banned) }
        #expect(found(["Die STRASSE ist lang."]) == [#"f.tex:L1: the banned phrasing "Straße" (r)"#])
        #expect(found(["We concatenate lists."]).isEmpty)
        #expect(found(["A cat", "sat."]) == [#"f.tex:L1: the banned phrasing " cat " (r)"#])
        #expect(found(["banana"]).count == 2)
        #expect(found(["Unrelated %\u{0301} strasse"]).isEmpty)
        #expect(found(["ΟΔΟΣ"]).isEmpty)
        #expect(Phrasing.occurrences(in: ["οδός ΟΔΌΣ"], file: "f.tex", banned: [Article.Banned(phrase: "ΟΔΌΣ", reason: "r")]).count == 2)
    }

    // spec-example: write / write.json that no longer names what prepare copied
    @Test func `A write json that no longer names what prepare copied is refused`() throws {
        let box = try base.setUp()
        _ = try box.write(Self.article + "\n", to: "paper/propositions/article.json")
        #expect(write(WriteParagraphTests.prepare, in: box).exitCode == 0)
        try base.draft(box, text: "The effect was very large.")
        try Self.remove("article", from: box)
        let outlined = try base.setUp()
        try WriteFromOutlineTests().outline(in: outlined)
        #expect(write(WriteParagraphTests.prepare + ["--outline", "paper/outline", "--outline-paragraph", "p-1"], in: outlined).exitCode == 0)
        try base.draft(outlined)
        try Self.remove("outline", from: outlined)
        for edited in [box, outlined] {
            for command in ["check", "commit"] {
                let result = write([command, "--stage", "stage"], in: edited)
                #expect(result.exitCode == 2)
                #expect(result.stderr.first?.contains("prepare again") == true, "\(result)")
            }
        }
    }

    // spec-example: write / a rewrite that adds an included file
    @Test func `A rewrite that adds an included file is reported`() throws {
        let rewrite = WriteRewriteTests()
        let box = try rewrite.setUp()
        #expect(write(WriteRewriteTests.prepare, in: box).exitCode == 0)
        try rewrite.rewrite(box)
        try rewrite.edit(box, "stage/manuscript/main.tex") { $0.replacingOccurrences(of: "\\end{document}", with: "\\input{extra}\n\\end{document}") }
        _ = try box.write("Extra text.\n", to: "stage/manuscript/extra.tex")
        let check = write(["check", "--stage", "stage"], in: box)
        #expect(check.exitCode == 1)
        #expect(check.stdout.contains("the staged manuscript includes extra.tex, which prepare did not copy: a rewrite cannot add a file to the input tree"))
    }

    // spec-example: write / the main file is reported under its own name
    @Test func `The main file is reported under its own name`() throws {
        let box = try Box()
        _ = try box.write("\\begin{document}\nSupplementary material.\n\n\\end{document}\n", to: "s/supp.tex")
        _ = try box.write("", to: "s/p/main.jsonl")
        _ = try box.write("", to: "s/p/discourse.jsonl")
        _ = try box.write("{}", to: "s/p/structure.json")
        _ = try box.write(#"{"banned": [{"phrase": "extra analysis", "reason": "name it"}]}"#, to: "s/p/article.json")
        #expect(write(["prepare", "--jsonl", "s/p/main.jsonl", "--tex", "s/supp.tex", "--structure", "s/p/structure.json", "--discourse", "s/p/discourse.jsonl", "--stage", "stage"], in: box).exitCode == 0)
        let staged = box.url.appendingPathComponent("stage/manuscript/supp.tex")
        try String(contentsOf: staged, encoding: .utf8).replacingOccurrences(of: "material.\n", with: "material.\n\nThe extra analysis agrees.\n").write(to: staged, atomically: true, encoding: .utf8)
        _ = try box.write(#"{"id": "019a3c5e-7a00-7000-8000-0000000000e1", "text": "The extra analysis agrees.", "location": "main.tex:L4"}"# + "\n", to: "stage/ledger/main.jsonl")
        let check = write(["check", "--stage", "stage"], in: box)
        #expect(check.exitCode == 1)
        #expect(check.stdout.first?.hasPrefix("supp.tex:L4: the banned phrasing") == true, "\(check.stdout)")
    }
}
