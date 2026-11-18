import Foundation
@testable import PropositionsKit

/// A manuscript in a temporary directory, removed when the value goes away.
final class Manuscript {
    let root: URL

    init(_ files: [String: String]) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("propositions-tests-\(UUID().uuidString)")
        for (name, text) in files {
            let url = root.appendingPathComponent(name)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    var main: URL { root.appendingPathComponent("main.tex") }

    func order() throws -> ReadingOrder { try ReadingOrder(mainFile: main) }
}

/// `count` lines, with `special` replacing the lines it names (1-based).
func lines(_ count: Int, _ special: [Int: String] = [:]) -> String {
    (1...count).map { special[$0] ?? "text of line \($0)" }.joined(separator: "\n") + "\n"
}

/// One ledger line.
func prop(_ id: String, _ location: String, cites: [String] = [], type: String = "claim",
          retired: Bool = false) -> String {
    var object: [String: Any] = ["id": id, "location": location, "cites": cites, "claim_type": type]
    if retired {
        object["retired"] = ["since": "2026-11-01", "mechanism": "removed", "match": "exact", "reason": "test"]
    }
    let data = try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    return String(decoding: data, as: UTF8.self)
}

func ledger(_ lines: String...) -> Ledger { Ledger(jsonl: lines.joined(separator: "\n") + "\n") }

/// The root of this repository, found from the path of this file.
let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
