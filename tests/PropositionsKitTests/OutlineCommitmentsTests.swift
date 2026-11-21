import Foundation
import Testing
@testable import PropositionsKit

/// Commitments planned on the outline (issue 116): the format check and the comparison `write
/// check` makes.
struct OutlineCommitmentsTests {
    typealias Box = LedgerOrderTests.Box
    let base = WriteParagraphTests()

    static let sectionA = #"{"id":"s-a","heading":"A","says":"Section A says this."}"#
    static func paragraph(_ id: String, _ extra: String = "", section: String = "s-a") -> String {
        #"{"id":"\#(id)","section":"\#(section)","points":[{"id":"\#(id).1","text":"A point."}]\#(extra)}"#
    }

    func findings(_ paragraphs: [String], sections: [String] = [sectionA]) -> [String] {
        OutlineCheck.findings(Outline(sections: sections.joined(separator: "\n") + "\n", paragraphs: paragraphs.joined(separator: "\n") + "\n", approvals: nil))
    }

    // spec-example: article-outline / planned commitments pass the check
    @Test func `Planned commitments pass the check`() {
        let opens = #","opens":[{"id":"c-q-spacing","kind":"question"}]"#
        #expect(findings([Self.paragraph("p-1", opens), Self.paragraph("p-2"), Self.paragraph("p-3", #","discharges":["c-q-spacing"]"#)]).isEmpty)
        #expect(findings([Self.paragraph("p-1", opens + #","discharges":["c-q-spacing"]"#)]).isEmpty)
    }

