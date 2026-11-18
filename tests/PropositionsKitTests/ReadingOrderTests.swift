import Foundation
import Testing
@testable import PropositionsKit

struct LocationTests {
    @Test(arguments: [
        ("L12", nil as String?, 12, 12),
        ("main.tex:L214", "main.tex", 214, 214),
        ("main.tex:L501-L507", "main.tex", 501, 507),
        ("parts/part2-theory.tex:L4-L9", "parts/part2-theory.tex", 4, 9),
        ("  L3 ", nil, 3, 3),
    ])
    func `A location the schema allows is parsed`(raw: String, file: String?, start: Int, end: Int) {
        #expect(Location.parse(raw) == Location(file: file, start: start, end: end))
    }

    @Test(arguments: ["main.tex:12", "L0", "L9-L3", "12", "L", "Lx", "a b.tex:L1", "a.tex:b.tex:L1", "L1-", "L1-L2-L3", "",
                     "/parts/a.tex:L1", "/main.tex:L1"])
    func `A location the schema does not allow is refused`(raw: String) {
        #expect(Location.parse(raw) == nil)
    }
}

struct ReadingOrderTests {
    // spec-example: citation-order / an included file sits at the line that includes it
    @Test func `An included file sits at the line that includes it`() throws {
        let manuscript = try Manuscript([
            "main.tex": lines(20, [10: "\\input{parts/a}"]),
            "parts/a.tex": lines(60),
        ])
        let order = try manuscript.order()
        let p1 = try #require(order.position(file: "parts/a.tex", line: 50))
        let p2 = try #require(order.position(file: nil, line: 12))
        let p3 = try #require(order.position(file: nil, line: 8))
        #expect(ReadingOrder.precedes(p3, p1))
        #expect(ReadingOrder.precedes(p1, p2))
        #expect(ReadingOrder.precedes(p3, p2))
        #expect(!ReadingOrder.precedes(p2, p1))
        #expect(order.files == ["main.tex", "parts/a.tex"])
    }

    // spec-example: citation-order / a commented include is not followed
    @Test func `A commented include is not followed`() throws {
        let manuscript = try Manuscript(["main.tex": lines(5, [3: "% \\input{parts/gone}"])])
        #expect(try manuscript.order().files == ["main.tex"])
    }

