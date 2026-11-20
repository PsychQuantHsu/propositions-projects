import CryptoKit
import Foundation
import Testing
@testable import PropositionsKit

/// plugins/propositions/hooks/fetch-cli.sh and run-cli.sh, run with stand-ins for curl, codesign
/// and uname. Nothing is downloaded: the stand-in curl writes a fixed payload where the hook asks.
struct FetchHookTests {
    /// The stand-in binary is a shell script, so that run-cli.sh can run it.
    static let payload = "#!/bin/sh\necho \"ran: $*\"\n"
    static let team = "TEAMID1234"
    static let goodLock = "version=9.9.9\nsha256=\(sha256(payload))\nteam=\(team)\n"

    /// What is at the binary's path after a run.
    enum Entry: Equatable {
        case nothing
        case file(content: String, executable: Bool)
        case other(String)
    }

    struct Outcome {
        let exitCode: Int32
        let output: String
        let calls: String
        let binary: Entry
        /// Every entry of the data directory other than `bin/propositions`, as relative paths.
        let others: [String]
    }

    /// What is put at the binary's path before the run.
    enum Existing {
        case file(String, mode: Int)
        case directory
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func entry(at url: URL) -> Entry {
        let fm = FileManager.default
        guard let attributes = try? fm.attributesOfItem(atPath: url.path) else { return .nothing }
        let type = attributes[.type] as? FileAttributeType
        guard type == .typeRegular else { return .other(type?.rawValue ?? "unknown") }
        let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
        let data = fm.contents(atPath: url.path) ?? Data()
        return .file(content: String(decoding: data, as: UTF8.self), executable: mode & 0o100 != 0)
    }

