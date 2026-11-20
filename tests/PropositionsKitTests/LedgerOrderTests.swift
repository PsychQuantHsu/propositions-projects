import Foundation
import Testing
@testable import PropositionsKit

/// `propositions ledger-order`: the Swift port of reorder-ledger.py, and what it adds for a
/// manuscript of several files.
struct LedgerOrderTests {
    final class Box {
        let url: URL
        init() throws {
            url = FileManager.default.temporaryDirectory.appendingPathComponent("ledger-order-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        deinit { try? FileManager.default.removeItem(at: url) }

        func write(_ text: String, to name: String) throws -> URL {
            let file = url.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: file)
            return file
        }
    }

    static func line(_ id: String, _ location: String) -> String {
        #"{"id":"\#(id)","location":"\#(location)","text":"t"}"#
    }

    static func ids(_ data: Data) -> [String] {
        String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { line in
            (try? JSONValue.parse(String(line)))?.members?.last { $0.key == "id" }?.value.string
        }
    }

    func swift(_ arguments: [String], in box: Box) -> CommandResult {
        PropositionsCLI.run(["ledger-order"] + arguments, workingDirectory: box.url)
    }

    // MARK: the same as the Python tool, for a manuscript of one file

    /// Ledgers the two tools are put to, each as a dry run and with --write.
    static let parityLedgers: [(name: String, text: String)] = [
        ("two lines out of order", line("b", "main.tex:L9") + "\n" + line("a", "main.tex:L2") + "\n"),
        ("in order, two on one line", line("a", "main.tex:L2") + "\n" + line("b", "main.tex:L2") + "\n" + line("c", "L7") + "\n"),
        ("ties and moves", line("c", "L9") + "\n" + line("a", "L2") + "\n" + line("b", "L2") + "\n" + line("d", "L9") + "\n"),
        ("a range and no final newline", line("b", "main.tex:L9-L12") + "\n" + line("a", "main.tex:L2-L3")),
        ("lines that follow their predecessor",
         "// a comment at the head\n\n" + line("b", "L9") + "\n"
            + #"{"id":"r","retired":{"since":"2026-01-01","reason":"x"}}"# + "\n// about r\n\n"
            + line("a", "L2") + "\n" + "[1, 2]\n" + #"{"id":"n","location":"L1","retired":null}"# + "\n"),
        ("text outside ASCII", line("乙", "L9") + "\n" + #"{"id":"甲","location":"L2","text":"λ → ∞ “x”"}"# + "\n"),
        ("indented lines", "  " + line("b", "L9") + "  \n\t" + line("a", "L2") + "\n"),
        ("a key written twice", #"{"id":"b","location":"L1","location":"L9"}"# + "\n" + line("a", "L2") + "\n"),
        ("another file", line("a", "sections/a.tex:L2") + "\n"),
        ("a location that cannot be parsed", line("a", "nowhere") + "\n"),
        ("no location", #"{"id":"a"}"# + "\n"),
        ("a line that is not JSON", line("a", "L2") + "\n{oops\n"),
        ("an empty ledger", ""),
        ("only comments", "// nothing\n\n"),
        ("a comment whose slashes carry a combining mark", line("b", "L9") + "\n//\u{0301} note\n" + line("a", "L2") + "\n"),
        ("white space that Python strips and does not split at", "\u{A0}" + line("b", "L9") + "\u{3000}\n\u{2003}" + line("a", "L2") + "\n"),
    ]

    // spec-example: ledger-order / a manuscript of one file is ordered as the Python tool orders it
    @Test(.enabled(if: ParityTests.interpreter != nil), arguments: parityLedgers.map(\.name), [false, true])
    func `Prints, exits and writes as the Python tool does`(name: String, write: Bool) throws {
        let text = try #require(Self.parityLedgers.first { $0.name == name }).text
        let python = try Box(), ours = try Box()
        let theirs = try python.write(text, to: "main.jsonl")
        let mine = try ours.write(text, to: "main.jsonl")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: try #require(ParityTests.interpreter))
        process.arguments = [repositoryRoot.appendingPathComponent("plugins/propositions/scripts/reorder-ledger.py").path,
                             "--jsonl", "main.jsonl"] + (write ? ["--write"] : [])
        process.currentDirectoryURL = python.url
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        try process.run()
        let printed = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        process.waitUntilExit()

        let result = swift(["--jsonl", "main.jsonl"] + (write ? ["--write"] : []), in: ours)
        #expect(result.exitCode == process.terminationStatus)
        #expect(result.stdout == printed.split(separator: "\n").map(String.init))
        #expect(try Data(contentsOf: mine) == Data(contentsOf: theirs))
        #expect(try FileManager.default.contentsOfDirectory(atPath: ours.url.path) == ["main.jsonl"])
        if result.exitCode == 2 { #expect(result.stderr.count == 1 && result.stderr[0].hasPrefix("error: ")) }
    }

    // spec-example: ledger-order / a dry run changes nothing
    @Test func `A dry run reports the lines that would move and changes nothing`() throws {
        let box = try Box()
        let text = Self.line("b", "main.tex:L9") + "\n" + Self.line("a", "main.tex:L2") + "\n"
        let ledger = try box.write(text, to: "main.jsonl")
        let result = swift(["--jsonl", "main.jsonl"], in: box)
        #expect(result == CommandResult(stdout: ["2 line(s) move"], exitCode: 1))
        #expect(try Data(contentsOf: ledger) == Data(text.utf8))
    }

    // spec-example: ledger-order / writing moves whole lines and keeps the file's permissions
    @Test func `Writing moves whole lines, keeps the permissions and leaves no other file`() throws {
        let box = try Box()
        let b = "  " + Self.line("b", "L9") + " \r\n", r = #"{"id":"r","retired":{"reason":"x"}}"# + "\n", a = Self.line("a", "L2") + "\r\n"
        let ledger = try box.write(b + r + a, to: "main.jsonl")
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: ledger.path)
        let result = swift(["--jsonl", "main.jsonl", "--write"], in: box)
        #expect(result == CommandResult(stdout: ["3 line(s) move", "written: main.jsonl"], exitCode: 0))
        // Each line with the bytes it had, the line endings included.
        #expect(try Data(contentsOf: ledger) == Data((a + b + r).utf8))
        let mode = try #require(FileManager.default.attributesOfItem(atPath: ledger.path)[.posixPermissions] as? NSNumber)
        #expect(mode.intValue == 0o640)
        #expect(try FileManager.default.contentsOfDirectory(atPath: box.url.path) == ["main.jsonl"])
        #expect(swift(["--jsonl", "main.jsonl"], in: box) == CommandResult(stdout: ["already in reading order"], exitCode: 0))
    }

    // MARK: a manuscript of several files

    static let mainFile = "Intro line 1.\n\\input{sections/a}\nMiddle line 3.\n\\include{sections/b}\nEnd line 5.\n"

    func manuscript(_ ledger: String) throws -> (Box, URL) {
        let box = try Box()
        _ = try box.write(Self.mainFile, to: "main.tex")
        _ = try box.write("A1.\nA2.\n\\input{sections/deep}\nA4.\n", to: "sections/a.tex")
        _ = try box.write("D1.\n", to: "sections/deep.tex")
        _ = try box.write("B1.\nB2.\n", to: "sections/b.tex")
        return (box, try box.write(ledger, to: "p/main.jsonl"))
    }

    // spec-example: ledger-order / a manuscript of several files is ordered through its input tree
    @Test func `Orders a manuscript of several files through its input tree`() throws {
        // Reading order: main 1, a 1-2, deep 1, a 4, main 3, b 1-2, main 5.
        let inOrder = [("m1", "main.tex:L1"), ("a1", "sections/a.tex:L1"), ("d1", "sections/deep.tex:L1"),
                       ("a4", "sections/a.tex:L4"), ("m3", "L3"), ("b2", "sections/b.tex:L2"), ("m5", "main.tex:L5")]
        let shuffled = [inOrder[6], inOrder[3], inOrder[0], inOrder[5], inOrder[2], inOrder[4], inOrder[1]]
        let (box, ledger) = try manuscript(shuffled.map { Self.line($0.0, $0.1) + "\n" }.joined())
        let before = try Data(contentsOf: ledger)
        let dry = swift(["--jsonl", "p/main.jsonl", "--tex", "main.tex"], in: box)
        #expect(dry == CommandResult(stdout: ["7 line(s) move"], exitCode: 1))
        #expect(try Data(contentsOf: ledger) == before)
        let written = swift(["--jsonl", "p/main.jsonl", "--tex", "main.tex", "--write"], in: box)
        #expect(written == CommandResult(stdout: ["7 line(s) move", "written: p/main.jsonl"], exitCode: 0))
        #expect(Self.ids(try Data(contentsOf: ledger)) == inOrder.map(\.0))
        #expect(swift(["--jsonl", "p/main.jsonl", "--tex", "main.tex"], in: box)
            == CommandResult(stdout: ["already in reading order"], exitCode: 0))
    }

    // spec-example: ledger-order / propositions that start on the same line of the same file are reported
    @Test func `Reports the places that hold several propositions, by file and line`() throws {
        let (box, _) = try manuscript([("x", "sections/a.tex:L2"), ("y", "sections/a.tex:L2-L4"), ("z", "sections/b.tex:L2"),
                                       ("w", "main.tex:L5"), ("v", "L5")].map { Self.line($0.0, $0.1) + "\n" }.joined())
        let result = swift(["--jsonl", "p/main.jsonl", "--tex", "main.tex"], in: box)
        #expect(result == CommandResult(stdout: [
            "2 place(s) hold several propositions on the same line, check their order: sections/a.tex:2, main.tex:5",
            "already in reading order",
        ], exitCode: 0))
    }

