import Foundation
import Testing
@testable import PropositionsKit

/// `propositions paragraphs`: the Swift port of derive-paragraphs.py, and what it adds for a
/// manuscript of several files.
struct ParagraphsTests {
    typealias Box = LedgerOrderTests.Box

    static func line(_ id: String, _ location: String) -> String { LedgerOrderTests.line(id, location) }

    func swift(_ arguments: [String], in box: Box) -> CommandResult {
        PropositionsCLI.run(["paragraphs"] + arguments, workingDirectory: box.url)
    }

    /// The whole list that was printed: every entry has to be an object with exactly `id` and
    /// `first_prop`, both strings, or the test that asks fails.
    static func plan(_ result: CommandResult) throws -> [[String]] {
        let value = try JSONValue.parse(result.stdout.joined(separator: "\n"))
        return try #require(value.array).map { entry in
            let members = try #require(entry.members)
            try #require(members.map(\.key) == ["id", "first_prop"])
            return try members.map { try #require($0.value.string) }
        }
    }

    // MARK: the same as the Python tool, for a manuscript of one file

    struct Case {
        let name: String
        let tex: String
        let ledger: String
        var structure: String?
    }

    static let tex = "One.\nTwo.\n\nFour.\n   \nSix.\nSeven.\n\t\n\nTen.\n"

