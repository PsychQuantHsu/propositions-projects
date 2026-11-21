import Foundation
import Testing
@testable import PropositionsKit

/// `propositions revise relocate` (issue 56), and the way it writes a ledger line again.
struct RelocateTests {
    typealias Box = LedgerOrderTests.Box

    static func line(_ id: String, _ location: String, _ text: String) -> String {
        "{\"id\": \"\(id)\", \"text\": \(Revise.quoted(text)), \"location\": \"\(location)\", \"claim_type\": \"claim\"}"
    }

    static let main = "Kept sentence.\n\\input{sections/a}\nNew opening.\nMoved sentence here.\nAlpha beta\n  gamma delta.\nTwice in b? no.\n"
    static let sectionA = "Moved to a.\nTwin.\nTwin.\n"

    func manuscript(_ rows: [String]) throws -> (Box, URL) {
        let box = try Box()
        _ = try box.write(Self.main, to: "main.tex")
        _ = try box.write(Self.sectionA, to: "sections/a.tex")
        return (box, try box.write(rows.map { $0 + "\n" }.joined(), to: "main.jsonl"))
    }

    func run(_ arguments: [String], in box: Box) -> CommandResult {
        PropositionsCLI.run(["revise", "relocate", "--jsonl", "main.jsonl", "--tex", "main.tex"] + arguments, workingDirectory: box.url)
    }

    static let rows = [
        line("k", "main.tex:L1", "Kept sentence."),
        line("b", "L1", "Kept sentence."),
        line("m", "main.tex:L2", "Moved sentence here."),
        line("f", "main.tex:L9", "Moved to a."),
        line("w", "main.tex:L5", "Alpha beta gamma delta."),
        line("t", "main.tex:L3", "Twin."),
        line("x", "main.tex:L7", "Gone from the paper."),
        #"{"id": "r", "text": "Retired.", "location": "L8", "retired": {"since": "2026-01-01", "mechanism": "removed", "match": "absent", "reason": "x"}}"#,
        "// a comment line",
    ]

    // spec-example: revise / each proposition is found in place, moved, rewrapped, ambiguous or missing
    @Test func `A dry run reports where each text now stands and changes nothing`() throws {
        let (box, ledger) = try manuscript(Self.rows)
        let before = try Data(contentsOf: ledger)
        let result = run([], in: box)
        #expect(result.exitCode == 1)
        #expect(result.stdout == [
            "moved m: main.tex:L2 -> main.tex:L4",
            "moved f: main.tex:L9 -> sections/a.tex:L1",
            "rewrapped w: main.tex:L5 -> main.tex:L5-L6",
            "ambiguous t: main.tex:L3; its text stands at sections/a.tex:L2, sections/a.tex:L3",
            "missing x: main.tex:L7",
            "2 in place, 2 moved, 1 rewrapped, 1 ambiguous, 1 missing",
        ])
        #expect(try Data(contentsOf: ledger) == before)
    }

    // spec-example: revise / only the moved and rewrapped lines are written again
    @Test func `Writing changes only the moved and rewrapped lines`() throws {
        let (box, ledger) = try manuscript(Self.rows)
        let result = run(["--write"], in: box)
        #expect(result.exitCode == 1)
        #expect(result.stdout.last == "written: main.jsonl")
        let lines = String(decoding: try Data(contentsOf: ledger), as: UTF8.self).components(separatedBy: "\n")
        var expected = Self.rows
        expected[2] = Self.line("m", "main.tex:L4", "Moved sentence here.")
        expected[3] = Self.line("f", "sections/a.tex:L1", "Moved to a.")
        expected[4] = Self.line("w", "main.tex:L5-L6", "Alpha beta\n  gamma delta.")
        #expect(lines == expected + [""])
        let again = run([], in: box)
        #expect(again.stdout.last == "5 in place, 0 moved, 0 rewrapped, 1 ambiguous, 1 missing")
    }

    @Test func `A ledger whose propositions all stand in place exits with 0`() throws {
        let (box, _) = try manuscript([Self.rows[0], Self.rows[1]])
        #expect(run(["--write"], in: box) == CommandResult(stdout: ["2 in place, 0 moved, 0 rewrapped, 0 ambiguous, 0 missing"], exitCode: 0))
    }

    @Test func `A location in another file is found there first, nearest its line`() throws {
        let (box, _) = try manuscript([Self.line("t", "sections/a.tex:L3", "Twin."), Self.line("u", "sections/a.tex:L1", "Twin.")])
        #expect(run([], in: box).stdout == ["moved u: sections/a.tex:L1 -> sections/a.tex:L2",
                                           "1 in place, 1 moved, 0 rewrapped, 0 ambiguous, 0 missing"])
    }

    @Test(arguments: [
        ([#"{"id": "n", "location": "L1"}"#], "has no text"),
        (["{oops"], "invalid JSON"),
    ])
    func `Refuses a ledger it cannot read`(rows: [String], message: String) throws {
        let (box, ledger) = try manuscript(rows)
        let before = try Data(contentsOf: ledger)
        let result = run(["--write"], in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr.last?.contains(message) == true)
        #expect(try Data(contentsOf: ledger) == before)
    }

    // spec-example: revise / a line is written again as the Python tools write it
    @Test(.enabled(if: ParityTests.interpreter != nil), arguments: [
        #"{"id":"a","text":"q\"\\\t\u0001é \u007f — “x”","n":[1,-2,1.5,1e-05,true,null],"o":{"k":"v"}}"#,
        #"{"id": "b", "id": "c", "location": "L1", "text": "x"}"#,
        #"{"text":"line\nbreak\r\u000b\f\b"}"#,
        "{}",
    ])
    func `A line is written again as json.dumps writes it`(line: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try #require(ParityTests.interpreter))
        process.arguments = ["-c", "import json,sys; sys.stdout.write(json.dumps(json.loads(sys.stdin.read()), ensure_ascii=False))"]
        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        try process.run()
        input.fileHandleForWriting.write(Data(line.utf8))
        input.fileHandleForWriting.closeFile()
        let python = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        #expect(Revise.dumps(try JSONValue.parse(line)) == python)
    }

    @Test func `The command states its interface`() throws {
        let help = PropositionsCLI.run(["revise", "relocate", "--help"], workingDirectory: repositoryRoot)
        #expect(help.exitCode == 0)
        for word in ["--jsonl", "--tex", "--write", "Exit codes"] { #expect(help.stdout.joined(separator: "\n").contains(word)) }
        #expect(PropositionsCLI.run(["--help"], workingDirectory: repositoryRoot).stdout.joined().contains("revise"))
    }
}