    // spec-example: ledger-order / what cannot be ordered is refused and nothing is written
    @Test(arguments: [
        (["--jsonl", "p/main.jsonl"], [("a", "sections/a.tex:L1")], "names another file; pass --tex"),
        (["--jsonl", "p/main.jsonl", "--tex", "main.tex"], [("a", "sections/zz.tex:L1")], "not in the input tree of main.tex"),
        (["--jsonl", "p/main.jsonl", "--tex", "main.tex"], [("a", "/abs/a.tex:L1")], "not in the input tree"),
        (["--jsonl", "p/main.jsonl", "--tex", "none.tex"], [("a", "L1")], "cannot read the main file none.tex"),
        (["--jsonl", "p/none.jsonl", "--tex", "main.tex"], [("a", "L1")], "p/none.jsonl"),
        (["--jsonl", "p", "--tex", "main.tex"], [("a", "L1")], "ledger not found, or not a regular file that can be read: p"),
    ] as [([String], [(String, String)], String)])
    func `Refuses what it cannot order, and writes nothing`(
        arguments: [String], rows: [(String, String)], message: String
    ) throws {
        let text = rows.map { Self.line($0.0, $0.1) + "\n" }.joined() + Self.line("b", "L1") + "\n"
        let (box, ledger) = try manuscript(text)
        let result = swift(arguments + ["--write"], in: box)
        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.count == 1)
        #expect(result.stderr.first?.hasPrefix("error: ") == true)
        #expect(result.stderr.first?.contains(message) == true)
        #expect(try Data(contentsOf: ledger) == Data(text.utf8))
        #expect(try FileManager.default.contentsOfDirectory(atPath: ledger.deletingLastPathComponent().path) == ["main.jsonl"])
        // Nothing beside the directory either, where a temporary file for `--jsonl p` would go.
        #expect(try FileManager.default.contentsOfDirectory(atPath: box.url.path).sorted() == ["main.tex", "p", "sections"])
    }

