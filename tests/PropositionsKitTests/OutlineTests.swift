import Foundation
import Testing
@testable import PropositionsKit

private let sectionA = #"{"id":"s-a","heading":"A","says":"Section A says this."}"#
private let sectionB = #"{"id":"s-b","heading":"B","says":"Section B says that."}"#
private func paragraph(_ id: String, _ section: String, extra: String = "") -> String {
    #"{"id":"\#(id)","section":"\#(section)","points":[{"id":"\#(id).1","text":"A point."}]\#(extra)}"#
}

private func outline(sections: [String] = [sectionA, sectionB],
                     paragraphs: [String] = [paragraph("p-1", "s-a"), paragraph("p-2", "s-a"), paragraph("p-3", "s-b")],
                     approvals: [String]? = nil) -> Outline {
    Outline(sections: sections.joined(separator: "\n") + "\n", paragraphs: paragraphs.joined(separator: "\n") + "\n",
            approvals: approvals.map { $0.joined(separator: "\n") + "\n" })
}

private let sectionCases: [(String, String)] = [
        (#"{"id":"s-a","heading":"A"}"#, "says is not a non-empty string"),
        (#"{"id":"s-a","heading":"","says":"S."}"#, "heading is not a non-empty string"),
        (#"{"heading":"A","says":"S."}"#, "a record has no id"),
        (#"{"id":"s-a","heading":"A","says":"S.","role":"chapter"}"#, "role is not one of the roles of the format"),
        (#"{"id":"s-a","heading":"A","says":"S.","part":"online"}"#, "part is not one of main, appendix, supplement"),
        (#"{"id":"s-a","heading":"A","says":"S.","parent":"s-z"}"#, "parent does not name a section record on an earlier line"),
        (#"{"id":"s-a","heading":"A","says":"S.","dropped":""}"#, "dropped is not a non-empty string"),
        (#"{"id":"s-a","heading":"A","says":"S.","moved_to":"paper B"}"#, "moved_to is not a non-empty string on a record that carries dropped"),
        (#"{"id":"s-a","heading":"A","says":"S.","says":"T."}"#, #"the key "says" is written twice in one object"#),
        (#"{"id":"s-a","heading":"A","says":"S\u0007."}"#, "a string holds a control character"),
        (#"{"id":"s-a","heading":"A","says":"S.","n":1e400}"#, "a number is too large for jq to keep"),
        (#"["s-a"]"#, "not a JSON object"),
        (#"{"id":"s-a","heading":"A","says":"S.",}"#, "not a JSON object"),
    ]

private let paragraphCases: [(String, String)] = [
        (#"{"id":"p-1","section":"s-a"}"#, "points is not a list of one or more points"),
        (#"{"id":"p-1","section":"s-a","points":[]}"#, "points is not a list of one or more points"),
        (#"{"id":"p-1","section":"s-a","points":[{"text":"T."}]}"#, "a record or a point has no id"),
        (#"{"id":"p-1","section":"s-a","points":[{"id":"p-1.1"}]}"#, "the text of a point is not a non-empty string"),
        (#"{"id":"p-1","section":"s-z","points":[{"id":"p-1.1","text":"T."}]}"#, "section names no section record"),
        (#"{"id":"p-1","section":7,"points":[{"id":"p-1.1","text":"T."}]}"#, "section is not a string"),
        (paragraph("p-1", "s-a", extra: #","carry":true"#), "a record that carries carry has no from"),
        (paragraph("p-1", "s-a", extra: #","carry":"yes","from":[{"file":"m.tex","label":"a"}]"#), "carry is not true"),
        (paragraph("p-1", "s-a", extra: #","edits":"x""#), "edits is not a non-empty string on a record that carries carry"),
        (paragraph("p-1", "s-a", extra: #","from":[]"#), "from is not a list of one or more locators"),
        (paragraph("p-1", "s-a", extra: #","from":{"file":"m.tex","label":"a"}"#), "from is not a list of one or more locators"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"m.tex"}]"#), "from: a locator has neither label nor starts"),
        (paragraph("p-1", "s-a", extra: #","from":[{"label":"a"}]"#), "from: a locator has no file"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"m.tex","label":"a","lines":[1,2]}]"#), "from: a locator has lines without commit"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"m.tex","label":"a","lines":[1],"commit":"c"}]"#), "from: lines is not a list of two line numbers, the first and the last"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"m.tex","label":"a","lines":[2.5,-1],"commit":"c"}]"#), "from: lines is not a list of two line numbers, the first and the last"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"m.tex","label":"a","lines":[9,3],"commit":"c"}]"#), "from: lines is not a list of two line numbers, the first and the last"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"m.tex","label":"a","lines":[1000000001,1000000000],"commit":"c"}]"#), "from: lines is not a list of two line numbers, the first and the last"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"/etc/hosts","starts":"localhost"}]"#), "from: a locator's file is not a path from the root"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"m\u202e.tex","label":"a"}]"#), "from: a locator's file name holds a control character"),
        (paragraph("p-1", "s-a", extra: #","replaces":[{"file":"m.tex","starts":7}]"#), "replaces: starts is not a string"),
        (paragraph("p-1", "s-a", extra: #","from":[{"outline":"b","id":"q"}]"#), "from: a reference to another outline stands where only locators go"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"m.tex","label":"a"}],"replaces":[{"file":"m.tex","label":"a","starts":"x"}]"#), "a locator is in both from and replaces"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"m.tex","starts":"The  bound"}],"replaces":[{"file":"m.tex","starts":" The bound"}]"#), "a locator is in both from and replaces"),
        (paragraph("p-1", "s-a", extra: #","from":[{"file":"m.tex","label":"thm:  main"}],"replaces":[{"file":"m.tex","label":"thm: main"}]"#), "a locator is in both from and replaces"),
        (paragraph("p-1", "s-a", extra: #","uses":"p-0""#), "uses is not a list"),
        (paragraph("p-1", "s-a", extra: #","uses":[""]"#), "uses has an entry that is neither an id nor a reference to another outline"),
        (paragraph("p-1", "s-a", extra: #","uses":[{"outline":"b"}]"#), "uses: a reference to another outline is not an object with outline and id, and without file"),
        (paragraph("p-1", "s-a", extra: #","uses":["p-9"]"#), #"uses names "p-9", which is not a record or a point on an earlier line"#),
        (paragraph("p-1", "s-a", extra: #","uses":["p-1.1"]"#), #"uses names "p-1.1", which is not a record or a point on an earlier line"#),
        (paragraph("p-1", "s-a", extra: #","moved_to":"B","dropped":null"#), "dropped is not a non-empty string"),
        (paragraph("p-1", "s-a", extra: #","note":3"#), "note is not a string"),
    ]

private let approvalCases: [(String, String)] = [
        (#"{"approved_at":"2026-11-13","statement":"ok","sections":[{"section":{"id":"s-a","heading":"A","says":"S."},"paragraphs":[]}]}"#, "approved_at is not a time with its offset from UTC"),
        (#"{"approved_at":"2026-11-13T16:30:00Z","statement":"","sections":[{"section":{"id":"s-a","heading":"A","says":"S."},"paragraphs":[]}]}"#, "statement is not a non-empty string"),
        (#"{"approved_at":"2026-11-13T16:30:00.5-05:00","statement":"ok","sections":[]}"#, "sections is not a list of one or more entries"),
        (#"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"ok","sections":[{"section":{"id":"s-a"}}]}"#, "an entry of sections does not hold a section record and a list of paragraph records"),
        (#"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"ok","whole":false,"sections":[{"section":{"id":"s-a","heading":"A","says":"S."},"paragraphs":[]}]}"#, "whole is not true"),
        ("not json", "not a JSON object"),
        (#"{"approved_at":"2026-02-30T16:30:00+08:00","statement":"ok","sections":[{"section":{"id":"s-a","heading":"A","says":"S."},"paragraphs":[]}]}"#, "approved_at is not a time with its offset from UTC"),
        (#"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"ok","sections":[{"section":{"id":"s-a"},"paragraphs":[]}]}"#, "an entry of sections does not hold a section record and a list of paragraph records"),
        (#"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"ok","sections":[{"section":{"id":"s-a","heading":"A","says":"S."},"paragraphs":[{"id":"p","section":"s-a"}]}]}"#, "an entry of sections does not hold a section record and a list of paragraph records"),
        (#"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"ok","sections":[{"section":{"id":"s-a","heading":"A","says":"S."},"paragraphs":[]},{"section":{"id":"s-a","heading":"A","says":"S."},"paragraphs":[]}]}"#, #"the section "s-a" has two entries in one approval"#),
        (#"{"approved_at":"2026-02-15T12:34:60Z","statement":"ok","sections":[{"section":{"id":"s-a","heading":"A","says":"S."},"paragraphs":[]}]}"#, "approved_at is not a time with its offset from UTC"),
        (#"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"ok","sections":[{"section":{"id":"s-a","heading":"A","says":"S.","role":7},"paragraphs":[]}]}"#, "an entry of sections does not hold a section record and a list of paragraph records"),
        (#"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"ok","sections":[{"section":{"id":"s-a","heading":"A","says":"S."},"paragraphs":[{"id":"p","section":"s-a","points":[{"id":"p.1","text":"T."}]},{"id":"p","section":"s-a","points":[{"id":"p.2","text":"T."}]}]}]}"#, #"the id "p" is used twice in one approval"#),
        (#"{"approved_at":"2026-99-99T99:99:99+99:99","statement":"ok","sections":[{"section":{"id":"s-a","heading":"A","says":"S."},"paragraphs":[]}]}"#, "approved_at is not a time with its offset from UTC"),
        (#"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"ok","sections":[{"section":{"id":"s-a"},"paragraphs":[{}]}]}"#, "an entry of sections does not hold a section record and a list of paragraph records"),
        (#"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"ok","sections":[{"section":{"id":"s-a"},"paragraphs":[{"id":"p","section":"s-b"}]}]}"#, "an entry of sections does not hold a section record and a list of paragraph records"),
    ]

private let changeCases: [(String, [String], [String], Bool, Bool, Bool)] = [
        ("a point of p-2 is reworded", [sectionA, sectionB],
         [paragraph("p-1", "s-a"), #"{"id":"p-2","section":"s-a","points":[{"id":"p-2.1","text":"Reworded."}]}"#, paragraph("p-3", "s-b")], false, true, true),
        ("p-1 and p-2 are swapped", [sectionA, sectionB], [paragraph("p-2", "s-a"), paragraph("p-1", "s-a"), paragraph("p-3", "s-b")], false, true, true),
        ("p-2 is moved to s-b", [sectionA, sectionB], [paragraph("p-1", "s-a"), paragraph("p-2", "s-b"), paragraph("p-3", "s-b")], false, false, true),
        ("p-3 is given dropped", [sectionA, sectionB], [paragraph("p-1", "s-a"), paragraph("p-2", "s-a"), paragraph("p-3", "s-b", extra: #","dropped":"out""#)], true, false, true),
        ("an undefined key is added to p-3", [sectionA, sectionB], [paragraph("p-1", "s-a"), paragraph("p-2", "s-a"), paragraph("p-3", "s-b", extra: #","length_target":200"#)], true, false, true),
        ("p-1 is written with its keys in another order", [sectionA, sectionB],
         [#"{"points":[{"text":"A point.","id":"p-1.1"}],"section":"s-a","id":"p-1"}"#, paragraph("p-2", "s-a"), paragraph("p-3", "s-b")], true, true, true),
        ("a section s-c is added", [sectionA, sectionB, #"{"id":"s-c","heading":"C","says":"S."}"#],
         [paragraph("p-1", "s-a"), paragraph("p-2", "s-a"), paragraph("p-3", "s-b"), paragraph("p-4", "s-c")], true, true, false),
        ("s-a and s-b are swapped with their groups", [sectionB, sectionA], [paragraph("p-3", "s-b"), paragraph("p-1", "s-a"), paragraph("p-2", "s-a")], true, true, false),
    ]

private let locatorCases: [(String, String?)] = [
        (#"{"file":"paper/main.tex","label":"thm:a"}"#, nil),
        (#"{"file":"paper/main.tex","starts":"\\begin{proof} Let $y$ be large."}"#, nil),
        (#"{"file":"paper/main.tex","starts":"  Let $x$ be   small. "}"#, nil),
        (#"{"file":"paper/main.tex","starts":"\\begin{proof}"}"#, #""p-1": starts occurs 2 times, not once"#),
        (#"{"file":"paper/main.tex","starts":"It repeats."}"#, #""p-1": starts occurs 2 times, not once"#),
        (#"{"file":"paper/main.tex","starts":"a a"}"#, #""p-1": starts occurs 2 times, not once"#),
        (#"{"file":"paper/main.tex","starts":"no such words"}"#, #""p-1": starts occurs 0 times, not once"#),
        (#"{"file":"paper/main.tex","starts":" "}"#, #""p-1": starts occurs 0 times, not once"#),
        (#"{"file":"paper/main.tex","label":"twice"}"#, #""p-1": the label "twice" occurs 2 times as \label{…}, not once"#),
        (#"{"file":"paper/main.tex","label":"thm:b"}"#, #""p-1": the label "thm:b" occurs 0 times as \label{…}, not once"#),
        (#"{"file":"paper/missing.tex","label":"thm:a"}"#, #""p-1": "paper/missing.tex" is not a file of the repository that git lists"#),
        (#"{"file":"../outside.tex","label":"thm:a"}"#, #""p-1": "../outside.tex" is not a file of the repository that git lists"#),
        (#"{"file":"/etc/hosts","starts":"localhost"}"#, #""p-1": a locator's file is not a path from the root"#),
        (#"{"file":".git/HEAD","starts":"ref"}"#, #""p-1": ".git/HEAD" is not a file of the repository that git lists"#),
        (#"{"file":"secret.env","starts":"API_KEY"}"#, #""p-1": "secret.env" is not a file of the repository that git lists"#),
        (#"{"file":"paper","label":"thm:a"}"#, #""p-1": "paper" is not a file of the repository that git lists"#),
        (#"{"file":"paper/main.tex"}"#, #""p-1": a locator has neither label nor starts"#),
    ]

struct JSONValueTests {
    // spec-example: article-outline / a section compared as a JSON value
    @Test func `Values are compared, not text`() throws {
        #expect(try JSONValue.parse(#"{"a":1,"b":[1.0,"x"]}"#) == JSONValue.parse(#"{"b":[1,"x"],"a":10e-1}"#))
        #expect(try JSONValue.parse("9007199254740993") != JSONValue.parse("9007199254740992"))
        #expect(try JSONValue.parse("-0") == JSONValue.parse("0.0"))
        #expect(try JSONValue.parse(#"{"a":1}"#) != JSONValue.parse(#"{"a":1,"b":null}"#))
        #expect(try JSONValue.parse(#""\u00e9""#) != JSONValue.parse(#""e\u0301""#))
    }

    @Test(arguments: ["nan", "Infinity", "01", ".5", "1.", "+1", "{\"a\":1,}", "[1 2]", "\u{FEFF}{}", "\"a\tb\"", "{} {}", "'a'", ""])
    func `Text that is not JSON is refused`(text: String) {
        #expect(throws: JSONError.self) { try JSONValue.parse(text) }
    }

    @Test func `A key written twice keeps both members and reads as the later one`() throws {
        let value = try JSONValue.parse(#"{"id":"a","id":"b"}"#)
        #expect(value.members?.count == 2)
        #expect(value["id"]?.string == "b")
    }

    @Test func `Whole numbers of any size are put in order`() throws {
        func n(_ text: String) throws -> JSONNumber {
            guard case let .number(n) = try JSONValue.parse(text) else { throw JSONError(description: "not a number") }
            return n
        }
        #expect(try JSONNumber.inOrder(n("1"), n("1e4097")) && JSONNumber.inOrder(n("12"), n("12.0")) && JSONNumber.inOrder(n("99"), n("1e2")))
        #expect(try !JSONNumber.inOrder(n("1e4097"), n("1")) && !JSONNumber.inOrder(n("13"), n("12")) && !JSONNumber.inOrder(n("101"), n("1e2")))
        #expect(try !n("2.5").isPositiveInteger && !n("-1").isPositiveInteger && !n("0").isPositiveInteger && n("1e3").isPositiveInteger)
        #expect(OutlineCheck.findings(outline(paragraphs: [paragraph("p-1", "s-a", extra: #","from":[{"file":"m.tex","label":"a","lines":[1,1e12],"commit":"c"}]"#)])) == [])
    }

    @Test func `Numbers keep their value at any size`() throws {
        #expect(try JSONValue.parse("1e-999999999999999") != JSONValue.parse("2e-999999999999999"))
        #expect(try JSONValue.parse("1e-2147483648") != JSONValue.parse("1e-2147483649"))
        #expect(throws: JSONError.self) { try JSONValue.parse("1e9999999999999999") }
        func beyond(_ text: String) throws -> Bool {
            guard case let .number(n) = try JSONValue.parse(text) else { return false }
            return n.isBeyondDouble
        }
        #expect(try beyond("2e308") && beyond("1e400") && beyond("1.8e308"))
        #expect(try !beyond("1.7e308") && !beyond("1e308") && !beyond("0e999") && !beyond("123456"))
    }

    @Test func `Lines end at a line feed, and bytes that are not UTF-8 are not JSON`() {
        let crlf = Outline.lines(of: Data("{\"id\":\"a\"}\r\n\r\n{\"id\":\"b\"}\r\n".utf8))
        #expect(crlf.map(\.number) == [1, 3] && crlf[0].value?["id"]?.string == "a" && crlf[1].value?["id"]?.string == "b")
        let bad = Outline.lines(of: Data([0x7B, 0x22, 0x61, 0x22, 0x3A, 0x22, 0xFF, 0x22, 0x7D, 0x0A]))
        #expect(bad.count == 1 && bad[0].value == nil)
        let nul = Outline.lines(of: Data([0x7B, 0x7D, 0x00, 0x78, 0x0A]))
        #expect(nul.count == 1 && nul[0].value == nil)
    }

    @Test func `Escapes are read, and half of a surrogate pair is refused`() throws {
        #expect(try JSONValue.parse(#""\ud83d\ude00\n\u0041""#).string == "😀\nA")
        for text in [#""\ud83d x""#, #""\ude00""#, #""\ud83d\u0041""#] {
            #expect(throws: JSONError.self) { try JSONValue.parse(text) }
        }
        #expect(JSONValue.quoted("old\u{08}\u{0C}\u{01}\u{2028}") == #""old\b\f\u0001\u2028""#)
        #expect(try JSONValue.parse("1e0000000000000000") == JSONValue.parse("1"))
    }
}

struct OutlineCheckTests {
    // spec-example: article-outline / an outline that passes the format check
    @Test func `An outline with every key of the format passes`() {
        let sections = [
            #"{"id":"s-a","heading":"A","says":"Section A says this.","role":"method","part":"main"}"#,
            #"{"id":"s-b","heading":"B","says":"Section B says that.","parent":"s-a","part":"appendix"}"#,
            #"{"id":"s-c","heading":"C","says":"It goes elsewhere.","dropped":"moved","moved_to":"the second paper"}"#,
        ]
        let paragraphs = [
            #"{"id":"p-1","section":"s-a","carry":true,"edits":"The last sentence is removed.","from":[{"file":"main.tex","label":"thm:a"}],"points":[{"id":"p-1.1","text":"Theorem 1 states the bound."}],"note":"n"}"#,
            #"{"id":"p-2","section":"s-a","replaces":[{"file":"main.tex","starts":"Old abstract","lines":[1,3],"commit":"3f2c1ab"}],"uses":["p-1.1",{"outline":"paper-b/propositions","id":"q-1"}],"points":[{"id":"p-2.1","text":"A new abstract.","pending":"numbers","basis":[{"outline":"paper-b/propositions","id":"q-1"}]}]}"#,
            paragraph("p-3", "s-b"),
            paragraph("p-4", "s-c", extra: #","dropped":"with its section""#),
        ]
        let approval = #"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"I approve\nthe outline.","whole":true,"sections":[{"section":\#(sectionA),"paragraphs":[]}]}"#
        #expect(OutlineCheck.findings(outline(sections: sections, paragraphs: paragraphs, approvals: [approval])) == [])
    }

    // spec-example: article-outline / section records the format check reports
    @Test(arguments: sectionCases)
    func `Section records the format check reports`(line: String, message: String) {
        #expect(OutlineCheck.findings(outline(sections: [line], paragraphs: [])) == ["outline-sections.jsonl line 1: \(message)"])
    }

    @Test func `Section records are checked against the lines before them`() {
        let found = OutlineCheck.findings(outline(sections: [
            #"{"id":"s-b","heading":"B","says":"S.","parent":"s-a"}"#, sectionA,
            #"{"id":"s-a","heading":"A again","says":"S."}"#,
            #"{"id":"s-d","heading":"D","says":"S.","dropped":"out"}"#,
            #"{"id":"s-e","heading":"E","says":"S.","parent":"s-d"}"#,
        ], paragraphs: []))
        #expect(found == [
            "outline-sections.jsonl line 1: parent does not name a section record on an earlier line",
            "outline-sections.jsonl line 5: its parent carries dropped and it does not",
            #"outline-sections.jsonl: id "s-a" is on lines 2, 3"#,
        ])
        #expect(OutlineCheck.findings(Outline(sections: "", paragraphs: "", approvals: nil)) == ["outline-sections.jsonl: the file holds no record"])
    }

    // spec-example: article-outline / paragraph records the format check reports
    @Test(arguments: paragraphCases)
    func `Paragraph records the format check reports`(line: String, message: String) {
        let found = OutlineCheck.findings(outline(paragraphs: [line]))
        #expect(found.first == "outline-paragraphs.jsonl line 1: \(message)", "\(found)")
    }

    // spec-example: article-outline / the order of the paragraph records
    @Test func `The groups of paragraph records follow the section file`() {
        let split = OutlineCheck.findings(outline(paragraphs: [paragraph("p-1", "s-a"), paragraph("p-3", "s-b"), paragraph("p-2", "s-a")]))
        #expect(split == [#"outline-paragraphs.jsonl line 3: the records of section "s-a" are not on consecutive lines"#])
        let swapped = OutlineCheck.findings(outline(paragraphs: [paragraph("p-3", "s-b"), paragraph("p-1", "s-a")]))
        #expect(swapped == [#"outline-paragraphs.jsonl line 2: section "s-a" comes before "s-b" in the section file and after it here"#])
        #expect(OutlineCheck.findings(outline(paragraphs: [paragraph("p-3", "s-b")])) == [])
    }

    @Test func `Ids, dropped sections and uses are checked across lines`() {
        let dropped = #"{"id":"s-b","heading":"B","says":"S.","dropped":"out"}"#
        let found = OutlineCheck.findings(outline(sections: [sectionA, dropped], paragraphs: [
            paragraph("p-1", "s-a", extra: #","dropped":"out""#),
            paragraph("p-2", "s-a", extra: #","uses":["p-1","p-1.1"]"#),
            #"{"id":"p-2","section":"s-a","points":[{"id":"p-1.1","text":"T."}]}"#,
            paragraph("p-3", "s-b"),
        ]))
        #expect(found == [
            #"outline-paragraphs.jsonl line 2: uses names "p-1", which belongs to a record that carries dropped"#,
            #"outline-paragraphs.jsonl line 2: uses names "p-1.1", which belongs to a record that carries dropped"#,
            "outline-paragraphs.jsonl line 4: its section carries dropped and it does not",
            #"outline-paragraphs.jsonl: id "p-1.1" is on lines 1, 3"#,
            #"outline-paragraphs.jsonl: id "p-2" is on lines 2, 3"#,
        ])
    }

    // spec-example: article-outline / approval records the format check reports
    @Test(arguments: approvalCases)
    func `Approval records the format check reports`(line: String, message: String) {
        #expect(OutlineCheck.findings(outline(approvals: [line])) == ["outline-approvals.jsonl line 1: \(message)"])
    }
}

struct OutlineStatusTests {
    private func approval(_ sections: [(String, [String])], whole: Bool) -> String {
        let entries = sections.map { #"{"section":\#($0.0),"paragraphs":[\#($0.1.joined(separator: ","))]}"# }
        return #"{"approved_at":"2026-11-13T16:30:00+08:00","statement":"approved",\#(whole ? #""whole":true,"# : "")"sections":[\#(entries.joined(separator: ","))]}"#
    }
    private var approvedBoth: String {
        approval([(sectionA, [paragraph("p-1", "s-a"), paragraph("p-2", "s-a")]), (sectionB, [paragraph("p-3", "s-b")])], whole: true)
    }

    // spec-example: article-outline / eight changes after an approval of the whole outline
    @Test(arguments: changeCases)
    func `Eight changes after an approval of the whole outline`(change: String, sections: [String], paragraphs: [String], a: Bool, b: Bool, order: Bool) throws {
        let lines = try OutlineStatus.lines(outline(sections: sections, paragraphs: paragraphs, approvals: [approvedBoth]))
        func answer(_ name: String) -> String? { lines.first { $0.hasPrefix(name + "\t") }?.components(separatedBy: "\t")[1] }
        #expect(answer(#""s-a""#) == (a ? "stands as approved" : "differs from its latest approved copy"), "\(change)")
        #expect(answer(#""s-b""#) == (b ? "stands as approved" : "differs from its latest approved copy"), "\(change)")
        #expect(answer("order of sections") == (order ? "stands as approved" : "differs from the last approval of the whole outline"), "\(change)")
        if sections.count == 3 { #expect(answer(#""s-c""#) == "never approved") }
        #expect(lines.last == "ok status")
    }

    // spec-example: article-outline / sections approved one at a time
    @Test func `Approving sections one at a time does not approve their order`() throws {
        let lines = try OutlineStatus.lines(outline(approvals: [
            approval([(sectionA, [paragraph("p-1", "s-a"), paragraph("p-2", "s-a")])], whole: false),
            approval([(sectionB, [paragraph("p-3", "s-b")])], whole: false),
        ]))
        #expect(lines == [
            "\"s-a\"\tstands as approved", "\"s-b\"\tstands as approved",
            "order of sections\tno approval of the whole outline is on record",
            "sections removed since their approval\t0", "paragraph records that name no section\t0",
            "points that carry pending\t0", "records that carry dropped\t0", "ok status",
        ])
    }

    @Test func `With no approvals file every section was never approved`() throws {
        let lines = try OutlineStatus.lines(outline(paragraphs: [
            paragraph("p-1", "s-a", extra: #","dropped":"x""#), paragraph("p-9", "s-z"),
            #"{"id":"p-3","section":"s-b","points":[{"id":"p-3.1","text":"T.","pending":"data"}]}"#,
        ]))
        #expect(lines == [
            "\"s-a\"\tnever approved", "\"s-b\"\tnever approved",
            "order of sections\tno approval of the whole outline is on record",
            "sections removed since their approval\t0", "paragraph records that name no section\t1\t[\"p-9\"]",
            "points that carry pending\t1", "records that carry dropped\t1", "ok status",
        ])
    }

    // spec-example: article-outline / a section removed since its approval
    @Test func `A removed section is reported until the whole outline is approved without it`() throws {
        let onlyA = outline(sections: [sectionA], paragraphs: [paragraph("p-1", "s-a"), paragraph("p-2", "s-a")], approvals: [approvedBoth])
        #expect(try OutlineStatus.lines(onlyA).contains("sections removed since their approval\t1\t[\"s-b\"]"))
        let again = approval([(sectionA, [paragraph("p-1", "s-a"), paragraph("p-2", "s-a")])], whole: true)
        let approvedWithout = outline(sections: [sectionA], paragraphs: [paragraph("p-1", "s-a"), paragraph("p-2", "s-a")], approvals: [approvedBoth, again])
        let lines = try OutlineStatus.lines(approvedWithout)
        #expect(lines.contains("sections removed since their approval\t0"))
        #expect(lines.contains("order of sections\tstands as approved"))
    }

    @Test func `Two long numbers that differ make a section differ`() throws {
        let before = paragraph("p-3", "s-b", extra: #","n":9007199254740992"#)
        let after = paragraph("p-3", "s-b", extra: #","n":9007199254740993"#)
        let record = approval([(sectionB, [before])], whole: false)
        let lines = try OutlineStatus.lines(outline(sections: [sectionB], paragraphs: [after], approvals: [record]))
        #expect(lines.first == "\"s-b\"\tdiffers from its latest approved copy")
    }

    @Test func `A line that is not a record stops the status`() {
        #expect(throws: OutlineStatus.Failure.self) { try OutlineStatus.lines(outline(paragraphs: ["[1]"])) }
        #expect(throws: OutlineStatus.Failure.self) { try OutlineStatus.lines(outline(approvals: [#"{"sections":7}"#])) }
    }
}

/// A git repository in a temporary directory.
private final class Repository {
    let root: URL

    init(_ files: [String: String], ignore: String? = nil) throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("outline-tests-\(UUID().uuidString)").resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var all = files
        if let ignore { all[".gitignore"] = ignore }
        for (name, text) in all {
            let url = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        try run(["init", "-q", "."])
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func run(_ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", root.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }

    func findings(_ extra: String) -> [String] {
        OutlineLocators.findings(paragraphs: Outline.lines(of: paragraph("p-1", "s-a", extra: extra) + "\n"), root: root)
    }
}

struct OutlineLocatorTests {
    private let text = "\\begin{proof}\nLet $x$ be small.\n\\end{proof}\n\\begin{proof}\nLet $y$ be\n  large. \\label{thm:a}\n\\end{proof}\nIt repeats. It repeats.\na a a\n% \\label{twice} \\label{twice}\n"

    // spec-example: article-outline / locators that name one place and locators that do not
    @Test(arguments: locatorCases)
    func `Locators that name one place and locators that do not`(locator: String, finding: String?) throws {
        let repository = try Repository(["paper/main.tex": text, "secret.env": "API_KEY=1\n"], ignore: "*.env\n")
        #expect(repository.findings(#","from":[\#(locator)]"#) == (finding.map { [$0] } ?? []))
    }

    @Test func `Every list of locators is read, and a reference to another outline is not`() throws {
        let repository = try Repository(["main.tex": text])
        let record = #"{"id":"p-1","section":"s-a","replaces":[{"file":"main.tex","label":"none"}],"points":[{"id":"p-1.1","text":"T.","basis":[{"outline":"b","id":"q"},{"file":"main.tex","starts":"zzz"}]}]}"#
        let found = OutlineLocators.findings(paragraphs: Outline.lines(of: record + "\n"), root: repository.root)
        #expect(found == [
            #""p-1": the label "none" occurs 0 times as \label{…}, not once"#,
            #""p-1": starts occurs 0 times, not once"#,
        ])
    }

    @Test func `Lists that are not lists, and lines that are not records, are reported`() throws {
        let repository = try Repository(["main.tex": text])
        let lines = [#"{"id":"p-1","section":"s-a","from":{"file":"main.tex","label":"missing"},"replaces":[],"points":[{"id":"p-1.1","text":"T.","basis":{}}]}"#, "[1]"]
        #expect(OutlineLocators.findings(paragraphs: Outline.lines(of: lines.joined(separator: "\n") + "\n"), root: repository.root) == [
            #""p-1": from is not a list of one or more locators"#, #""p-1": replaces is not a list of one or more locators"#,
            #""p-1": basis is not a list of one or more locators or references to another outline"#, "line 2: not a JSON object",
        ])
    }

    @Test func `Two spellings of one name are two files`() throws {
        let repository = try Repository(["caf\u{00E9}.tex": "Alpha here.\n"])
        try "Beta here.\n".write(to: repository.root.appendingPathComponent("cafe\u{0301}.tex"), atomically: true, encoding: .utf8)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: repository.root.path))?.filter { $0.hasSuffix(".tex") } ?? []
        guard names.count == 2 else { return }   // a file system that folds the two spellings holds one file
        let record = #"{"id":"p-1","section":"s-a","from":[{"file":"caf\u00e9.tex","starts":"Alpha"},{"file":"cafe\u0301.tex","starts":"Alpha"}],"points":[{"id":"p-1.1","text":"T."}]}"#
        #expect(OutlineLocators.findings(paragraphs: Outline.lines(of: record + "\n"), root: repository.root) == [#""p-1": starts occurs 0 times, not once"#])
    }

    @Test func `A root that is the root of the file system holds every path under it`() {
        // Asked without git: the path check alone decides, and it must not look for "//".
        let asked = OutlineLocators.readable("no/such/file.tex", rootPath: "/", git: { _, _ in 1 })
        #expect(asked == nil)
        let found = OutlineLocators.readable("etc/hosts", rootPath: "/", git: { _, arguments in arguments.contains("ls-files") ? 0 : 1 })
        #expect(found != nil)
    }

    @Test func `A file through a symbolic link that leads outside is not read`() throws {
        let repository = try Repository(["main.tex": text])
        let outside = FileManager.default.temporaryDirectory.appendingPathComponent("outline-outside-\(UUID().uuidString).tex")
        try "\\label{thm:a}\n".write(to: outside, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: outside) }
        try FileManager.default.createSymbolicLink(at: repository.root.appendingPathComponent("link.tex"), withDestinationURL: outside)
        #expect(repository.findings(#","from":[{"file":"link.tex","label":"thm:a"}]"#) == [#""p-1": "link.tex" is not a file of the repository that git lists"#])
    }
}

struct OutlineCommandTests {
    private func directory(_ files: [String: String]) throws -> Manuscript { try Manuscript(files) }

    // spec-example: article-outline / the three files of an outline are read from one directory
    @Test func `The commands read the outline of a directory`() throws {
        let files = try directory([
            "o/outline-sections.jsonl": sectionA + "\n", "o/outline-paragraphs.jsonl": paragraph("p-1", "s-a") + "\n",
        ])
        #expect(PropositionsCLI.run(["outline", "check", "o"], workingDirectory: files.root) == CommandResult(stdout: ["ok outline check"], exitCode: 0))
        let status = PropositionsCLI.run(["outline", "status", files.root.appendingPathComponent("o").path], workingDirectory: files.root)
        #expect(status.exitCode == 0 && status.stdout.first == "\"s-a\"\tnever approved" && status.stdout.last == "ok status")
        let notARepository = PropositionsCLI.run(["outline", "locators", "o", "--root", "."], workingDirectory: files.root)
        #expect(notARepository == CommandResult(stderr: ["outline locators: the root . is not the root of a git repository"], exitCode: 2))
        let repository = try Repository(["o/outline-sections.jsonl": sectionA + "\n", "o/outline-paragraphs.jsonl": paragraph("p-1", "s-a") + "\n"])
        let locators = PropositionsCLI.run(["outline", "locators", "o", "--root", "."], workingDirectory: repository.root)
        #expect(locators == CommandResult(stdout: ["ok locators"], exitCode: 0))
        #expect(PropositionsCLI.run(["outline", "locators", "o", "--root", "o"], workingDirectory: repository.root)
            == CommandResult(stderr: ["outline locators: the root o is not the root of a git repository"], exitCode: 2))
    }

    // spec-example: article-outline / a missing file and a wrong argument
    @Test func `Findings exit with 1, and a missing file or a wrong argument with 2`() throws {
        let files = try directory([
            "o/outline-sections.jsonl": #"{"id":"s-a"}"# + "\n", "o/outline-paragraphs.jsonl": "[1]\n",
            "half/outline-sections.jsonl": sectionA + "\n",
        ])
        let check = PropositionsCLI.run(["outline", "check", "o"], workingDirectory: files.root)
        #expect(check.exitCode == 1 && check.stdout.count == 3)
        #expect(PropositionsCLI.run(["outline", "status", "o"], workingDirectory: files.root).exitCode == 2)
        let missing = PropositionsCLI.run(["outline", "check", "half"], workingDirectory: files.root)
        #expect(missing == CommandResult(stderr: ["outline check: cannot read outline-paragraphs.jsonl in half"], exitCode: 2))
        #expect(PropositionsCLI.run(["outline", "locators", "o"], workingDirectory: files.root).exitCode == 2)
        #expect(PropositionsCLI.run(["outline", "locators", "o", "--root", "nowhere"], workingDirectory: files.root).exitCode == 2)
        #expect(PropositionsCLI.run(["outline", "nothing"], workingDirectory: files.root).exitCode == 2)
    }

    // spec-example: article-outline / an approvals file that cannot be read
    @Test func `An approvals file that cannot be read is not an outline that was never approved`() throws {
        let files = try directory([
            "o/outline-sections.jsonl": sectionA + "\n", "o/outline-paragraphs.jsonl": paragraph("p-1", "s-a") + "\n",
            "o/outline-approvals.jsonl": "",
        ])
        // A directory where the file should be: it is there and cannot be read, whoever runs the test.
        let approvals = files.root.appendingPathComponent("o/outline-approvals.jsonl")
        try FileManager.default.removeItem(at: approvals)
        try FileManager.default.createDirectory(at: approvals, withIntermediateDirectories: false)
        let status = PropositionsCLI.run(["outline", "status", "o"], workingDirectory: files.root)
        #expect(status == CommandResult(stderr: ["outline status: cannot read outline-approvals.jsonl in o"], exitCode: 2))
    }

    @Test func `An outline file that is a symbolic link is not read`() throws {
        let files = try directory(["o/outline-sections.jsonl": sectionA + "\n", "elsewhere.jsonl": paragraph("p-1", "s-a") + "\n"])
        try FileManager.default.createSymbolicLink(
            at: files.root.appendingPathComponent("o/outline-paragraphs.jsonl"), withDestinationURL: files.root.appendingPathComponent("elsewhere.jsonl"))
        #expect(PropositionsCLI.run(["outline", "check", "o"], workingDirectory: files.root)
            == CommandResult(stderr: ["outline check: cannot read outline-paragraphs.jsonl in o"], exitCode: 2))
    }

    @Test func `Help for each subcommand`() {
        for name in ["check", "status", "locators"] {
            let help = PropositionsCLI.run(["outline", name, "--help"], workingDirectory: repositoryRoot)
            #expect(help.exitCode == 0 && help.stdout.contains { $0.contains("propositions outline \(name)") }, "\(name)")
        }
        let named = PropositionsCLI.run(["outline", "status", "cite-order", "--help"], workingDirectory: repositoryRoot)
        #expect(named.stdout.contains { $0.contains("propositions outline status") })
        let group = PropositionsCLI.run(["outline", "--help"], workingDirectory: repositoryRoot)
        #expect(group.exitCode == 0 && group.stdout.contains { $0.contains("locators") })
    }
}
