import Foundation
import Testing
@testable import PropositionsKit

struct CiteOrderTests {
    let manuscript: Manuscript
    let order: ReadingOrder

    init() throws {
        manuscript = try Manuscript(["main.tex": lines(40)])
        order = try manuscript.order()
    }

    // spec-example: citation-order / three citations
    @Test(arguments: [
        ("L12", "claim", "L30", true),
        ("L3", "restatement", "L30", true),
        ("L12", "claim", "L5", false),
    ])
    func `Three citations`(citing: String, type: String, cited: String, warned: Bool) {
        let report = CiteOrder.check(
            ledger: ledger(prop("A", citing, cites: ["B"], type: type), prop("B", cited)), order: order)
        #expect(report.checked == 1)
        #expect(report.unreadable.isEmpty)
        #expect(report.forward == (warned
            ? [ForwardCitation(from: "A", fromLocation: citing, to: "B", toLocation: cited)] : []))
    }

    // spec-example: citation-order / a retired proposition is not checked
    @Test func `A retired proposition is not checked`() {
        let report = CiteOrder.check(
            ledger: ledger(prop("A", "L3", cites: ["B"], retired: true), prop("B", "L30")), order: order)
        #expect(report.checked == 0)
        #expect(report.forward.isEmpty)
    }

    @Test func `A citation of a retired proposition is skipped`() {
        let report = CiteOrder.check(
            ledger: ledger(prop("A", "L3", cites: ["B", "ghost"]), prop("B", "L30", retired: true)), order: order)
        #expect(report.checked == 0)
        #expect(report.forward.isEmpty)
        #expect(report.isComplete)
    }

    @Test func `Ledger order is not reading order`() {
        // B is listed first but sits later in the manuscript: citing it from L5 is forward.
        let report = CiteOrder.check(
            ledger: ledger(prop("B", "L30"), prop("A", "L5", cites: ["B"]), prop("C", "L35", cites: ["B"])),
            order: order)
        #expect(report.forward.map(\.from) == ["A"])
        #expect(report.checked == 2)
    }

    @Test func `Two propositions at the same position are not reported`() {
        let report = CiteOrder.check(
            ledger: ledger(prop("A", "L7", cites: ["B"]), prop("B", "L7-L9")), order: order)
        #expect(report.forward.isEmpty)
        #expect(report.checked == 1)
    }

    // spec-example: citation-order / warnings leave the exit code at 0
    @Test func `Warnings leave the exit code at 0`() {
        let report = CiteOrder.check(ledger: ledger(prop("A", "L12", cites: ["B"]), prop("B", "L30")), order: order)
        #expect(report.isComplete)  // the command exits with 1 only when the report is incomplete
        #expect(CiteOrder.render(report) == [
            "WARN cite-order: A (L12) cites B (L30), which comes later",
            "cite-order: 1 forward citation(s) among 1 citation(s) checked",
        ])
    }

    // spec-example: citation-order / a location the schema does not allow
    @Test func `A location the schema does not allow`() {
        let report = CiteOrder.check(
            ledger: ledger(prop("A", "L1"), prop("B", "main.tex:12", cites: ["A"])), order: order)
        #expect(!report.isComplete)
        #expect(report.unreadable == [
            "line 2: the location of B is 'main.tex:12', not [<file>.tex:]L<a>[-L<b>]",
        ])
        #expect(CiteOrder.render(report).last == "cite-order: incomplete, 1 item(s) could not be read")
    }

    // spec-example: citation-order / a file outside the input tree
    @Test func `A file outside the input tree`() {
        let report = CiteOrder.check(ledger: ledger(prop("A", "parts/b.tex:L4")), order: order)
        #expect(report.unreadable == [
            "line 1: the location of A names parts/b.tex, which the input tree does not hold",
        ])
    }

    @Test func `Ledger lines that are not propositions are reported by line`() {
        let text = [prop("A", "L1"), "not json", "[1, 2]", "{\"location\": \"L3\"}", "", prop("B", "L2", cites: ["A"])]
            .joined(separator: "\n")
        let report = CiteOrder.check(ledger: Ledger(jsonl: text), order: order)
        #expect(report.unreadable == [
            "line 2: not a JSON object", "line 3: not a JSON object", "line 4: no string id",
        ])
        #expect(report.checked == 1)
        #expect(report.forward.isEmpty)
    }

    @Test func `A proposition without a location is reported`() {
        let report = CiteOrder.check(ledger: Ledger(jsonl: "{\"id\": \"A\"}\n"), order: order)
        #expect(report.unreadable == ["line 1: the location of A is missing, not [<file>.tex:]L<a>[-L<b>]"])
    }

    @Test func `A citation across files follows the input tree`() throws {
        let multi = try Manuscript([
            "main.tex": lines(20, [10: "\\input{parts/a}"]),
            "parts/a.tex": lines(60),
        ])
        let report = CiteOrder.check(
            ledger: ledger(
                prop("early", "L8", cites: ["inA"]),            // forward: parts/a comes at line 10
                prop("inA", "parts/a.tex:L50", cites: ["late"]), // forward: line 12 of main comes after
                prop("late", "main.tex:L12", cites: ["inA", "early"])),
            order: try multi.order())
        #expect(report.forward.map { "\($0.from)>\($0.to)" } == ["early>inA", "inA>late"])
        #expect(report.checked == 4)
    }

    @Test func `The JSON output holds the three keys`() throws {
        let report = CiteOrder.check(ledger: ledger(prop("A", "L12", cites: ["B"]), prop("B", "L30")), order: order)
        let object = try #require(
            JSONSerialization.jsonObject(with: Data(try CiteOrder.renderJSON(report).utf8)) as? [String: Any])
        #expect(object["checked"] as? Int == 1)
        #expect((object["unreadable"] as? [String]) == [])
        let forward = try #require(object["forward"] as? [[String: String]])
        #expect(forward == [["from": "A", "fromLocation": "L12", "to": "B", "toLocation": "L30"]])
    }
}