    // spec-example: ledger-order / a ledger that is a link, or that changed, is not replaced
    @Test func `Does not replace a ledger that is a link`() throws {
        let box = try Box()
        let text = Self.line("b", "L9") + "\n" + Self.line("a", "L2") + "\n"
        let real = try box.write(text, to: "real/main.jsonl")
        try FileManager.default.createSymbolicLink(at: box.url.appendingPathComponent("main.jsonl"), withDestinationURL: real)
        #expect(swift(["--jsonl", "main.jsonl"], in: box) == CommandResult(stdout: ["2 line(s) move"], exitCode: 1))
        let result = swift(["--jsonl", "main.jsonl", "--write"], in: box)
        #expect(result.exitCode == 2)
        #expect(result.stdout == ["2 line(s) move"])
        #expect(result.stderr.count == 1 && result.stderr[0].contains("named through a link"))
        #expect(try Data(contentsOf: real) == Data(text.utf8))
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: box.url.appendingPathComponent("main.jsonl").path) == real.path)
        #expect(try FileManager.default.contentsOfDirectory(atPath: box.url.path).sorted() == ["main.jsonl", "real"])
    }

    /// What was done to the ledger between reading it and writing.
    enum Change: CaseIterable { case moreBytes, sameBytesNewFile, permissions, link }

    @Test(arguments: Change.allCases)
    func `Does not replace a ledger that changed after it was read`(change: Change) throws {
        let box = try Box()
        let text = Self.line("b", "L9") + "\n" + Self.line("a", "L2") + "\n"
        let ledger = try box.write(text, to: "main.jsonl")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: ledger.path)
        let read = try #require(LedgerOrder.read(ledger))
        let plan = try LedgerOrder.plan(read.data, order: nil)
        var expected = Data(text.utf8)
        switch change {
        case .moreBytes:
            expected.append(Data((Self.line("c", "L1") + "\n").utf8))
            try expected.write(to: ledger)
        case .sameBytesNewFile:
            // What an editor's atomic save does: another file with the same bytes under the name.
            try FileManager.default.moveItem(at: ledger, to: box.url.appendingPathComponent("old"))
            try Data(text.utf8).write(to: ledger)
            try FileManager.default.removeItem(at: box.url.appendingPathComponent("old"))
        case .permissions:
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: ledger.path)
        case .link:
            try FileManager.default.moveItem(at: ledger, to: box.url.appendingPathComponent("real"))
            try FileManager.default.createSymbolicLink(at: ledger, withDestinationURL: box.url.appendingPathComponent("real"))
        }
        #expect(throws: LedgerOrder.Failure.self) {
            _ = try LedgerOrder.write(plan.content, to: ledger, replacing: read)
        }
        #expect(try Data(contentsOf: ledger) == expected)
        let names = try FileManager.default.contentsOfDirectory(atPath: box.url.path).sorted()
        #expect(names == (change == .link ? ["main.jsonl", "real"] : ["main.jsonl"]))
        if change == .permissions {
            let mode = try #require(FileManager.default.attributesOfItem(atPath: ledger.path)[.posixPermissions] as? NSNumber)
            #expect(mode.intValue == 0o600)
        }
        if change == .link {
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: ledger.path).hasSuffix("/real"))
        }
    }

    @Test func `An unchanged ledger is replaced, and the directory is synced`() throws {
        let box = try Box()
        let ledger = try box.write(Self.line("b", "L9") + "\n" + Self.line("a", "L2") + "\n", to: "main.jsonl")
        let read = try #require(LedgerOrder.read(ledger))
        let plan = try LedgerOrder.plan(read.data, order: nil)
        #expect(try LedgerOrder.write(plan.content, to: ledger, replacing: read))
        #expect(Self.ids(try Data(contentsOf: ledger)) == ["a", "b"])
    }

    @Test func `A pipe where the ledger or the main file is named is refused, not read`() throws {
        let box = try Box()
        _ = try box.write(Self.line("a", "L1") + "\n", to: "main.jsonl")
        #expect(mkfifo(box.url.appendingPathComponent("pipe").path, 0o644) == 0)
        #expect(swift(["--jsonl", "pipe"], in: box).exitCode == 2)
        #expect(swift(["--jsonl", "main.jsonl", "--tex", "pipe"], in: box).exitCode == 2)
    }

    @Test func `The name of the main file is shown with its control characters escaped`() throws {
        let box = try Box()
        _ = try box.write("Text.\n", to: "ma\nin.tex")
        _ = try box.write(Self.line("a", "other.tex:L1") + "\n", to: "main.jsonl")
        let result = swift(["--jsonl", "main.jsonl", "--tex", "ma\nin.tex"], in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr.count == 1 && !result.stderr[0].contains("\n"))
    }

    @Test func `A path is shown with its control characters escaped`() throws {
        let box = try Box()
        let result = swift(["--jsonl", "no\nfile.jsonl"], in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr.count == 1 && !result.stderr[0].contains("\n"))
    }

    @Test func `An input tree that cannot be read is refused`() throws {
        let box = try Box()
        _ = try box.write("\\input{missing}\n", to: "main.tex")
        _ = try box.write(Self.line("a", "L1") + "\n", to: "main.jsonl")
        let result = swift(["--jsonl", "main.jsonl", "--tex", "main.tex"], in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr.count == 1)
    }

    @Test func `A ledger that is not UTF-8 is refused`() throws {
        let box = try Box()
        try Data([0x7B, 0xFF, 0x7D, 0x0A]).write(to: box.url.appendingPathComponent("main.jsonl"))
        let result = swift(["--jsonl", "main.jsonl"], in: box)
        #expect(result.exitCode == 2)
        #expect(result.stderr == ["error: line 1 of the ledger is not UTF-8"])
    }

    @Test func `The command states its interface`() throws {
        let help = PropositionsCLI.run(["ledger-order", "--help"], workingDirectory: repositoryRoot)
        #expect(help.exitCode == 0)
        let text = help.stdout.joined(separator: "\n")
        for word in ["--jsonl", "--tex", "--write", "Exit codes"] { #expect(text.contains(word)) }
        #expect(PropositionsCLI.run(["ledger-order"], workingDirectory: repositoryRoot).exitCode == 2)
        #expect(PropositionsCLI.run(["--help"], workingDirectory: repositoryRoot).stdout.joined().contains("ledger-order"))
    }
}