    // spec-example: article-outline / what the check reports about commitments
    @Test func `What the check reports about commitments`() {
        let open = Self.paragraph("p-0", #","opens":[{"id":"c-q","kind":"question"}]"#)
        let cases: [([String], String)] = [
            ([Self.paragraph("p-1", #","opens":[]"#)], "opens is not a list of one or more commitments"),
            ([Self.paragraph("p-1", #","opens":"c-x""#)], "opens is not a list of one or more commitments"),
            ([Self.paragraph("p-1", #","opens":[{"id":"c-x","kind":"promise"}]"#)], "opens has an entry that is not an object with a commitment id and a kind of the format"),
            ([Self.paragraph("p-1", #","opens":[{"id":"C x","kind":"aim"}]"#)], "opens has an entry that is not an object with a commitment id and a kind of the format"),
            ([Self.paragraph("p-1", #","opens":["c-x"]"#)], "opens has an entry that is not an object with a commitment id and a kind of the format"),
            ([Self.paragraph("p-1", #","discharges":[]"#)], "discharges is not a list of one or more commitment ids"),
            ([Self.paragraph("p-1", #","discharges":[7]"#)], "discharges has an entry that is not a commitment id"),
            ([Self.paragraph("p-1", #","discharges":["c-none"]"#)], #"discharges names "c-none", which no record that is not dropped opens on this line or an earlier one"#),
            ([open, Self.paragraph("p-1", #","discharges":["c-q","c-q"]"#)], #"the commitment "c-q" is discharged twice by one record"#),
            ([open, Self.paragraph("p-1", #","opens":[{"id":"c-q","kind":"aim"}]"#)], #"the commitment "c-q" is opened more than once"#),
            ([Self.paragraph("p-1", #","opens":[{"id":"c-q","kind":"aim"},{"id":"c-q","kind":"aim"}]"#)], #"the commitment "c-q" is opened more than once"#),
            ([open, Self.paragraph("p-1", #","dropped":"cut","discharges":["c-q"]"#)], "a record that carries dropped carries opens or discharges"),
            ([Self.paragraph("p-1", #","discharges":["c-q"]"#), Self.paragraph("p-2", #","opens":[{"id":"c-q","kind":"question"}]"#)],
             #"discharges names "c-q", which no record that is not dropped opens on this line or an earlier one"#),
            // Only a dropped record opens it.
            ([Self.paragraph("p-0", #","dropped":"cut","opens":[{"id":"c-q","kind":"question"}]"#), Self.paragraph("p-1", #","discharges":["c-q"]"#)],
             #"discharges names "c-q", which no record that is not dropped opens on this line or an earlier one"#),
        ]
        for (paragraphs, expected) in cases {
            let found = findings(paragraphs)
            #expect(found.contains { $0.hasSuffix(expected) }, "\(paragraphs) → \(found)")
        }
        let abstract = #"{"id":"s-a","heading":"Abstract","says":"S.","role":"abstract"}"#
        #expect(findings([Self.paragraph("p-1", #","opens":[{"id":"c-q","kind":"question"}]"#)], sections: [abstract])
            .contains { $0.hasSuffix("a record of the abstract opens a commitment") })
        #expect(OutlineCommitments.isID(String(repeating: "a", count: 64)))
        #expect(!OutlineCommitments.isID(String(repeating: "a", count: 65)))
        #expect(!OutlineCommitments.isID("-a"))
    }

    // MARK: write check

    func write(_ arguments: [String], in box: Box) -> CommandResult { PropositionsCLI.run(["write"] + arguments, workingDirectory: box.url) }

    func outline(in box: Box, _ paragraphs: [String], whole: Bool = false) throws {
        _ = try box.write(Self.sectionA + "\n", to: "paper/outline/outline-sections.jsonl")
        _ = try box.write(paragraphs.joined(separator: "\n") + "\n", to: "paper/outline/outline-paragraphs.jsonl")
        let approval = #"{"approved_at":"2026-11-22T09:00:00+08:00","statement":"approved",\#(whole ? #""whole":true,"# : "")"sections":[{"section":\#(Self.sectionA),"paragraphs":[\#(paragraphs.joined(separator: ","))]}]}"#
        _ = try box.write(approval + "\n", to: "paper/outline/outline-approvals.jsonl")
    }

    static let fromOutline = WriteParagraphTests.prepare + ["--outline", "paper/outline", "--outline-paragraph", "p-1"]
    static func discourse(_ extra: String) -> [(String, String)] {
        [("main.jsonl", WriteParagraphTests.newProposition), ("discourse.jsonl", #"{"prop_id": "019a3c5e-7a00-7000-8000-00000000000d"\#(extra)}"#)]
    }

    // spec-example: write / a paragraph is compared with the commitments its record plans
    @Test func `A paragraph is compared with the commitments its record plans`() throws {
        let plan = [Self.paragraph("p-1", #","opens":[{"id":"c-fw-scale","kind":"future_work"}]"#)]
        let box = try base.setUp()
        try outline(in: box, plan)
        #expect(write(Self.fromOutline, in: box).exitCode == 0)
        try base.draft(box, rows: Self.discourse(#", "opens": [{"id": "c-fw-scale", "kind": "future_work"}]"#))
        #expect(write(["check", "--stage", "stage"], in: box).exitCode == 0)

        let other = try base.setUp()
        try outline(in: other, plan)
        #expect(write(Self.fromOutline, in: other).exitCode == 0)
        try base.draft(other, rows: Self.discourse(#", "opens": [{"id": "c-fw-scale", "kind": "plan"}, {"id": "c-other", "kind": "aim"}], "discharges": ["c-fw-interval"]"#))
        let check = write(["check", "--stage", "stage"], in: other)
        #expect(check.exitCode == 1)
        #expect(check.stdout.prefix(3) == [
            "the outline record p-1 plans c-fw-scale as future_work, and its paragraph opens it as plan",
            "the paragraph opens c-other, which the outline record p-1 does not plan",
            "the paragraph discharges c-fw-interval, which the outline record p-1 does not plan",
        ])
        #expect(write(["commit", "--stage", "stage"], in: other).exitCode == 2)

        // Planned and not done.
        let missing = try base.setUp()
        try outline(in: missing, [Self.paragraph("p-1", #","opens":[{"id":"c-fw-scale","kind":"future_work"}],"discharges":["c-fw-scale"]"#)])
        #expect(write(Self.fromOutline, in: missing).exitCode == 0)
        try base.draft(missing, rows: Self.discourse(""))
        #expect(write(["check", "--stage", "stage"], in: missing).stdout.prefix(2) == [
            "the outline record p-1 plans to open c-fw-scale, and its paragraph does not open it",
            "the outline record p-1 plans to discharge c-fw-scale, and its paragraph does not discharge it",
        ])
    }

    // spec-example: write / a record with no planned commitment, in an outline that plans some
    @Test func `A record with no planned commitment, in an outline that plans some`() throws {
        let box = try base.setUp()
        try outline(in: box, [Self.paragraph("p-1"), Self.paragraph("p-2", #","opens":[{"id":"c-later","kind":"aim"}]"#)])
        #expect(write(Self.fromOutline, in: box).exitCode == 0)
        try base.draft(box, rows: Self.discourse(#", "opens": [{"id": "c-other", "kind": "aim"}]"#))
        let check = write(["check", "--stage", "stage"], in: box)
        #expect(check.exitCode == 1)
        #expect(check.stdout.first == "the paragraph opens c-other, which the outline record p-1 does not plan")
    }

    // spec-example: write / an outline that plans no commitment is not compared
    @Test func `An outline that plans no commitment is not compared`() throws {
        let box = try base.setUp()
        try outline(in: box, [Self.paragraph("p-1"), Self.paragraph("p-2")])
        #expect(write(Self.fromOutline, in: box).exitCode == 0)
        try base.draft(box, rows: Self.discourse(#", "opens": [{"id": "c-other", "kind": "aim"}]"#))
        #expect(write(["check", "--stage", "stage"], in: box).exitCode == 0)
    }

    // spec-example: write / a rewrite is compared paragraph by paragraph
    @Test func `A rewrite is compared paragraph by paragraph`() throws {
        let rewrite = WriteRewriteTests()
        // p-1 plans everything the fixture's discourse sidecar does before the last paragraph.
        let fixture = try Data(contentsOf: repositoryRoot.appendingPathComponent("tests/fixtures/structure/discourse.jsonl"))
        var done = OutlineCommitments.Commitments()
        for record in OutlineCommitments.objects(fixture) where record["prop_id"]?.string != WriteRewriteTests.old { done.add(record) }
        let opens = done.opens.map { #"{"id":"\#($0.id)","kind":"\#($0.kind!)"}"# }.joined(separator: ",")
        let discharges = done.discharges.map { "\"\($0)\"" }.joined(separator: ",")
        let plan = [Self.paragraph("p-1", #","opens":[\#(opens)],"discharges":[\#(discharges)]"#),
                    Self.paragraph("p-2", #","opens":[{"id":"c-fw-interval","kind":"future_work"}]"#)]
        for recorded in [true, false] {
            let box = try base.setUp()
            try outline(in: box, plan, whole: true)
            #expect(write(WriteRewriteTests.prepare, in: box).exitCode == 0)
            try rewrite.rewrite(box)
            if recorded {
                try rewrite.edit(box, "stage/ledger/discourse.jsonl") {
                    $0 + #"{"prop_id": "\#(WriteRewriteTests.new)", "opens": [{"id": "c-fw-interval", "kind": "future_work"}]}"# + "\n"
                }
            }
            let check = write(["check", "--stage", "stage"], in: box)
            if recorded {
                #expect(check.exitCode == 0, "\(check.stdout)")
            } else {
                #expect(check.exitCode == 1)
                #expect(check.stdout.first == "the outline record p-2 plans to open c-fw-interval, and its paragraph does not open it")
            }
        }
    }
}
