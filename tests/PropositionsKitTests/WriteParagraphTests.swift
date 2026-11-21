import Foundation
import Testing
@testable import PropositionsKit

/// `propositions write prepare|check|commit` (issue 49), on the structure fixture.
struct WriteParagraphTests {
    typealias Box = LedgerOrderTests.Box

    func setUp() throws -> Box {
        let box = try Box()
        let fixture = repositoryRoot.appendingPathComponent("tests/fixtures/structure")
        _ = try box.write(String(contentsOf: fixture.appendingPathComponent("main.tex"), encoding: .utf8), to: "paper/main.tex")
        for name in ["main.jsonl", "_meta.json", "structure.json", "discourse.jsonl"] {
            _ = try box.write(String(contentsOf: fixture.appendingPathComponent(name), encoding: .utf8), to: "paper/propositions/\(name)")
        }
        return box
    }

    func run(_ arguments: [String], in box: Box) -> CommandResult {
        PropositionsCLI.run(["write"] + arguments, workingDirectory: box.url)
    }

    static let prepare = ["prepare", "--jsonl", "paper/propositions/main.jsonl", "--tex", "paper/main.tex",
                          "--structure", "paper/propositions/structure.json", "--discourse", "paper/propositions/discourse.jsonl",
                          "--stage", "stage"]

    static let newProposition = #"{"id": "019a3c5e-7a00-7000-8000-00000000000d", "text": "The effect was large.", "location": "main.tex:L32", "claim_type": "claim", "evidence_class": "external", "asserts": ["x"], "cites": []}"#

    /// Makes the paragraph in the staged copies, as the skill does.
    func draft(_ box: Box, text: String = "The effect was large, {PENDING: the effect size}.",
               rows: [(String, String)] = [("main.jsonl", Self.newProposition), ("discourse.jsonl", #"{"prop_id": "019a3c5e-7a00-7000-8000-00000000000d"}"#)]) throws {
        let staged = box.url.appendingPathComponent("stage/manuscript/main.tex")
        var lines = try String(contentsOf: staged, encoding: .utf8).components(separatedBy: "\n")
        lines.insert(contentsOf: ["", text], at: 30)
        try lines.joined(separator: "\n").write(to: staged, atomically: true, encoding: .utf8)
        for (name, line) in rows {
            let url = box.url.appendingPathComponent("stage/ledger/\(name)")
            let handle = try FileHandle(forWritingTo: url)
            handle.seekToEndOfFile()
            handle.write(Data((line + "\n").utf8))
            try handle.close()
        }
    }

    // spec-example: write / a paragraph is written after the last proposition behind one confirmation
    @Test func `Prepare, draft in the copies, check and commit`() throws {
        let box = try setUp()
        let prepared = run(Self.prepare, in: box)
        #expect(prepared.exitCode == 0)
        #expect(prepared.stdout.first == "the new paragraph goes after line 30 of main.tex")
        #expect(run(["check", "--stage", "stage"], in: box).exitCode == 1)
        try draft(box)
        #expect(run(["check", "--stage", "stage"], in: box)
            == CommandResult(stdout: ["2 line(s) added, 1 new proposition(s), 1 new record(s), 1 placeholder line(s): 32"], exitCode: 0))
        let committed = run(["commit", "--stage", "stage"], in: box)
        #expect(committed.exitCode == 0)
        #expect(committed.stdout.count == 5)
        for (original, staged) in [("paper/main.tex", "stage/manuscript/main.tex"), ("paper/propositions/main.jsonl", "stage/ledger/main.jsonl"),
                                   ("paper/propositions/discourse.jsonl", "stage/ledger/discourse.jsonl")] {
            #expect(try Data(contentsOf: box.url.appendingPathComponent(original)) == Data(contentsOf: box.url.appendingPathComponent(staged)))
        }
        let fixture = repositoryRoot.appendingPathComponent("tests/fixtures/structure/main.jsonl")
        #expect(try Data(contentsOf: box.url.appendingPathComponent("stage/backup/ledger")) == Data(contentsOf: fixture))
    }

    // spec-example: write / a file changed after prepare is not overwritten
    @Test func `Commit writes nothing when a file changed after prepare`() throws {
        let box = try setUp()
        #expect(run(Self.prepare, in: box).exitCode == 0)
        try draft(box)
        let main = box.url.appendingPathComponent("paper/main.tex")
        let edited = try String(contentsOf: main, encoding: .utf8) + "% saved by the editor\n"
        try edited.write(to: main, atomically: true, encoding: .utf8)
        let ledger = try Data(contentsOf: box.url.appendingPathComponent("paper/propositions/main.jsonl"))
        let result = run(["commit", "--stage", "stage"], in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr.first?.contains("changed after prepare") == true)
        #expect(try String(contentsOf: main, encoding: .utf8) == edited)
        #expect(try Data(contentsOf: box.url.appendingPathComponent("paper/propositions/main.jsonl")) == ledger)
    }

    // spec-example: write / copies that change more than a new paragraph are refused
    @Test func `Check refuses copies that change more than a new paragraph`() throws {
        let box = try setUp()
        #expect(run(Self.prepare, in: box).exitCode == 0)
        try draft(box)
        let staged = box.url.appendingPathComponent("stage/manuscript/main.tex")
        let text = try String(contentsOf: staged, encoding: .utf8).replacingOccurrences(of: "Spaced review", with: "Spacing")
        try text.write(to: staged, atomically: true, encoding: .utf8)
        let ledger = box.url.appendingPathComponent("stage/ledger/main.jsonl")
        let rows = try String(contentsOf: ledger, encoding: .utf8)
        try rows.replacingOccurrences(of: "\"claim_type\": \"claim\"", with: "\"claim_type\": \"definition\"").write(to: ledger, atomically: true, encoding: .utf8)
        let result = run(["check", "--stage", "stage"], in: box)
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains { $0.contains("is not the file with lines added after line 30") })
        #expect(result.stdout.contains { $0.contains("the staged ledger is not the ledger with lines added at its end") })
        #expect(run(["commit", "--stage", "stage"], in: box).exitCode == 2)
    }

