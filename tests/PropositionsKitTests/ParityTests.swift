import Foundation
import Testing
@testable import PropositionsKit

/// Three things are written in Python and in Swift (specification umbrella-marketplace-layout).
/// These tests put the same inputs to both and compare, so that a change to one side that the
/// other does not follow fails here. They run the Python tools of this repository.
struct ParityTests {
    /// The first `python3` on PATH that is 3.10 or later, which the Python tools need. When there
    /// is none these tests are skipped, and the test run says so.
    static let interpreter: String? = ((ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/python3" }
        + ["/opt/homebrew/bin/python3", "/usr/local/bin/python3", "/usr/bin/python3"])
        .first { path in
            guard FileManager.default.isExecutableFile(atPath: path) else { return false }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["-c", "import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)"]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            return (try? process.run()) != nil && { process.waitUntilExit(); return process.terminationStatus == 0 }()
        }

    /// Runs a Python program with the scripts directory on its path; `input` is handed over as JSON on stdin.
    func python(_ program: String, input: Any) throws -> Any {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: try #require(ParityTests.interpreter))
        process.arguments = ["-c", "import sys, json\nsys.path.insert(0, 'plugins/propositions/scripts')\n" + program]
        process.currentDirectoryURL = repositoryRoot
        let stdin = Pipe(), stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        try process.run()
        stdin.fileHandleForWriting.write(try JSONSerialization.data(withJSONObject: input))
        stdin.fileHandleForWriting.closeFile()
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try #require(process.terminationStatus == 0)
        return try JSONSerialization.jsonObject(with: data)
    }

    // spec-example: umbrella-marketplace-layout / a location is read alike in both languages
    @Test(.enabled(if: ParityTests.interpreter != nil))
    func `A location is read alike in both languages`() throws {
        let cases = ["L12", "main.tex:L214", "main.tex:L501-L507", "parts/a.tex:L4-L9", "main.tex:12", "L0", "L9-L3",
                     "12", "L", "a b.tex:L1", "a.tex:b.tex:L1", "L1-", "L1-L2-L3", "", "../shared/defs.tex:L2",
                     "/parts/a.tex:L1", "/main.tex:L1", "L٣", "parts/a.tex:L٤-L٥", "L½", " L3\t", "\u{200B}L3",
                     "\u{FEFF}L3", "L3\u{1C}", "L3\u{A0}", "Lx", "L-1", "L 3", "l3", ".tex:L1", "a.tex:"]
        let answer = try python("""
            from _lib.latex_env_parser import parse_location_v16
            out = []
            for raw in json.load(sys.stdin):
                p = parse_location_v16(raw)
                out.append(None if p is None else [p[0], p[1], p[2]])
            print(json.dumps(out))
            """, input: cases)
        let rows = try #require(answer as? [Any])
        for (raw, row) in zip(cases, rows) {
            let swift = Location.parse(raw)
            guard let triple = row as? [Any] else {
                #expect(swift == nil, "Python refuses \(raw.debugDescription), Swift reads it")
                continue
            }
            // Python maps the prefix `main.tex` to "no file"; Swift keeps it and ReadingOrder maps it.
            let file = triple[0] as? String
            #expect(swift?.start == triple[1] as? Int, "start of \(raw.debugDescription)")
            #expect(swift?.end == triple[2] as? Int, "end of \(raw.debugDescription)")
            #expect((swift?.file == "main.tex" ? nil : swift?.file) == file, "file of \(raw.debugDescription)")
        }
    }

    // spec-example: umbrella-marketplace-layout / lines are counted alike in both languages
    @Test(.enabled(if: ParityTests.interpreter != nil))
    func `Lines are counted alike in both languages`() throws {
        let texts = ["a\nb\nc", "a\r\nb\r\nc\r\n", "a\rb\rc", "one\u{0C}x\u{0B}two\nthree", "a\u{2028}b\nc\u{85}d\n", "", "\n\n", "x\r\n\ry"]
        let manuscript = try Manuscript(Dictionary(uniqueKeysWithValues: texts.enumerated().map { ("t\($0.offset).tex", $0.element) }))
        // The Python side is the function of refresh-prop-locations.py that every location it
        // writes is counted with, loaded from the script itself.
        let answer = try python("""
            import importlib.util, pathlib
            spec = importlib.util.spec_from_file_location('r', 'plugins/propositions/scripts/refresh-prop-locations.py')
            r = importlib.util.module_from_spec(spec); spec.loader.exec_module(r)
            out = []
            for path in json.load(sys.stdin):
                lines = r.read_tex_lines(pathlib.Path(path))[1]
                while lines and lines[-1] == "":
                    lines.pop()
                out.append(lines)
            print(json.dumps(out))
            """, input: texts.indices.map { manuscript.root.appendingPathComponent("t\($0).tex").path })
        let rows = try #require(answer as? [[String]])
        for (text, row) in zip(texts, rows) {
            var swift = LatexLine.splitLines(text)
            while swift.last == "" { swift.removeLast() }
            #expect(swift == row, "lines of \(text.debugDescription)")
        }
    }

    // spec-example: umbrella-marketplace-layout / a retired block is judged alike in both languages
    @Test(.enabled(if: ParityTests.interpreter != nil))
    func `A retired block is judged alike in both languages`() throws {
        let good: [String: Any] = ["since": "2026-11-01", "mechanism": "removed", "match": "exact", "reason": "r"]
        var blocks: [Any] = [good, NSNull(), false, true, 0, "x", [String: Any](), ["mechanism": "removed", "reason": "r"]]
        for (key, value) in [("since", "2026-02-30"), ("since", "2026-2-3"), ("mechanism", "deleted"), ("match", "fuzzy"), ("reason", "  ")] {
            var block = good
            block[key] = value
            blocks.append(block)
        }
        blocks.append(["since": "2026-11-01", "mechanism": "comment_env", "match": "by_reading", "reason": "moved"])
        let answer = try python("""
            import importlib.util
            spec = importlib.util.spec_from_file_location('v', 'plugins/propositions/scripts/validate-propositions.py')
            v = importlib.util.module_from_spec(spec); spec.loader.exec_module(v)
            out = []
            for block in json.load(sys.stdin):
                p = {"retired": block}
                out.append(block is not None and v.retired_problem(p) is None)
            print(json.dumps(out))
            """, input: blocks)
        let rows = try #require(answer as? [Bool])
        for (block, expected) in zip(blocks, rows) {
            #expect(Ledger.isRetired(block) == expected, "retired block \(block)")
        }
    }
}
