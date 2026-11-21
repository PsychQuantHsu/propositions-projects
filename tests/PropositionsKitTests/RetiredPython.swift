import Foundation
import Testing
@testable import PropositionsKit

/// What a retired Python tool printed, exited with and wrote for an input, recorded from the tool
/// itself on 2026-11-21, before it was retired. The Swift commands that replace those tools are
/// compared with these records (tests/fixtures/retired-python/<tool>/<case>.json).
enum RetiredPython {
    struct Run: Codable, Equatable {
        let exit: Int32
        /// Standard output, as base64.
        let stdout: String
        /// The ledger after the run, as base64, for a tool that writes one.
        let file: String?

        var output: Data { Data(base64Encoded: stdout) ?? Data() }
        var written: Data? { file.flatMap { Data(base64Encoded: $0) } }
    }

    static func path(tool: String, case name: String) -> URL {
        let slug = name.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "-" }
        return repositoryRoot.appendingPathComponent("tests/fixtures/retired-python/\(tool)/\(String(slug)).json")
    }

    static func load(tool: String, case name: String) throws -> Run {
        try JSONDecoder().decode(Run.self, from: Data(contentsOf: path(tool: tool, case: name)))
    }
}