    // MARK: the first review

    func edit(_ box: Box, _ path: String, _ change: (String) -> String) throws {
        let url = box.url.appendingPathComponent(path)
        try change(try String(contentsOf: url, encoding: .utf8)).write(to: url, atomically: true, encoding: .utf8)
    }

    @Test func `Check refuses two paragraphs, a byte changed in an earlier line, and a structure that loses a key`() throws {
        let box = try setUp()
        #expect(run(Self.prepare, in: box).exitCode == 0)
        try draft(box, text: "One.\n\nTwo.")
        try edit(box, "stage/ledger/structure.json") { text in
            let value = try! JSONValue.parse(text)
            guard case .object(let members) = value else { return text }
            return Revise.dumps(.object(Array(members.dropFirst())))
        }
        var result = run(["check", "--stage", "stage"], in: box)
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains { $0.contains("hold 2 paragraphs, not one") })
        #expect(result.stdout.contains { $0.contains("the staged structure drops or changes something") })
        let other = try setUp()
        #expect(run(Self.prepare, in: other).exitCode == 0)
        try draft(other)
        // The same text in another Unicode form: equal as strings, not as bytes.
        try edit(other, "stage/manuscript/main.tex") { $0.replacingOccurrences(of: "Spaced", with: "Spaced\u{301}") }
        result = run(["check", "--stage", "stage"], in: other)
        #expect(result.stdout.contains { $0.contains("every other byte as it was") })
    }

    @Test func `A copy of a file that is not written back may not be changed`() throws {
        let box = try setUp()
        #expect(run(Self.prepare, in: box).exitCode == 0)
        try draft(box)
        try edit(box, "stage/ledger/_meta.json") { $0 + " " }
        let result = run(["check", "--stage", "stage"], in: box)
        #expect(result.exitCode == 1)
        #expect(result.stdout.contains { $0.contains("only the four files are written") })
    }

    @Test func `A ledger without a last line ending gets new lines`() throws {
        let box = try setUp()
        try edit(box, "paper/propositions/main.jsonl") { String($0.dropLast()) }
        #expect(run(Self.prepare, in: box).exitCode == 0)
        let url = box.url.appendingPathComponent("stage/ledger/main.jsonl")
        try edit(box, "stage/ledger/main.jsonl") { $0 + "\n" + Self.newProposition + "\n" }
        _ = url
        try draft(box, rows: [("discourse.jsonl", #"{"prop_id": "019a3c5e-7a00-7000-8000-00000000000d"}"#)])
        #expect(run(["check", "--stage", "stage"], in: box).exitCode == 0)
    }

    // spec-example: write / a staged file that is missing writes nothing
    @Test func `Commit writes nothing when a staged file is missing, and refuses a backup that exists`() throws {
        let box = try setUp()
        #expect(run(Self.prepare, in: box).exitCode == 0)
        try draft(box)
        let structure = box.url.appendingPathComponent("stage/ledger/structure.json")
        let kept = try Data(contentsOf: structure)
        try FileManager.default.removeItem(at: structure)
        let main = try Data(contentsOf: box.url.appendingPathComponent("paper/main.tex"))
        #expect(run(["commit", "--stage", "stage"], in: box).exitCode == 2)
        #expect(try Data(contentsOf: box.url.appendingPathComponent("paper/main.tex")) == main)
        try kept.write(to: structure)
        try FileManager.default.createDirectory(at: box.url.appendingPathComponent("stage/backup"), withIntermediateDirectories: false)
        let result = run(["commit", "--stage", "stage"], in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr.first?.contains("exists already") == true)
        #expect(try Data(contentsOf: box.url.appendingPathComponent("paper/main.tex")) == main)
    }

    @Test func `Prepare refuses two roles that are one file`() throws {
        let box = try setUp()
        var arguments = Self.prepare
        arguments[arguments.firstIndex(of: "paper/propositions/discourse.jsonl")!] = "paper/propositions/structure.json"
        let result = run(arguments, in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr.first?.contains("three different file names") == true)
    }

    @Test func `Prepare refuses a staging directory that is not empty`() throws {
        let box = try setUp()
        _ = try box.write("x", to: "stage/other")
        let result = run(Self.prepare, in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr.first?.contains("is not empty") == true)
    }

    @Test(.enabled(if: ParityTests.interpreter != nil))
    func `The validator passes on the staged copies`() throws {
        let box = try setUp()
        #expect(run(Self.prepare, in: box).exitCode == 0)
        try draft(box, text: "The effect was large.")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try #require(ParityTests.interpreter))
        process.arguments = [repositoryRoot.appendingPathComponent("plugins/propositions/scripts/validate-propositions.py").path,
                             "--jsonl", "stage/ledger/main.jsonl", "--meta", "stage/ledger/_meta.json", "--tex", "stage/manuscript/main.tex"]
        process.currentDirectoryURL = box.url
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    @Test func `The commands state their interface`() throws {
        for name in ["prepare", "check", "commit"] {
            let help = PropositionsCLI.run(["write", name, "--help"], workingDirectory: repositoryRoot)
            #expect(help.exitCode == 0)
            #expect(help.stdout.joined(separator: "\n").contains("Exit codes"))
        }
    }
}