    // spec-example: citation-order / a missing include stops the check
    @Test func `A missing include stops the check`() throws {
        let manuscript = try Manuscript(["main.tex": lines(5, [3: "\\input{parts/missing}"])])
        #expect(throws: InputTreeError.missing(target: "parts/missing.tex", in: "main.tex", line: 3)) {
            try manuscript.order()
        }
    }

    @Test func `Nested includes order by every level`() throws {
        let manuscript = try Manuscript([
            "main.tex": lines(10, [4: "\\input{a}"]),
            "a.tex": lines(10, [2: "\\include{b.tex}"]),
            "b.tex": lines(10),
        ])
        let order = try manuscript.order()
        let inB = try #require(order.position(file: "b.tex", line: 9))
        let aAfter = try #require(order.position(file: "a.tex", line: 3))
        let aBefore = try #require(order.position(file: "a.tex", line: 1))
        let mainAfter = try #require(order.position(file: nil, line: 5))
        #expect(ReadingOrder.precedes(aBefore, inB))
        #expect(ReadingOrder.precedes(inB, aAfter))
        #expect(ReadingOrder.precedes(aAfter, mainAfter))
    }

    @Test func `A file included twice counts where it is first included`() throws {
        let manuscript = try Manuscript([
            "main.tex": lines(10, [2: "\\input{shared}", 8: "\\input{shared}"]),
            "shared.tex": lines(3),
        ])
        let order = try manuscript.order()
        #expect(order.position(file: "shared.tex", line: 1) == [2, 1, 1])
        #expect(order.files == ["main.tex", "shared.tex"])
    }

    @Test func `A cyclic include stops the check`() throws {
        let manuscript = try Manuscript([
            "main.tex": lines(3, [1: "\\input{a}"]),
            "a.tex": lines(3, [1: "\\input{main}"]),
        ])
        #expect(throws: InputTreeError.cycle(chain: ["main.tex", "a.tex", "main.tex"])) {
            try manuscript.order()
        }
    }

    @Test func `Nesting deeper than three levels stops the check`() throws {
        let manuscript = try Manuscript([
            "main.tex": "\\input{a}\n", "a.tex": "\\input{b}\n", "b.tex": "\\input{c}\n",
            "c.tex": "\\input{d}\n", "d.tex": "text\n",
        ])
        #expect(throws: InputTreeError.tooDeep(file: "d.tex", limit: 3)) { try manuscript.order() }
    }

    @Test func `Three levels of nesting are read`() throws {
        let manuscript = try Manuscript([
            "main.tex": "\\input{a}\n", "a.tex": "\\input{b}\n", "b.tex": "\\input{c}\n", "c.tex": "text\n",
        ])
        #expect(try manuscript.order().files == ["main.tex", "a.tex", "b.tex", "c.tex"])
    }

    @Test func `An absolute include is refused`() throws {
        let manuscript = try Manuscript(["main.tex": "\\input{/etc/hosts}\n"])
        #expect(throws: InputTreeError.absolute(target: "/etc/hosts", in: "main.tex", line: 1)) {
            try manuscript.order()
        }
    }

    @Test func `An include inside a verbatim environment is not followed`() throws {
        let manuscript = try Manuscript([
            "main.tex": "\\begin{verbatim}\n\\input{gone}\n\\end{verbatim}\n\\begin{lstlisting}\n\\input{gone2}\n\\end{lstlisting}\ntext\n",
        ])
        #expect(try manuscript.order().files == ["main.tex"])
    }

    @Test func `An escaped percent sign does not start a comment`() throws {
        let manuscript = try Manuscript([
            "main.tex": "95\\% of cases \\input{a}\nline break\\\\% \\input{gone}\n",
            "a.tex": "text\n",
        ])
        #expect(try manuscript.order().files == ["main.tex", "a.tex"])
    }

    @Test func `Macros that only begin like an include are not includes`() throws {
        let manuscript = try Manuscript([
            "main.tex": "\\includegraphics{fig}\n\\inputencoding{utf8}\n\\input {a}\n\\subfile{b}\n",
            "a.tex": "text\n",
        ])
        let order = try manuscript.order()
        #expect(order.files == ["main.tex", "a.tex"])
        #expect(order.skippedImports == ["main.tex:4"])
    }

    @Test func `A file outside the input tree has no position`() throws {
        let manuscript = try Manuscript(["main.tex": lines(3), "parts/b.tex": lines(3)])
        #expect(try manuscript.order().position(file: "parts/b.tex", line: 2) == nil)
    }

    // spec-example: citation-order / two includes on one line keep their order
    @Test func `Two includes on one line keep their order`() throws {
        let manuscript = try Manuscript([
            "main.tex": "\\input{a}\\input{b}\nnext\n",
            "a.tex": lines(60), "b.tex": lines(3),
        ])
        let order = try manuscript.order()
        let inA = try #require(order.position(file: "a.tex", line: 50))
        let inB = try #require(order.position(file: "b.tex", line: 1))
        let next = try #require(order.position(file: nil, line: 2))
        #expect(ReadingOrder.precedes(inA, inB))
        #expect(ReadingOrder.precedes(inB, next))
    }

    // spec-example: citation-order / an environment marker inside a comment changes nothing
    @Test(arguments: [
        "x\n%\\begin{comment}\n\\input{a}\n%\\end{comment}\ny\n",
        "% \\begin{verbatim}\n\\input{a}\n",
        "\\begin{verbatim}x\\end{verbatim}\n\\input{a}\n",
    ])
    func `An environment marker inside a comment changes nothing`(main: String) throws {
        let manuscript = try Manuscript(["main.tex": main, "a.tex": lines(3)])
        #expect(try manuscript.order().files == ["main.tex", "a.tex"])
    }

    // spec-example: citation-order / lines are counted as the tool that writes locations counts them
    @Test func `Lines are counted as the tool that writes locations counts them`() throws {
        // A line feed, a carriage return and the two together end a line; a form feed does not.
        let manuscript = try Manuscript([
            "main.tex": "one\u{0C}x\u{0C}two\nthree\r\\input{a}\r\nsix\n",
            "a.tex": lines(2),
        ])
        #expect(try manuscript.order().position(file: "a.tex", line: 1) == [3, 1, 1])
    }

    // spec-example: citation-order / the main file under another name
    @Test func `The main file under another name`() throws {
        let manuscript = try Manuscript([
            "thesis.tex": lines(20, [10: "\\input{main}"]),
            "main.tex": lines(5),
        ])
        let order = try ReadingOrder(mainFile: manuscript.root.appendingPathComponent("thesis.tex"))
        #expect(order.position(file: nil, line: 3) == [3])
        #expect(order.position(file: "thesis.tex", line: 3) == [3])  // the main file's own name
        // `main.tex` always means the main file, as the tool that writes locations has it; the
        // included file of that name cannot be named by a location.
        #expect(order.position(file: "main.tex", line: 3) == [3])
    }

    @Test func `A file outside the main file's directory is keyed by its relative path`() throws {
        let manuscript = try Manuscript([
            "m/main.tex": "\\input{../shared/defs}\n",
            "shared/defs.tex": lines(3),
        ])
        let order = try ReadingOrder(mainFile: manuscript.root.appendingPathComponent("m/main.tex"))
        #expect(order.files == ["main.tex", "../shared/defs.tex"])
        #expect(order.position(file: "../shared/defs.tex", line: 2) == [1, 1, 2])
    }

    @Test func `An include with an empty name stops the check`() throws {
        let manuscript = try Manuscript(["main.tex": "\\input{ }\n"])
        #expect(throws: InputTreeError.missing(target: ".tex", in: "main.tex", line: 1)) {
            try manuscript.order()
        }
    }

    // spec-example: citation-order / an environment ends only at its own end
    @Test func `An environment ends only at its own end`() throws {
        let manuscript = try Manuscript([
            "main.tex": "\\begin{verbatim}\n\\end{comment}\n\\input{gone}\n\\end{verbatim}\n\\input{a}\n",
            "a.tex": lines(2),
        ])
        #expect(try manuscript.order().files == ["main.tex", "a.tex"])
    }

    @Test(arguments: [
        "\\begin{comment}ignored\\end{comment}\\input{a}\n",
        "\\begin{verbatim}50% \\input{gone}\\end{verbatim}\n\\input{a}\n",
        "\\input{a}\\begin{verbatim}\n\\input{gone}\n\\end{verbatim}\n",
    ])
    func `An include beside an environment on one line is followed`(main: String) throws {
        let manuscript = try Manuscript(["main.tex": main, "a.tex": lines(2)])
        #expect(try manuscript.order().files == ["main.tex", "a.tex"])
    }

    // spec-example: citation-order / an import macro that is not followed
    @Test func `An import macro that is not followed`() throws {
        let manuscript = try Manuscript([
            "main.tex": "\\subfile{x}\\input{a}\n\\import{dir/}{y}\n",
            "a.tex": lines(2),
        ])
        let order = try manuscript.order()
        #expect(order.files == ["main.tex", "a.tex"])
        #expect(order.skippedImports == ["main.tex:1", "main.tex:2"])
    }

    // spec-example: citation-order / a file reached through a symbolic link
    @Test func `A file reached through a symbolic link`() throws {
        let manuscript = try Manuscript([
            "main.tex": "\\input{a}\n\\input{b}\n",
            "a.tex": lines(2),
        ])
        try FileManager.default.createSymbolicLink(
            at: manuscript.root.appendingPathComponent("b.tex"),
            withDestinationURL: manuscript.root.appendingPathComponent("a.tex"))
        // b.tex is a.tex: one file, counted where it is first included.
        #expect(try manuscript.order().files == ["main.tex", "a.tex"])
    }
}
