import CryptoKit
import Foundation
import Testing
@testable import PropositionsKit

/// plugins/propositions/hooks/fetch-cli.sh and run-cli.sh, run by /bin/bash with stand-ins for
/// curl, codesign and uname. Nothing is downloaded: the stand-in curl writes a fixed payload
/// where the hook asks. The stand-in codesign checks the arguments it is given, not a signature:
/// that Apple's tool accepts the requirement is checked by hand against a release
/// (docs/RELEASE-FLOW.md).
struct FetchHookTests {
    /// The stand-in binary is a shell script, so that run-cli.sh can run it. It prints how many
    /// arguments it got and each of them, and exits with STUB_EXIT. On entry it makes the file
    /// STUB_MARKER names, so that a test can tell whether it ran, whatever was printed.
    static let payload = "#!/bin/sh\n[ -z \"$STUB_MARKER\" ] || : > \"$STUB_MARKER\"\necho \"$#\"\nfor a in \"$@\"; do echo \"[$a]\"; done\nexit \"${STUB_EXIT:-0}\"\n"
    static let team = "TEAMID1234"
    static let hash = sha256(payload)
    static let goodLock = lock(team: team)

    static func lock(version: String = "9.9.9", hash: String = hash, team: String) -> String {
        "version=\(version)\nsha256=\(hash)\nteam=\(team)\n"
    }

    /// The requirement the hook has to hand to codesign for a team, character for character.
    static func requirement(team: String) -> String {
        "anchor apple generic and certificate 1[field.1.2.840.113635.100.6.2.6] exists and "
            + "certificate leaf[field.1.2.840.113635.100.6.1.13] exists and certificate leaf[subject.OU] = \"\(team)\""
    }

    /// What is at a path after a run. Only a confirmed absence is `nothing`.
    enum Entry: Equatable {
        case nothing
        case file(content: String, executable: Bool)
        case other(String)
    }

    struct Outcome {
        let exitCode: Int32
        let output: String
        let calls: [String]
        /// Whether the stand-in binary was started.
        let ran: Bool
        /// What is at `bin/propositions-<pinned hash>` under the data directory.
        let binary: Entry
        /// Every other entry under the data directory, and under the directory a linked `bin` names.
        let others: [String]
    }

    /// What is put in place before the run, at the pinned path unless `name` says otherwise.
    enum Existing {
        case file(String, mode: Int)
        case directory
        /// A link at the pinned path to a matching executable kept elsewhere.
        case linkToPinned
    }

