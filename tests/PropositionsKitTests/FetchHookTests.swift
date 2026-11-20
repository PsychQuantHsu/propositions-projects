import CryptoKit
import Foundation
import Testing
@testable import PropositionsKit

/// plugins/propositions/hooks/fetch-cli.sh, run with stand-ins for curl, codesign and uname.
/// Nothing is downloaded: the stand-in curl writes a fixed payload where the hook asks.
struct FetchHookTests {
    static let payload = "stand-in binary\n"
    static let team = "TEAMID1234"

    struct Outcome {
        let exitCode: Int32
        let output: String
        let calls: String
        let installed: String?
        let leftovers: [String]
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// `lock` replaces the whole lock file; `existing` is put at the binary's path before the run.
    func run(dataName: String? = "propositions-test", lock: String? = nil, existing: String? = nil,
             environment extra: [String: String] = [:]) throws -> Outcome {
        let fm = FileManager.default
        let box = fm.temporaryDirectory.appendingPathComponent("hook-test-\(UUID().uuidString)")
        let tools = box.appendingPathComponent("tools")
        let hooks = box.appendingPathComponent("hooks")
        try fm.createDirectory(at: tools, withIntermediateDirectories: true)
        try fm.createDirectory(at: hooks, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: box) }
        let log = box.appendingPathComponent("calls.log").path
        let source = repositoryRoot.appendingPathComponent("plugins/propositions/hooks/fetch-cli.sh")
        let script = hooks.appendingPathComponent("fetch-cli.sh")
        try fm.copyItem(at: source, to: script)
        let lockText = lock ?? "version=9.9.9\nsha256=\(Self.sha256(Self.payload))\nteam=\(Self.team)\n"
        try lockText.write(to: hooks.appendingPathComponent("cli.lock"), atomically: true, encoding: .utf8)
        let stubs: [String: String] = [
            "curl": """
                echo "curl $*" >> "\(log)"
                [ -z "$STUB_CURL_FAIL" ] || exit 22
                out=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && out="$2"; shift; done
                printf '%s' "${STUB_PAYLOAD-\(Self.payload)}" > "$out"
                """,
            "codesign": """
                echo "codesign $1" >> "\(log)"
                case "$1" in
                  --verify) [ -z "$STUB_BAD_SIGNATURE" ] || exit 1 ;;
                  -dv) echo "TeamIdentifier=${STUB_TEAM-\(Self.team)}" >&2 ;;
                esac
                """,
            "uname": "echo \"${STUB_UNAME-Darwin}\"",
        ]
        for (name, body) in stubs {
            let url = tools.appendingPathComponent(name)
            try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        var environment = ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": box.path, "TMPDIR": box.path]
        var binary: URL?
        if let dataName {
            let data = box.appendingPathComponent(dataName)
            environment["CLAUDE_PLUGIN_DATA"] = data.path
            binary = data.appendingPathComponent("bin/propositions")
            if let existing, let binary {
                try fm.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
                try existing.write(to: binary, atomically: true, encoding: .utf8)
            }
        }
        environment.merge(extra) { _, new in new }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let installed = binary.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        let directory = binary?.deletingLastPathComponent().path ?? ""
        let leftovers = ((try? fm.contentsOfDirectory(atPath: directory)) ?? []).filter { $0 != "propositions" }
        return Outcome(exitCode: process.terminationStatus, output: String(decoding: data, as: UTF8.self),
                       calls: (try? String(contentsOfFile: log, encoding: .utf8)) ?? "",
                       installed: installed, leftovers: leftovers)
    }

    // spec-example: citation-order / the hook installs the binary that has the pinned hash and team
    @Test func `Installs the binary that has the pinned hash and team`() throws {
        let outcome = try run()
        #expect(outcome.exitCode == 0)
        #expect(outcome.installed == Self.payload)
        #expect(outcome.output.contains("installed the command-line tool v9.9.9"))
        #expect(outcome.calls.contains("releases/download/propositions-cli-v9.9.9/propositions"))
        #expect(outcome.leftovers.isEmpty)
    }