    /// Runs one of the two scripts from a copy of the hooks directory. `dataName` nil leaves
    /// CLAUDE_PLUGIN_DATA unset (and gives run-cli.sh an empty first argument).
    func run(script name: String = "fetch-cli.sh", arguments: [String] = [], dataName: String? = "propositions-test",
             lock: String? = goodLock, existing: Existing? = nil, binIsLink: Bool = false,
             environment extra: [String: String] = [:]) throws -> Outcome {
        let fm = FileManager.default
        let box = fm.temporaryDirectory.appendingPathComponent("hook-test-\(UUID().uuidString)")
        let tools = box.appendingPathComponent("tools")
        let hooks = box.appendingPathComponent("hooks")
        try fm.createDirectory(at: tools, withIntermediateDirectories: true)
        try fm.createDirectory(at: hooks, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: box) }
        let log = box.appendingPathComponent("calls.log").path
        let source = repositoryRoot.appendingPathComponent("plugins/propositions/hooks/\(name)")
        let script = hooks.appendingPathComponent(name)
        try fm.copyItem(at: source, to: script)
        if let lock {
            try lock.write(to: hooks.appendingPathComponent("cli.lock"), atomically: true, encoding: .utf8)
        }
        let stubs: [String: String] = [
            "curl": """
                echo "curl $*" >> "\(log)"
                [ -z "$STUB_CURL_FAIL" ] || { echo "curl: (22) stand-in failure" >&2; exit 22; }
                out=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && out="$2"; shift; done
                if [ -n "${STUB_PAYLOAD+set}" ]; then printf '%s' "$STUB_PAYLOAD" > "$out"; else /bin/cat "\(box.path)/payload" > "$out"; fi
                """,
            // Accepts a file only when the requirement it is given names the stand-in team.
            "codesign": """
                echo "codesign $*" >> "\(log)"
                [ -z "$STUB_BAD_SIGNATURE" ] || { echo "stand-in: invalid signature" >&2; exit 1; }
                case "$*" in
                  *"Developer"*) exit 1 ;;
                  *"field.1.2.840.113635.100.6.2.6"*"field.1.2.840.113635.100.6.1.13"*"subject.OU] = \\"${STUB_TEAM-\(Self.team)}\\""*) exit 0 ;;
                  *) exit 1 ;;
                esac
                """,
            "uname": "echo \"${STUB_UNAME-Darwin}\"",
        ]
        try Self.payload.write(to: box.appendingPathComponent("payload"), atomically: true, encoding: .utf8)
        for (stub, body) in stubs {
            let url = tools.appendingPathComponent(stub)
            try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        var environment = ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": box.path, "TMPDIR": box.path]
        let data = box.appendingPathComponent(dataName ?? "unused")
        let binary = data.appendingPathComponent("bin/propositions")
        if dataName != nil {
            environment["CLAUDE_PLUGIN_DATA"] = data.path
            if binIsLink {
                let elsewhere = box.appendingPathComponent("elsewhere")
                try fm.createDirectory(at: elsewhere, withIntermediateDirectories: true)
                try fm.createDirectory(at: data, withIntermediateDirectories: true)
                try fm.createSymbolicLink(at: data.appendingPathComponent("bin"), withDestinationURL: elsewhere)
            }
            switch existing {
            case .file(let content, let mode):
                try fm.createDirectory(at: binary.deletingLastPathComponent(), withIntermediateDirectories: true)
                try content.write(to: binary, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: mode], ofItemAtPath: binary.path)
            case .directory:
                try fm.createDirectory(at: binary.appendingPathComponent("inside"), withIntermediateDirectories: true)
            case nil:
                break
            }
        }
        environment.merge(extra) { _, new in new }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path] + (name == "run-cli.sh" ? [dataName == nil ? "" : data.path] : []) + arguments
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        var others: [String] = []
        if let enumerator = fm.enumerator(atPath: data.path) {
            for case let path as String in enumerator where path != "bin" && path != "bin/propositions" {
                others.append(path)
            }
        }
        let elsewhere = (try? fm.contentsOfDirectory(atPath: box.appendingPathComponent("elsewhere").path)) ?? []
        return Outcome(exitCode: process.terminationStatus, output: String(decoding: output, as: UTF8.self),
                       calls: (try? String(contentsOfFile: log, encoding: .utf8)) ?? "",
                       binary: Self.entry(at: binary), others: others.sorted() + elsewhere.map { "elsewhere/\($0)" })
    }

    static func lines(_ text: String) -> [String] { text.split(separator: "\n").map(String.init) }

    // spec-example: citation-order / the hook installs the binary that has the pinned hash and team
    @Test func `Installs the binary that has the pinned hash and team`() throws {
        let outcome = try run()
        #expect(outcome.exitCode == 0)
        #expect(outcome.binary == .file(content: Self.payload, executable: true))
        #expect(Self.lines(outcome.output) == ["propositions: installed the command-line tool v9.9.9"])
        #expect(outcome.calls.contains("releases/download/propositions-cli-v9.9.9/propositions"))
        #expect(outcome.calls.contains("curl -q "))
        #expect(outcome.others.isEmpty)
    }

    // spec-example: citation-order / the hook is silent when the pinned binary is already there
    @Test func `Does nothing and prints nothing when the pinned binary is already there`() throws {
        let outcome = try run(existing: .file(Self.payload, mode: 0o755))
        #expect(outcome.exitCode == 0)
        #expect(outcome.output.isEmpty)
        #expect(outcome.calls.isEmpty)
        #expect(outcome.binary == .file(content: Self.payload, executable: true))
    }

    // spec-example: citation-order / the hook replaces what is not the pinned binary
    @Test(arguments: [("older binary\n", 0o755), (payload, 0o644)])
    func `Replaces a file of another version, or one that cannot be run`(content: String, mode: Int) throws {
        let outcome = try run(existing: .file(content, mode: mode))
        #expect(outcome.exitCode == 0)
        #expect(outcome.binary == .file(content: Self.payload, executable: true))
        #expect(outcome.calls.contains("curl "))
        #expect(outcome.others.isEmpty)
    }

    // spec-example: citation-order / a failed check leaves no binary
    @Test(arguments: [
        (["STUB_PAYLOAD": "something else\n"], "pinned SHA-256"),
        (["STUB_PAYLOAD": ""], "pinned SHA-256"),
        (["STUB_TEAM": "OTHERTEAM1"], "Developer ID signature of the pinned team"),
        (["STUB_BAD_SIGNATURE": "1"], "Developer ID signature of the pinned team"),
        (["STUB_CURL_FAIL": "1"], "could not download"),
    ])
    func `Installs nothing, and leaves no file of another version, when a check fails`(
        environment: [String: String], message: String
    ) throws {
        let outcome = try run(existing: .file("older binary\n", mode: 0o755), environment: environment)
        #expect(outcome.exitCode == 0)
        #expect(outcome.binary == .nothing)
        #expect(Self.lines(outcome.output).count == 1)
        #expect(outcome.output.contains(message))
        #expect(outcome.others.isEmpty)
    }

    // spec-example: citation-order / the hook does nothing outside its own data directory
    @Test(arguments: [
        ("propositions-test", ["STUB_UNAME": "Linux"]),
        ("codex-openai-codex", [:]),
        ("my-propositions", [:]),
    ])
    func `Leaves everything as it is on another system or in another plugin's directory`(
        dataName: String, environment: [String: String]
    ) throws {
        let outcome = try run(dataName: dataName, existing: .file("older binary\n", mode: 0o755), environment: environment)
        #expect(outcome.exitCode == 0)
        #expect(outcome.output.isEmpty)
        #expect(outcome.calls.isEmpty)
        #expect(outcome.binary == .file(content: "older binary\n", executable: true))
        #expect(outcome.others.isEmpty)
    }

    @Test func `Does nothing without a plugin data directory`() throws {
        let outcome = try run(dataName: nil)
        #expect(outcome.exitCode == 0)
        #expect(outcome.output.isEmpty)
        #expect(outcome.calls.isEmpty)
        #expect(outcome.others.isEmpty)
    }

    // spec-example: citation-order / the hook writes through no link and into no directory
    @Test func `Fetches nothing when the directory for the binary is a link`() throws {
        let outcome = try run(binIsLink: true)
        #expect(outcome.exitCode == 0)
        #expect(Self.lines(outcome.output).count == 1)
        #expect(outcome.output.contains("is a link"))
        #expect(outcome.calls.isEmpty)
        #expect(outcome.others.isEmpty)
    }

    @Test func `Fetches nothing when a directory is where the binary goes`() throws {
        let outcome = try run(existing: .directory)
        #expect(outcome.exitCode == 0)
        #expect(Self.lines(outcome.output).count == 1)
        #expect(outcome.output.contains("cannot remove"))
        #expect(outcome.calls.isEmpty)
        #expect(outcome.binary == .other(FileAttributeType.typeDirectory.rawValue))
        #expect(outcome.others == ["bin/propositions/inside"])
    }

    // spec-example: citation-order / an unusable lock file fetches nothing
    @Test(arguments: [
        ("version=1.0;rm\nsha256=\(sha256(payload))\nteam=\(team)\n", "version"),
        ("version=1.0\nsha256=\(sha256(payload))\nteam=\(team)\n", "version"),
        ("version=1..0\nsha256=\(sha256(payload))\nteam=\(team)\n", "version"),
        ("version=1.0.0.0\nsha256=\(sha256(payload))\nteam=\(team)\n", "version"),
        ("version=1.0.0\nsha256=abc\nteam=\(team)\n", "sha256"),
        ("version=1.0.0\nsha256=\(sha256(payload).uppercased())\nteam=\(team)\n", "sha256"),
        ("version=1.0.0\nsha256=\(sha256(payload))\nteam=\n", "team"),
        ("version=1.0.0\nsha256=\(sha256(payload))\nteam=short\n", "team"),
        ("version=1.0.0\nversion=2.0.0\nsha256=\(sha256(payload))\nteam=\(team)\n", "form"),
        (goodLock + "extra=1\n", "form"),
        ("sha256=\(sha256(payload))\nversion=1.0.0\nteam=\(team)\n", "version"),
    ])
    func `Fetches nothing when the lock file is unusable`(lock: String, field: String) throws {
        let outcome = try run(lock: lock)
        #expect(outcome.exitCode == 0)
        #expect(Self.lines(outcome.output).count == 1)
        #expect(outcome.output.contains("no usable \(field)"))
        #expect(outcome.calls.isEmpty)
        #expect(outcome.binary == .nothing)
        #expect(outcome.others.isEmpty)
    }

    // spec-example: citation-order / the repository's lock file has the three fields
    @Test func `The lock file has a version, a hash and the signing team`() throws {
        let lock = try String(contentsOf: repositoryRoot.appendingPathComponent("plugins/propositions/hooks/cli.lock"),
                              encoding: .utf8)
        let lines = Self.lines(lock)
        #expect(lines.count == 3)
        #expect(lines[0].wholeMatch(of: /version=\d+\.\d+\.\d+/) != nil)
        #expect(lines[1].wholeMatch(of: /sha256=[0-9a-f]{64}/) != nil)
        #expect(lines[2] == "team=6W377FS7BS")
    }

    // MARK: run-cli.sh

    // spec-example: citation-order / the launcher runs the pinned binary with the arguments it is given
    @Test func `Runs the pinned binary with the arguments it is given`() throws {
        let outcome = try run(script: "run-cli.sh", arguments: ["cite-order", "--tex", "a b.tex"],
                              existing: .file(Self.payload, mode: 0o755))
        #expect(outcome.exitCode == 0)
        #expect(outcome.output == "ran: cite-order --tex a b.tex\n")
    }

    // spec-example: citation-order / the launcher runs nothing but the pinned binary
    @Test(arguments: [
        (Existing?.none, "is not installed"),
        (.file("#!/bin/sh\necho other version\n", mode: 0o755), "is not v9.9.9"),
        (.file(payload, mode: 0o644), "is not installed"),
        (.directory, "is not installed"),
    ] as [(Existing?, String)])
    func `Runs nothing, and says so with exit 3, when the pinned binary is not there`(
        existing: Existing?, message: String
    ) throws {
        let outcome = try run(script: "run-cli.sh", arguments: ["cite-order"], existing: existing)
        #expect(outcome.exitCode == 3)
        #expect(Self.lines(outcome.output).count == 1)
        #expect(outcome.output.hasPrefix("propositions: NOT RUN ("))
        #expect(outcome.output.contains(message))
    }

    @Test(arguments: [("codex-openai-codex", goodLock as String?), (nil, goodLock), ("propositions-test", nil),
                      ("propositions-test", "version=1.0\nsha256=abc\nteam=x\n")] as [(String?, String?)])
    func `Runs nothing for another plugin's directory or without a usable lock`(dataName: String?, lock: String?) throws {
        let outcome = try run(script: "run-cli.sh", arguments: ["cite-order"], dataName: dataName, lock: lock,
                              existing: .file(Self.payload, mode: 0o755))
        #expect(outcome.exitCode == 3)
        #expect(outcome.output.hasPrefix("propositions: NOT RUN ("))
        #expect(!outcome.output.contains("ran:"))
    }

    @Test func `Runs nothing through a linked directory or without a subcommand`() throws {
        let linked = try run(script: "run-cli.sh", arguments: ["cite-order"], binIsLink: true)
        #expect(linked.exitCode == 3)
        let bare = try run(script: "run-cli.sh", existing: .file(Self.payload, mode: 0o755))
        #expect(bare.exitCode == 3)
        #expect(bare.output.hasPrefix("propositions: NOT RUN (usage"))
    }

    // spec-example: citation-order / the skill calls the binary only through the launcher
    @Test func `The skill calls the binary only through the launcher`() throws {
        let skill = try String(
            contentsOf: repositoryRoot.appendingPathComponent("plugins/propositions/skills/propositions/SKILL.md"),
            encoding: .utf8)
        let call = #"bash "$PLUGIN_ROOT/hooks/run-cli.sh" "${CLAUDE_PLUGIN_DATA}" cite-order --jsonl "$JSONL" --tex "$TEX""#
        #expect(skill.contains(call))
        #expect(!skill.contains("bin/propositions"))
        #expect(!skill.contains(".claude/plugins/data"))
    }
}