    static let cases: [Case] = [
        Case(name: "blank lines separate paragraphs", tex: tex,
             ledger: [("a", "L1"), ("b", "L2"), ("c", "main.tex:L4"), ("d", "L6-L7"), ("e", "L7"), ("f", "L10")]
                .map { line($0.0, $0.1) + "\n" }.joined()),
        Case(name: "paragraphs without a proposition are skipped", tex: tex,
             ledger: line("a", "L1") + "\n" + line("f", "L10") + "\n"),
        Case(name: "a section start splits a paragraph", tex: tex,
             ledger: [("a", "L1"), ("b", "L2"), ("d", "L6"), ("e", "L7")].map { line($0.0, $0.1) + "\n" }.joined(),
             structure: #"{"sections":[{"id":"s1","first_prop":"a"},{"id":"s2","first_prop":"b"},{"id":"s3","first_prop":"e"},"x",{"id":"s4"}]}"#),
        Case(name: "retired propositions and empty lines are passed over", tex: tex,
             ledger: line("a", "L1") + "\n\n" + #"{"id":"r","location":"L4","retired":{"reason":"x"}}"# + "\n  \n" + line("b", "L2") + "\n[1]\n"),
        Case(name: "the ledger's order is kept, not the reading order", tex: tex,
             ledger: [("f", "L10"), ("a", "L1"), ("d", "L6"), ("b", "L2")].map { line($0.0, $0.1) + "\n" }.joined()),
        Case(name: "ids that need escaping", tex: tex,
             // Written as JSON escapes: a quote, a backslash, a tab, U+0001, U+2028 and U+007F.
             ledger: "{" + #""id":"q\"\\\t"# + "\\u" + "0001é" + "\\u" + "2028" + "\\u" + #"007f","location":"L1"}"# + "\n"),
        Case(name: "no proposition", tex: tex, ledger: "\n"),
        Case(name: "a structure without sections", tex: tex, ledger: line("a", "L1") + "\n", structure: "{}"),
        Case(name: "carriage returns in the manuscript", tex: "One.\r\nTwo.\r\n\r\nFour.\r\n",
             ledger: line("a", "L2") + "\n" + line("b", "L4") + "\n"),
        Case(name: "an input of the main file that leads nowhere", tex: "One.\n\\IfFileExists{draft.tex}{\\input{draft}}{}\n\nFour.\n",
             ledger: line("a", "L1") + "\n" + line("b", "L2") + "\n" + line("c", "L4") + "\n"),
        Case(name: "a row that is white space outside JSON's only", tex: tex, ledger: line("a", "L1") + "\n\u{A0}\n" + line("b", "L4") + "\n"),
        Case(name: "a row with white space outside JSON's before the object", tex: tex, ledger: "\u{A0}" + line("a", "L1") + "\n"),
        // The id with the composed letter is second in its run; only the other spelling starts a
        // section. Compared by code points it does not split the run.
        Case(name: "a section start in another spelling of the same letters", tex: tex,
             ledger: line("x", "L1") + "\n" + line("caf\u{E9}", "L2") + "\n", structure: "{\"sections\":[{\"first_prop\":\"cafe\u{301}\"}]}"),
        Case(name: "a ledger that starts with a byte-order mark", tex: tex, ledger: "\u{FEFF}" + line("a", "L1") + "\n"),
        Case(name: "a structure sidecar that starts with a byte-order mark", tex: tex, ledger: line("a", "L1") + "\n", structure: "\u{FEFF}{}"),
        Case(name: "the main file written with a dot before it", tex: tex, ledger: line("a", "./main.tex:L1") + "\n"),
        Case(name: "sections that is an object", tex: tex, ledger: line("a", "L1") + "\n" + line("b", "L2") + "\n", structure: #"{"sections":{"first_prop":"b"}}"#),
        Case(name: "a location in another file", tex: tex, ledger: line("a", "sections/a.tex:L1") + "\n"),
        Case(name: "a location from the root of the file system", tex: tex, ledger: line("a", "/main.tex:L1") + "\n"),
        Case(name: "a location on a blank line", tex: tex, ledger: line("a", "L3") + "\n"),
        Case(name: "a location past the end", tex: tex, ledger: line("a", "L99") + "\n"),
        Case(name: "a location that cannot be parsed", tex: tex, ledger: line("a", "nowhere") + "\n"),
        Case(name: "no location", tex: tex, ledger: #"{"id":"a"}"# + "\n"),
        Case(name: "a line that is not JSON", tex: tex, ledger: line("a", "L1") + "\n{oops\n"),
        Case(name: "a structure that is not JSON", tex: tex, ledger: line("a", "L1") + "\n", structure: "{oops"),
    ]

    // spec-example: paragraph-plan / a manuscript of one file gets the plan the Python tool gives
    @Test(arguments: cases.map(\.name))
    func `Prints and exits as the Python tool did`(name: String) throws {
        let (box, arguments) = try setUp(name)
        let recorded = try RetiredPython.load(tool: "derive-paragraphs", case: name)
        let result = swift(arguments, in: box)
        #expect(result.exitCode == recorded.exit)
        // Byte for byte, the final newline included: the executable prints each line with one.
        #expect(Data(result.stdout.map { $0 + "\n" }.joined().utf8) == recorded.output)
        if result.exitCode == 2 {
            #expect(result.stdout.isEmpty)
            #expect(result.stderr.count == 1 && result.stderr[0].hasPrefix("error: "))
        }
    }

    func setUp(_ name: String) throws -> (Box, [String]) {
        let item = try #require(Self.cases.first { $0.name == name })
        let box = try Box()
        _ = try box.write(item.tex, to: "main.tex")
        _ = try box.write(item.ledger, to: "main.jsonl")
        var arguments = ["--jsonl", "main.jsonl", "--tex", "main.tex"]
        if let structure = item.structure {
            _ = try box.write(structure, to: "structure.json")
            arguments += ["--structure", "structure.json"]
        }
        return (box, arguments)
    }

    // spec-example: paragraph-plan / blank lines separate paragraphs
    @Test func `Blank lines separate paragraphs, and a section start splits one`() throws {
        let box = try Box()
        _ = try box.write(Self.tex, to: "main.tex")
        _ = try box.write([("a", "L1"), ("b", "L2"), ("c", "L4"), ("d", "L6"), ("e", "L7")].map { Self.line($0.0, $0.1) + "\n" }.joined(),
                          to: "main.jsonl")
        let plain = swift(["--jsonl", "main.jsonl", "--tex", "main.tex"], in: box)
        #expect(plain.stdout == ["[", " {", "  \"id\": \"p-1\",", "  \"first_prop\": \"a\"", " },", " {", "  \"id\": \"p-2\",",
                                 "  \"first_prop\": \"c\"", " },", " {", "  \"id\": \"p-3\",", "  \"first_prop\": \"d\"", " }", "]"])
        _ = try box.write(#"{"sections":[{"first_prop":"a"},{"first_prop":"e"}]}"#, to: "structure.json")
        let split = swift(["--jsonl", "main.jsonl", "--tex", "main.tex", "--structure", "structure.json"], in: box)
        #expect(try Self.plan(split) == [["p-1", "a"], ["p-2", "c"], ["p-3", "d"], ["p-4", "e"]])
    }

    // MARK: a manuscript of several files

    func manuscript(_ ledger: String) throws -> Box {
        let box = try Box()
        _ = try box.write("Intro 1.\n\\input{sections/a}\nMiddle 3.\nMiddle 4.\n\n\\include{sections/b}\n", to: "main.tex")
        _ = try box.write("A1.\nA2.\n\nA4.\n", to: "sections/a.tex")
        _ = try box.write("B1.\n\nB3.\n", to: "sections/b.tex")
        _ = try box.write("Unused.\n", to: "sections/unused.tex")
        _ = try box.write(ledger, to: "p/main.jsonl")
        return box
    }

    // spec-example: paragraph-plan / a manuscript of several files gets a plan
    @Test func `Derives the plan of a manuscript of several files`() throws {
        // main 1-4 is one run; a has two; b has two. Lines 1 of main, of a and of b are three paragraphs.
        let rows = [("m1", "main.tex:L1"), ("a1", "sections/a.tex:L1"), ("a2", "./sections/a.tex:L2"), ("a4", "sections/a.tex:L4"),
                    ("m3", "L3"), ("m4", "L4"), ("b1", "sections/b.tex:L1"), ("b3", "sections/b.tex:L3")]
        let box = try manuscript(rows.map { Self.line($0.0, $0.1) + "\n" }.joined())
        let result = swift(["--jsonl", "p/main.jsonl", "--tex", "main.tex"], in: box)
        #expect(result.exitCode == 0)
        #expect(result.stderr.isEmpty)
        // a1 leaves main's run; m3 comes back to the run m1 was in, and still starts a paragraph,
        // because the proposition before it was in another file.
        #expect(try Self.plan(result) == [["p-1", "m1"], ["p-2", "a1"], ["p-3", "a4"], ["p-4", "m3"], ["p-5", "b1"], ["p-6", "b3"]])
    }

    // spec-example: paragraph-plan / a location outside the input tree is refused
    @Test(arguments: [
        ("sections/unused.tex:L1", "not in the manuscript's input tree"),
        ("sections/none.tex:L1", "not in the manuscript's input tree"),
        ("/abs/a.tex:L1", "not in the manuscript's input tree"),
        ("/main.tex:L1", "not in the manuscript's input tree"),
        ("/sections/a.tex:L1", "not in the manuscript's input tree"),
        ("sections/a.tex:L3", "not inside a TeX paragraph"),
        ("sections/b.tex:L9", "not inside a TeX paragraph"),
    ])
    func `Refuses a location it cannot place`(location: String, message: String) throws {
        let box = try manuscript(Self.line("a", "L1") + "\n" + Self.line("x", location) + "\n")
        let result = swift(["--jsonl", "p/main.jsonl", "--tex", "main.tex"], in: box)
        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.count == 1)
        #expect(result.stderr.first?.hasPrefix("error: ") == true)
        #expect(result.stderr.first?.contains(message) == true)
    }

    @Test(arguments: [
        (["--jsonl", "p/none.jsonl", "--tex", "main.tex"], "ledger not found"),
        (["--jsonl", "p/main.jsonl", "--tex", "none.tex"], "TeX file not found"),
        (["--jsonl", "p/main.jsonl", "--tex", "sections"], "TeX file not found"),
        (["--jsonl", "p/main.jsonl", "--tex", "main.tex", "--structure", "none.json"], "structure sidecar not found"),
    ])
    func `Refuses an input that is not there`(arguments: [String], message: String) throws {
        let box = try manuscript(Self.line("a", "L1") + "\n")
        let result = swift(arguments, in: box)
        #expect(result.exitCode == 2)
        #expect(result.stdout.isEmpty)
        #expect(result.stderr.count == 1 && result.stderr[0].contains(message))
    }

    @Test func `A comment line of the ledger is passed over`() throws {
        let box = try manuscript("// a note\n" + Self.line("a", "L1") + "\n")
        #expect(try Self.plan(swift(["--jsonl", "p/main.jsonl", "--tex", "main.tex"], in: box)) == [["p-1", "a"]])
    }

    @Test func `The command states its interface`() throws {
        let help = PropositionsCLI.run(["paragraphs", "--help"], workingDirectory: repositoryRoot)
        #expect(help.exitCode == 0)
        let text = help.stdout.joined(separator: "\n")
        for word in ["--jsonl", "--tex", "--structure", "Exit codes"] { #expect(text.contains(word)) }
        #expect(PropositionsCLI.run(["paragraphs"], workingDirectory: repositoryRoot).exitCode == 2)
        #expect(PropositionsCLI.run(["--help"], workingDirectory: repositoryRoot).stdout.joined().contains("paragraphs"))
    }
}