    // spec-example: citation-order / the hook is silent when the pinned binary is already there
    @Test func `Does nothing and prints nothing when the pinned binary is already there`() throws {
        let outcome = try run(existing: Self.payload)
        #expect(outcome.exitCode == 0)
        #expect(outcome.output.isEmpty)
        #expect(outcome.calls.isEmpty)
        #expect(outcome.installed == Self.payload)
    }

    @Test func `Replaces a binary of another version`() throws {
        let outcome = try run(existing: "older binary\n")
        #expect(outcome.exitCode == 0)
        #expect(outcome.installed == Self.payload)
    }

    // spec-example: citation-order / a failed check leaves no binary
    @Test(arguments: [
        (["STUB_PAYLOAD": "something else\n"], "pinned SHA-256"),
        (["STUB_TEAM": "OTHERTEAM1"], "pinned team"),
        (["STUB_TEAM": ""], "pinned team"),
        (["STUB_BAD_SIGNATURE": "1"], "no valid signature"),
        (["STUB_CURL_FAIL": "1"], "could not download"),
    ])
    func `Installs nothing, and leaves no binary of another version, when a check fails`(
        environment: [String: String], message: String
    ) throws {
        let outcome = try run(existing: "older binary\n", environment: environment)
        #expect(outcome.exitCode == 0)
        #expect(outcome.installed == nil)
        #expect(outcome.output.contains(message))
        #expect(outcome.leftovers.isEmpty)
    }

    // spec-example: citation-order / the hook does nothing outside its own data directory
    @Test func `Does nothing on a system the release was not built for`() throws {
        let outcome = try run(existing: "older binary\n", environment: ["STUB_UNAME": "Linux"])
        #expect(outcome.exitCode == 0)
        #expect(outcome.output.isEmpty)
        #expect(outcome.calls.isEmpty)
        #expect(outcome.installed == "older binary\n")
    }

    @Test func `Does nothing without a plugin data directory`() throws {
        let outcome = try run(dataName: nil)
        #expect(outcome.exitCode == 0)
        #expect(outcome.output.isEmpty)
        #expect(outcome.calls.isEmpty)
    }

    @Test func `Writes nothing into the data directory of another plugin`() throws {
        let outcome = try run(dataName: "codex-openai-codex")
        #expect(outcome.exitCode == 0)
        #expect(outcome.output.isEmpty)
        #expect(outcome.calls.isEmpty)
        #expect(outcome.installed == nil)
    }

    // spec-example: citation-order / an unusable lock file fetches nothing
    @Test(arguments: [
        ("version=1.0;rm\nsha256=\(sha256(payload))\nteam=\(team)\n", "version"),
        ("version=1.0.0\nsha256=abc\nteam=\(team)\n", "sha256"),
        ("version=1.0.0\nsha256=\(sha256(payload).uppercased())\nteam=\(team)\n", "sha256"),
        ("version=1.0.0\nsha256=\(sha256(payload))\nteam=\n", "team"),
    ])
    func `Fetches nothing when the lock file is unusable`(lock: String, field: String) throws {
        let outcome = try run(lock: lock)
        #expect(outcome.exitCode == 0)
        #expect(outcome.output.contains("no usable \(field)"))
        #expect(outcome.calls.isEmpty)
        #expect(outcome.installed == nil)
    }

    // spec-example: citation-order / the repository's lock file has the three fields
    @Test func `The lock file has a version, a hash and the signing team`() throws {
        let lock = try String(contentsOf: repositoryRoot.appendingPathComponent("plugins/propositions/hooks/cli.lock"),
                              encoding: .utf8)
        let lines = lock.split(separator: "\n").map(String.init)
        #expect(lines.count == 3)
        #expect(lines[0].wholeMatch(of: /version=\d+\.\d+\.\d+/) != nil)
        #expect(lines[1].wholeMatch(of: /sha256=[0-9a-f]{64}/) != nil)
        #expect(lines[2] == "team=6W377FS7BS")
    }
}
