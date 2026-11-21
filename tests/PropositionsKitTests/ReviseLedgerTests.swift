import Foundation
import Testing
@testable import PropositionsKit

/// `propositions revise retire`, `revise check` and `revise redirect` (issue 56, schema v1.8).
struct ReviseLedgerTests {
    typealias Box = LedgerOrderTests.Box

    static func row(_ id: String, _ location: String, _ text: String, cites: [String] = []) -> String {
        "{\"id\": \"\(id)\", \"text\": \"\(text)\", \"location\": \"\(location)\", \"cites\": [\(cites.map { "\"\($0)\"" }.joined(separator: ", "))]}"
    }

    func run(_ arguments: [String], in box: Box) -> CommandResult {
        PropositionsCLI.run(["revise"] + arguments, workingDirectory: box.url)
    }

    static let main = "First.\nSecond.\nThird.\nFourth.\n"
    static let rows = [
        row("a", "main.tex:L1", "First."),
        row("old", "main.tex:L2", "Gone."),
        row("b", "main.tex:L2", "Second."),
        row("c", "main.tex:L3", "Third.", cites: ["old", "a"]),
        row("d", "main.tex:L4", "Fourth.", cites: ["gone2", "old"]),
        row("gone2", "main.tex:L9", "Also gone."),
        row("e", "main.tex:L1", "First.", cites: ["old"]),
    ]

    func ledger(_ rows: [String] = rows) throws -> (Box, URL) {
        let box = try Box()
        _ = try box.write(Self.main, to: "main.tex")
        return (box, try box.write(rows.map { $0 + "\n" }.joined(), to: "main.jsonl"))
    }

    static let retireArguments = ["retire", "--jsonl", "main.jsonl", "--retire", "old=b,c", "--retire", "gone2",
                                  "--since", "2026-11-21", "--reason", "revised draft"]

    // spec-example: revise / a retirement records what replaces it
    @Test func `Retiring writes the block with replaced_by, and nothing else changes`() throws {
        let (box, file) = try ledger()
        let before = try Data(contentsOf: file)
        let dry = run(Self.retireArguments, in: box)
        #expect(dry == CommandResult(stdout: ["retire old: replaced by b, c", "retire gone2: deleted, no replacement"], exitCode: 1))
        #expect(try Data(contentsOf: file) == before)
        let written = run(Self.retireArguments + ["--write"], in: box)
        #expect(written.exitCode == 0)
        let lines = String(decoding: try Data(contentsOf: file), as: UTF8.self).components(separatedBy: "\n")
        let block = #""retired": {"since": "2026-11-21", "mechanism": "removed", "match": "exact", "reason": "revised draft", "replaced_by": "#
        #expect(lines[1] == String(Self.rows[1].dropLast()) + ", " + block + #"["b", "c"]}}"#)
        #expect(lines[5] == String(Self.rows[5].dropLast()) + ", " + block + "[]}}")
        for index in [0, 2, 3, 4, 6] { #expect(lines[index] == Self.rows[index]) }
        #expect(run(["check", "--jsonl", "main.jsonl"], in: box)
            == CommandResult(stdout: ["1 replaced, 1 deleted, 0 without replaced_by, 0 problem(s)"], exitCode: 0))
    }

    @Test(.enabled(if: ParityTests.interpreter != nil))
    func `The Python validator reads the block the command writes`() throws {
        let (box, _) = try ledger()
        #expect(run(Self.retireArguments + ["--write"], in: box).exitCode == 0)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try #require(ParityTests.interpreter))
        process.arguments = [repositoryRoot.appendingPathComponent("plugins/propositions/scripts/validate-propositions.py").path,
                             "--jsonl", "main.jsonl", "--tex", "main.tex"]
        process.currentDirectoryURL = box.url
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()
        #expect(text.contains("R1-retired"))
        #expect(!text.contains("`retired`"))
    }

    @Test(arguments: [
        (["--retire", "nobody"], "no proposition nobody"),
        (["--retire", "old=nobody"], "no proposition nobody"),
        (["--retire", "old=old"], "cannot replace itself"),
        (["--retire", "old=gone2", "--retire", "gone2"], "is retired by this run"),
        (["--retire", "old", "--retire", "old"], "named twice"),
        (["--retire", "old", "--since", "2026-02-30"], "not a YYYY-MM-DD date"),
        (["--retire", "old", "--mechanism", "deleted"], "--mechanism is one of"),
        (["--retire", "old", "--reason", " "], "--reason is empty"),
    ])
    func `Refuses a retirement it cannot make, and writes nothing`(arguments: [String], message: String) throws {
        let (box, file) = try ledger()
        let before = try Data(contentsOf: file)
        var all = ["retire", "--jsonl", "main.jsonl", "--since", "2026-11-21", "--reason", "x"] + arguments + ["--write"]
        if arguments.contains("--since") { all.removeSubrange(3..<5) }
        if arguments.contains("--reason") { all.removeSubrange(all.firstIndex(of: "--reason")!..<(all.firstIndex(of: "--reason")! + 2)) }
        let result = run(all, in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr.last?.contains(message) == true)
        #expect(try Data(contentsOf: file) == before)
    }

    // spec-example: revise / a replaced_by that names no live proposition is reported
    @Test func `The check reports a replaced_by that names no live proposition`() throws {
        let retired = #""retired": {"since": "2026-11-21", "mechanism": "removed", "match": "exact", "reason": "x""#
        let (box, _) = try ledger([
            Self.row("a", "L1", "First."),
            "{\"id\": \"r1\", \"text\": \"x\", \(retired), \"replaced_by\": [\"a\"]}}",
            "{\"id\": \"r2\", \"text\": \"x\", \(retired), \"replaced_by\": [\"nobody\", \"r1\"]}}",
            "{\"id\": \"r3\", \"text\": \"x\", \(retired), \"replaced_by\": [\"r3\"]}}",
            "{\"id\": \"r4\", \"text\": \"x\", \(retired), \"replaced_by\": \"a\"}}",
            "{\"id\": \"r5\", \"text\": \"x\", \(retired)}}",
        ])
        #expect(run(["check", "--jsonl", "main.jsonl"], in: box) == CommandResult(stdout: [
            "line 3: r2 is replaced by nobody, which is no proposition of the ledger",
            "line 3: r2 is replaced by r1, which is retired",
            "line 4: r3 is listed as its own replacement",
            "line 5: the replaced_by of r4 is not a list",
            "1 replaced, 0 deleted, 1 without replaced_by, 4 problem(s)",
        ], exitCode: 1))
    }

    // spec-example: revise / the citations of a retired proposition follow its replacements
    @Test func `Redirecting follows the replacements, keeps only those before the citing proposition`() throws {
        let (box, file) = try ledger()
        #expect(run(Self.retireArguments + ["--write"], in: box).exitCode == 0)
        let lines = { String(decoding: try Data(contentsOf: file), as: UTF8.self).components(separatedBy: "\n") }
        let retiredLines = try lines()
        let result = run(["redirect", "--jsonl", "main.jsonl", "--tex", "main.tex", "--write"], in: box)
        #expect(result.stdout == [
            "drop c: c, which replaces old, does not come before it",
            "redirect c: old -> b",
            "drop d: gone2 is retired and has no replacement",
            "redirect d: old -> b, c",
            "drop e: b, which replaces old, does not come before it",
            "drop e: c, which replaces old, does not come before it",
            "written: main.jsonl",
        ])
        #expect(result.exitCode == 0)
        let after = try lines()
        #expect(after[3] == Self.row("c", "main.tex:L3", "Third.", cites: ["b", "a"]))
        #expect(after[4] == Self.row("d", "main.tex:L4", "Fourth.", cites: ["b", "c"]))
        #expect(after[6] == Self.row("e", "main.tex:L1", "First.", cites: []))
        for index in [0, 1, 2, 5] { #expect(after[index] == retiredLines[index]) }
        #expect(run(["redirect", "--jsonl", "main.jsonl", "--tex", "main.tex"], in: box)
            == CommandResult(stdout: ["nothing to change"], exitCode: 0))
    }

    @Test func `The commands state their interface`() throws {
        for (name, words) in [("retire", ["--retire", "--since", "--reason", "--mechanism", "--match", "--write"]),
                              ("check", ["--jsonl", "Exit codes"]), ("redirect", ["--tex", "--write", "Exit codes"])] {
            let help = PropositionsCLI.run(["revise", name, "--help"], workingDirectory: repositoryRoot)
            #expect(help.exitCode == 0)
            for word in words { #expect(help.stdout.joined(separator: "\n").contains(word)) }
        }
    }
}