    static func sha256(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func entry(at url: URL) -> Entry {
        var info = stat()
        guard lstat(url.path, &info) == 0 else {
            return errno == ENOENT ? .nothing : .other("lstat failed: \(errno)")
        }
        guard info.st_mode & S_IFMT == S_IFREG else { return .other("mode \(String(info.st_mode & S_IFMT, radix: 8))") }
        guard let data = FileManager.default.contents(atPath: url.path) else { return .other("unreadable file") }
        return .file(content: String(decoding: data, as: UTF8.self), executable: info.st_mode & 0o100 != 0)
    }

    static func listing(of directory: URL, prefix: String = "") -> [String] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDirectory) else { return [] }
        guard let enumerator = fm.enumerator(atPath: directory.path) else { return ["\(prefix)<cannot be listed>"] }
        return enumerator.compactMap { $0 as? String }.map { prefix + $0 }
    }

    /// Runs one of the two scripts from a copy of the hooks directory. `dataName` nil leaves
    /// CLAUDE_PLUGIN_DATA unset (and gives run-cli.sh an empty first argument). `lock` nil leaves
    /// no lock file; `lockMode` is its permission.
    func run(script name: String = "fetch-cli.sh", arguments: [String] = [], dataName: String? = "propositions-test",
             lock: String? = goodLock, lockMode: Int = 0o644, signer: String = team, existing: Existing? = nil,
             binIsLink: Bool = false, environment extra: [String: String] = [:]) throws -> Outcome {
        let fm = FileManager.default
        let box = fm.temporaryDirectory.appendingPathComponent("hook-test-\(UUID().uuidString)")
        let tools = box.appendingPathComponent("tools")
        let hooks = box.appendingPathComponent("hooks")
        let elsewhere = box.appendingPathComponent("elsewhere")
        for directory in [tools, hooks, elsewhere] {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        defer {
            try? fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: hooks.appendingPathComponent("cli.lock").path)
            try? fm.removeItem(at: box)
        }
        let log = box.appendingPathComponent("calls.log").path
        let script = hooks.appendingPathComponent(name)
        try fm.copyItem(at: repositoryRoot.appendingPathComponent("plugins/propositions/hooks/\(name)"), to: script)
        if let lock {
            let url = hooks.appendingPathComponent("cli.lock")
            try lock.write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: lockMode], ofItemAtPath: url.path)
        }
        try Self.payload.write(to: box.appendingPathComponent("payload"), atomically: true, encoding: .utf8)
        let stubs: [String: String] = [
            "curl": """
                printf 'curl' >> "\(log)"; for a in "$@"; do printf ' [%s]' "$a" >> "\(log)"; done; echo >> "\(log)"
                [ -z "$STUB_CURL_FAIL" ] || { echo "curl: (22) stand-in failure" >&2; exit 22; }
                out=""; while [ $# -gt 0 ]; do [ "$1" = "-o" ] && out="$2"; shift; done
                printf '%s' "$out" > "\(box.path)/downloaded-to"
                if [ -n "${STUB_PAYLOAD+set}" ]; then printf '%s' "$STUB_PAYLOAD" > "$out"; else /bin/cat "\(box.path)/payload" > "$out"; fi
                """,
            // Accepts exactly: --verify --strict -R=<the requirement for the signer's team> <the file curl wrote>.
            "codesign": """
                echo "codesign $# $1 $2" >> "\(log)"
                [ -z "$STUB_BAD_SIGNATURE" ] || { echo "stand-in: invalid signature" >&2; exit 1; }
                [ "$#" = 4 ] && [ "$1" = "--verify" ] && [ "$2" = "--strict" ] && [ "$3" = "-R=$STUB_REQUIREMENT" ] && [ -f "$4" ] && [ "$4" = "$(/bin/cat "\(box.path)/downloaded-to")" ]
                """,
            "uname": "echo \"${STUB_UNAME-Darwin}\"",
        ]
        for (stub, body) in stubs {
            let url = tools.appendingPathComponent(stub)
            try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        var environment = ["PATH": "\(tools.path):/usr/bin:/bin", "HOME": box.path, "TMPDIR": box.path,
                           "STUB_REQUIREMENT": Self.requirement(team: signer),
                           "STUB_MARKER": box.appendingPathComponent("ran").path]
        let data = box.appendingPathComponent(dataName ?? "unused")
        let bin = data.appendingPathComponent("bin")
        let pinned = bin.appendingPathComponent("propositions-\(Self.hash)")
        if dataName != nil {
            environment["CLAUDE_PLUGIN_DATA"] = data.path
            try fm.createDirectory(at: data, withIntermediateDirectories: true)
            if binIsLink { try fm.createSymbolicLink(at: bin, withDestinationURL: elsewhere) }
            if existing != nil { try fm.createDirectory(at: bin, withIntermediateDirectories: true) }
            switch existing {
            case .file(let content, let mode):
                try content.write(to: pinned, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: mode], ofItemAtPath: pinned.path)
            case .directory:
                try fm.createDirectory(at: pinned.appendingPathComponent("inside"), withIntermediateDirectories: true)
            case .linkToPinned:
                let real = elsewhere.appendingPathComponent("real")
                try Self.payload.write(to: real, atomically: true, encoding: .utf8)
                try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: real.path)
                try fm.createSymbolicLink(at: pinned, withDestinationURL: real)
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
        let skipped: Set<String> = binIsLink ? ["bin"] : ["bin", "bin/propositions-\(Self.hash)"]
        let others = Self.listing(of: data).filter { !skipped.contains($0) }
            + Self.listing(of: elsewhere, prefix: "elsewhere/")
        let calls = ((try? String(contentsOfFile: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
        return Outcome(exitCode: process.terminationStatus, output: String(decoding: output, as: UTF8.self),
                       calls: calls, ran: fm.fileExists(atPath: box.appendingPathComponent("ran").path), binary: binIsLink ? .other("bin is a link") : Self.entry(at: pinned),
                       others: others.sorted())
    }

    static func lines(_ text: String) -> [String] { text.split(separator: "\n").map(String.init) }

    // MARK: fetch-cli.sh

    // spec-example: citation-order / the hook installs the binary that has the pinned hash and team
    @Test(arguments: [team, "OTHERTEAM9"])
    func `Installs the binary that has the pinned hash and the team of the lock`(lockTeam: String) throws {
        let outcome = try run(lock: Self.lock(team: lockTeam), signer: lockTeam)
        #expect(outcome.exitCode == 0)
        #expect(outcome.binary == .file(content: Self.payload, executable: true))
        #expect(Self.lines(outcome.output) == ["propositions: installed the command-line tool v9.9.9"])
        #expect(outcome.others.isEmpty)
        // One download, and every argument curl got: -q first, redirects followed, HTTPS only, the
        // three limits, the output in the data directory's bin, the release's address. Nothing else.
        let downloads = outcome.calls.filter { $0.hasPrefix("curl") }
        try #require(downloads.count == 1)
        let expected = /curl \[-q\] \[-fsL\] \[--proto\] \[=https\] \[--connect-timeout\] \[5\] \[--max-time\] \[30\] \[--max-filesize\] \[52428800\] \[-o\] \[[^\[\]]*\/propositions-test\/bin\/\.fetch\.[A-Za-z0-9]+\] \[https:\/\/github\.com\/PsychQuantHsu\/propositions-projects\/releases\/download\/propositions-cli-v9\.9\.9\/propositions\]/
        #expect(downloads[0].wholeMatch(of: expected) != nil, "\(downloads[0])")
        #expect(!outcome.ran)
        #expect(outcome.calls.contains("codesign 4 --verify --strict"))
    }

    // spec-example: citation-order / the hook is silent when the pinned binary is already there
    @Test func `Does nothing and prints nothing when the pinned binary is already there`() throws {
        let outcome = try run(existing: .file(Self.payload, mode: 0o755))
        #expect(outcome.exitCode == 0)
        #expect(outcome.output.isEmpty)
        #expect(outcome.calls.isEmpty)
        #expect(outcome.binary == .file(content: Self.payload, executable: true))
        #expect(outcome.others.isEmpty)
    }

    // spec-example: citation-order / the hook replaces what is not the pinned binary
    @Test(arguments: [("cut off", 0o755), (payload, 0o644)])
    func `Replaces a file with other content, or one that cannot be run`(content: String, mode: Int) throws {
        let outcome = try run(existing: .file(content, mode: mode))
        #expect(outcome.exitCode == 0)
        #expect(outcome.binary == .file(content: Self.payload, executable: true))
        #expect(outcome.calls.contains { $0.hasPrefix("curl ") })
        #expect(outcome.others.isEmpty)
    }

    // spec-example: citation-order / the hook leaves the binary of another pin alone
    @Test func `Leaves the binary of another pin where it is`() throws {
        let other = "f".padding(toLength: 64, withPad: "f", startingAt: 0)
        // The lock names another hash; the file at the first pin's path stands for another pin's binary.
        let outcome = try run(lock: Self.lock(hash: other, team: Self.team), existing: .file(Self.payload, mode: 0o755),
                              environment: ["STUB_CURL_FAIL": "1"])
        #expect(outcome.exitCode == 0)
        #expect(outcome.binary == .file(content: Self.payload, executable: true))
        #expect(outcome.output.contains("could not download"))
        #expect(outcome.others.isEmpty)
    }

    // spec-example: citation-order / a failed check leaves no binary
    @Test(arguments: [
        (["STUB_PAYLOAD": "something else\n"], team, "pinned SHA-256"),
        (["STUB_PAYLOAD": ""], team, "pinned SHA-256"),
        ([:], "OTHERTEAM9", "Developer ID signature of the pinned team"),
        (["STUB_BAD_SIGNATURE": "1"], team, "Developer ID signature of the pinned team"),
        (["STUB_CURL_FAIL": "1"], team, "could not download"),
    ] as [([String: String], String, String)])
    func `Installs nothing, and leaves nothing in its place, when a check fails`(
        environment: [String: String], signer: String, message: String
    ) throws {
        let outcome = try run(signer: signer, existing: .file("cut off", mode: 0o755), environment: environment)
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
    func `Leaves everything as it is on another system or in a directory named for another plugin`(
        dataName: String, environment: [String: String]
    ) throws {
        let outcome = try run(dataName: dataName, existing: .file("cut off", mode: 0o755), environment: environment)
        #expect(outcome.exitCode == 0)
        #expect(outcome.output.isEmpty)
        #expect(outcome.calls.isEmpty)
        #expect(outcome.binary == .file(content: "cut off", executable: true))
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
        #expect(outcome.others == ["bin/propositions-\(Self.hash)/inside"])
    }

    static let unusableLocks: [(String?, Int, String)] = [
        ("version=1.0;rm\nsha256=\(hash)\nteam=\(team)\n", 0o644, "version"),
        ("version=1.0\nsha256=\(hash)\nteam=\(team)\n", 0o644, "version"),
        ("version=1..0\nsha256=\(hash)\nteam=\(team)\n", 0o644, "version"),
        ("version=1.0.0.0\nsha256=\(hash)\nteam=\(team)\n", 0o644, "version"),
        ("version=1.0.0\nsha256=abc\nteam=\(team)\n", 0o644, "sha256"),
        ("version=1.0.0\nsha256=\(hash.uppercased())\nteam=\(team)\n", 0o644, "sha256"),
        ("version=9.9.9\nsha256=\(hash)\nteam=\n", 0o644, "team"),
        ("version=9.9.9\nsha256=\(hash)\nteam=short\n", 0o644, "team"),
        ("version=9.9.9\nversion=2.0.0\nsha256=\(hash)\nteam=\(team)\n", 0o644, "form"),
        (goodLock + "extra=1\n", 0o644, "form"),
        (goodLock + "\n", 0o644, "form"),
        (goodLock + "\0", 0o644, "form"),
        ("version=9.9.9\0\nsha256=\(hash)\nteam=\(team)\n", 0o644, "form"),
        ("sha256=\(hash)\nversion=9.9.9\nteam=\(team)\n", 0o644, "version"),
        ("", 0o644, "version"),
        (nil, 0o644, "form"),
        // A file without permission to read is unreadable only to a user who is not root.
    ] + (getuid() == 0 ? [] : [(goodLock, 0o000, "form")])

    // spec-example: citation-order / an unusable lock file fetches nothing
    @Test(arguments: unusableLocks)
    func `Fetches nothing when the lock file is unusable`(lock: String?, mode: Int, part: String) throws {
        let outcome = try run(lock: lock, lockMode: mode)
        #expect(outcome.exitCode == 0)
        #expect(Self.lines(outcome.output).count == 1)
        #expect(outcome.output.contains("no usable \(part)"))
        #expect(outcome.calls.isEmpty)
        #expect(outcome.binary == .nothing)
        #expect(outcome.others.isEmpty)
    }

    @Test func `A lock file without a final newline is read`() throws {
        let outcome = try run(lock: String(Self.goodLock.dropLast()))
        #expect(outcome.binary == .file(content: Self.payload, executable: true))
    }

    // spec-example: citation-order / the repository's lock file has the three fields
    @Test func `The lock file has a version, a hash and the signing team`() throws {
        let lock = try String(contentsOf: repositoryRoot.appendingPathComponent("plugins/propositions/hooks/cli.lock"),
                              encoding: .utf8)
        // Three lines, with or without the newline after the third, and nothing after it.
        var lines = lock.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.count == 4, lines[3].isEmpty { lines.removeLast() }
        try #require(lines.count == 3)
        #expect(lines[0].wholeMatch(of: /version=[0-9]+\.[0-9]+\.[0-9]+/) != nil)
        #expect(lines[1].wholeMatch(of: /sha256=[0-9a-f]{64}/) != nil)
        #expect(lines[2] == "team=6W377FS7BS")
    }

    // MARK: run-cli.sh

    // spec-example: citation-order / the launcher runs the pinned binary with the arguments it is given
    @Test(arguments: [0, 1, 2] as [Int32])
    func `Runs the pinned binary with the arguments it is given and exits as it does`(status: Int32) throws {
        let outcome = try run(script: "run-cli.sh", arguments: ["cite-order", "--tex", "a b.tex"],
                              existing: .file(Self.payload, mode: 0o755), environment: ["STUB_EXIT": "\(status)"])
        #expect(outcome.exitCode == status)
        #expect(outcome.output == "3\n[cite-order]\n[--tex]\n[a b.tex]\n")
        #expect(outcome.ran)
    }

    // spec-example: citation-order / the launcher runs nothing but the pinned binary
    @Test(arguments: [
        (Existing?.none, false, "is not installed"),
        (.file("#!/bin/sh\necho 1\n", mode: 0o755), false, "does not have the pinned SHA-256"),
        (.file(payload, mode: 0o644), false, "is not installed"),
        (.directory, false, "is not installed"),
        (.linkToPinned, false, "is not installed"),
        (.file(payload, mode: 0o755), true, "is not installed"),
    ] as [(Existing?, Bool, String)])
    func `Runs nothing, and says so with exit 3, when the pinned binary is not there`(
        existing: Existing?, binIsLink: Bool, message: String
    ) throws {
        // With a linked `bin`, the matching executable is put behind the link.
        let outcome = try run(script: "run-cli.sh", arguments: ["cite-order"], existing: existing, binIsLink: binIsLink)
        #expect(outcome.exitCode == 3)
        #expect(Self.lines(outcome.output).count == 1)
        #expect(outcome.output.hasPrefix("propositions: NOT RUN ("))
        #expect(outcome.output.contains(message))
        #expect(!outcome.ran)
    }

    @Test(arguments: ["codex-openai-codex", nil] as [String?])
    func `Runs nothing for a directory named for another plugin, or for none`(dataName: String?) throws {
        let outcome = try run(script: "run-cli.sh", arguments: ["cite-order"], dataName: dataName,
                              existing: .file(Self.payload, mode: 0o755))
        #expect(outcome.exitCode == 3)
        #expect(Self.lines(outcome.output).count == 1)
        #expect(outcome.output.hasPrefix("propositions: NOT RUN (the plugin's data directory"))
        #expect(!outcome.ran)
    }

    // spec-example: citation-order / the launcher runs nothing with an unusable lock
    @Test(arguments: unusableLocks.filter { $0.2 != "sha256" })
    func `Runs nothing with an unusable lock, though the binary is there`(lock: String?, mode: Int, part: String) throws {
        // Every row but the two with another `sha256` value. The matching executable is in place,
        // so only the lock's form can stop the launcher.
        let outcome = try run(script: "run-cli.sh", arguments: ["cite-order"], lock: lock, lockMode: mode,
                              existing: .file(Self.payload, mode: 0o755))
        #expect(outcome.exitCode == 3)
        #expect(Self.lines(outcome.output).count == 1)
        #expect(outcome.output.hasPrefix("propositions: NOT RUN ("))
        #expect(outcome.output.contains("cli.lock"))
        #expect(!outcome.ran)
    }

    @Test func `Runs nothing without a subcommand`() throws {
        let outcome = try run(script: "run-cli.sh", existing: .file(Self.payload, mode: 0o755))
        #expect(outcome.exitCode == 3)
        #expect(outcome.output.hasPrefix("propositions: NOT RUN (usage"))
        #expect(!outcome.ran)
    }

    static let launcherCall =
        #"bash "$PLUGIN_ROOT/hooks/run-cli.sh" "${CLAUDE_PLUGIN_DATA}" cite-order --jsonl="$JSONL" --tex="$TEX""#

    /// What keeps a skill's text from calling the tool only through the launcher, once. Inside a
    /// code fence (backticks or tildes, indented or not), the one line that names the tool, its
    /// launcher, a subcommand or the data directory is the launcher call; prose outside a fence
    /// may name them.
    static func launcherProblems(in skill: String) -> [String] {
        var problems: [String] = []
        var fenced = false
        var calls = 0
        let names = ["run-cli.sh", "cite-order", "CLAUDE_PLUGIN_DATA", "propositions outline", "bin/propositions"]
        for line in skill.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            let start = line.drop { $0 == " " || $0 == "\t" }
            if start.hasPrefix("```") || start.hasPrefix("~~~") { fenced.toggle(); continue }
            guard fenced else { continue }
            if line == launcherCall { calls += 1; continue }
            if names.contains(where: line.contains) || line.wholeMatch(of: /\s*propositions(\s.*)?/) != nil
                || line.hasSuffix("\\") && line.contains("propositions") {
                problems.append("a command line other than the launcher call: \(line)")
            }
        }
        if calls != 1 { problems.append("the launcher call occurs \(calls) times") }
        if skill.contains(".claude/plugins/data") { problems.append("a fixed path to a data directory") }
        return problems
    }

    // spec-example: citation-order / the skill calls the binary only through the launcher
    @Test func `The skill calls the binary once, through the launcher`() throws {
        let skill = try String(
            contentsOf: repositoryRoot.appendingPathComponent("plugins/propositions/skills/propositions/SKILL.md"),
            encoding: .utf8)
        #expect(Self.launcherProblems(in: skill) == [])
    }

    @Test(arguments: [
        "```bash\npropositions cite-order  --jsonl \"$JSONL\" --tex \"$TEX\"\n```",
        "```bash\npropositions \\\n  cite-order\n```",
        "```bash\npropositions\n```",
        "```bash\n\"$HOME/.claude/plugins/data/propositions-x/bin/propositions-abc\" cite-order\n```",
        "```bash\n[ -x \"$CLI\" ] && \"$CLI\" cite-order\n```",
        "~~~bash\npropositions cite-order\n~~~",
        "   ```bash\n   propositions cite-order\n   ```",
        "```bash\n\(launcherCall)\n```",
    ])
    func `A second way of calling the tool in the skill is found`(block: String) throws {
        let skill = "Text.\n\n```bash\n\(Self.launcherCall)\n```\n\nMore.\n\n\(block)\n"
        #expect(!Self.launcherProblems(in: skill).isEmpty)
        #expect(Self.launcherProblems(in: "```bash\n\(Self.launcherCall)\n```\n").isEmpty)
        #expect(!Self.launcherProblems(in: "No call at all.\n").isEmpty)
    }
}
