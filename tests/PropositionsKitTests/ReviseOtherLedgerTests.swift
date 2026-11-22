import Foundation
import Testing
@testable import PropositionsKit

/// A `replaced_by` item that names a proposition of another ledger (issue 133, schema v1.9).
struct ReviseOtherLedgerTests {
    typealias Box = LedgerOrderTests.Box
    typealias Rows = ReviseLedgerTests

    func run(_ arguments: [String], in box: Box) -> CommandResult {
        PropositionsCLI.run(["revise"] + arguments, workingDirectory: box.url)
    }

    /// The main ledger of `ReviseLedgerTests`, and a supplement ledger with `s1` live and `s2` retired.
    func ledgers() throws -> (Box, URL) {
        let box = try Box()
        _ = try box.write(Rows.main, to: "main.tex")
        let main = try box.write(Rows.rows.map { $0 + "\n" }.joined(), to: "main.jsonl")
        _ = try box.write(Rows.row("s1", "supp.tex:L1", "Moved.") + "\n"
            + #"{"id": "s2", "text": "Old.", "location": "supp.tex:L2", "retired": {"since": "2026-11-20", "mechanism": "removed", "match": "exact", "reason": "x"}}"#
            + "\n", to: "supp/supp.jsonl")
        return (box, main)
    }

    static func retire(_ replacement: String) -> [String] {
        ["retire", "--jsonl", "main.jsonl", "--retire", replacement, "--since", "2026-11-23", "--reason", "moved"]
    }

    // spec-example: revise / a retirement names a proposition of another ledger
    @Test func `Retiring a proposition moved to another document records the ledger and the id`() throws {
        let (box, file) = try ledgers()
        let written = run(Self.retire("old=b,supp/supp.jsonl#s1") + ["--write"], in: box)
        #expect(written.stdout.first == "retire old: replaced by b, supp/supp.jsonl#s1")
        #expect(written.exitCode == 0)
        let line = String(decoding: try Data(contentsOf: file), as: UTF8.self).components(separatedBy: "\n")[1]
        #expect(line.hasSuffix(#""replaced_by": ["b", {"ledger": "supp/supp.jsonl", "id": "s1"}]}}"#))
        #expect(run(["check", "--jsonl", "main.jsonl"], in: box)
            == CommandResult(stdout: ["1 replaced, 0 deleted, 0 without replaced_by, 0 problem(s)"], exitCode: 0))
    }

    @Test func `A proposition of another ledger has to be one live line of it`() throws {
        let (box, file) = try ledgers()
        let before = try Data(contentsOf: file)
        for (argument, why) in [("old=supp/supp.jsonl#s2", "is retired"), ("old=supp/supp.jsonl#zz", "is no proposition of that ledger"),
                                ("old=supp/none.jsonl#s1", "is in a ledger that cannot be read"),
                                ("old=main.jsonl#b", "names this ledger: write the id alone")] {
            let result = run(Self.retire(argument) + ["--write"], in: box)
            #expect(result.exitCode == 2)
            #expect(result.stderr.first?.contains(why) == true, "\(argument): \(result.stderr)")
        }
        #expect(run(Self.retire("old=/abs/supp.jsonl#s1"), in: box).exitCode == 2)
        #expect(run(Self.retire("old=#s1"), in: box).exitCode == 2)
        #expect(try Data(contentsOf: file) == before)
    }

    @Test func `Check reads the other ledger, from the original's directory when given a copy`() throws {
        let (box, _) = try ledgers()
        #expect(run(Self.retire("old=supp/supp.jsonl#s1") + ["--write"], in: box).exitCode == 0)
        // The supplement's proposition retired afterwards: the replacement no longer names a live one.
        let supp = box.url.appendingPathComponent("supp/supp.jsonl")
        let text = try String(contentsOf: supp, encoding: .utf8)
        try text.replacingOccurrences(of: #""cites": []}"#, with: #""cites": [], "retired": {"since": "2026-11-23", "mechanism": "removed", "match": "exact", "reason": "y"}}"#)
            .write(to: supp, atomically: true, encoding: .utf8)
        let result = run(["check", "--jsonl", "main.jsonl"], in: box)
        #expect(result.exitCode == 1)
        #expect(result.stdout.first == "line 2: old is replaced by supp/supp.jsonl#s1, which is retired")
        // A copy elsewhere resolves the path from --ledger-dir.
        try text.write(to: supp, atomically: true, encoding: .utf8)
        _ = try box.write(try String(contentsOf: box.url.appendingPathComponent("main.jsonl"), encoding: .utf8), to: "stage/ledger/main.jsonl")
        #expect(run(["check", "--jsonl", "stage/ledger/main.jsonl"], in: box).exitCode == 1)
        #expect(run(["check", "--jsonl", "stage/ledger/main.jsonl", "--ledger-dir", "."], in: box).exitCode == 0)
    }

    @Test func `A malformed item is a problem, not an id`() throws {
        let (box, _) = try ledgers()
        _ = try box.write(Rows.row("a", "main.tex:L1", "First.") + "\n"
            + #"{"id": "old", "text": "Gone.", "location": "main.tex:L2", "retired": {"since": "2026-11-23", "mechanism": "removed", "match": "exact", "reason": "x", "replaced_by": [{"ledger": "supp/supp.jsonl", "id": "s1", "extra": 1}]}}"#
            + "\n", to: "main.jsonl")
        let result = run(["check", "--jsonl", "main.jsonl"], in: box)
        #expect(result.exitCode == 1)
        #expect(result.stdout.first?.contains("neither an id nor") == true)
    }

    // spec-example: revise / a citation is not carried into another ledger
    @Test func `Redirect drops a citation whose replacements are all in another ledger and names them`() throws {
        let (box, _) = try ledgers()
        #expect(run(Self.retire("old=supp/supp.jsonl#s1") + ["--retire", "gone2", "--write"], in: box).exitCode == 0)
        let result = run(["redirect", "--jsonl", "main.jsonl", "--tex", "main.tex"], in: box)
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains("drop c: old is replaced only in another ledger (supp/supp.jsonl#s1), which a citation cannot cross"))
        #expect(result.stdout.contains("drop d: gone2 is retired and has no replacement"))
    }

    @Test func `Redirect keeps the replacements of this ledger and notes the others`() throws {
        let (box, _) = try ledgers()
        #expect(run(Self.retire("old=a,supp/supp.jsonl#s1") + ["--write"], in: box).exitCode == 0)
        let result = run(["redirect", "--jsonl", "main.jsonl", "--tex", "main.tex"], in: box)
        #expect(result.stdout.contains("note d: old is also replaced in another ledger (supp/supp.jsonl#s1), which a citation cannot cross"))
        #expect(result.stdout.contains("redirect d: old -> a"))
    }
}
