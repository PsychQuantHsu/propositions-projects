import Foundation
import Testing
@testable import PropositionsKit

/// The gates of scripts/release-signed.sh that need no signing identity, run with stand-ins
/// for swift, git, codesign, xcrun, ditto and gh. Nothing is signed, tagged or published.
struct ReleaseScriptTests {
    let script = repositoryRoot.appendingPathComponent("scripts/release-signed.sh").path

    struct Outcome {
        let exitCode: Int32
        let output: String
        let calls: String
    }

    /// Runs the script with stand-in tools. `notary` is the status the stand-in notarytool reports.
    func run(version: String?, notary: String = "Accepted", dirty: Bool = false, tagElsewhere: Bool = false,
             developerID: String? = "TESTID") throws -> Outcome {
        let fm = FileManager.default
        let box = fm.temporaryDirectory.appendingPathComponent("release-test-\(UUID().uuidString)")
        let tools = box.appendingPathComponent("tools")
        let built = box.appendingPathComponent("built")
        try fm.createDirectory(at: tools, withIntermediateDirectories: true)
        try fm.createDirectory(at: built, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: box) }
        let log = box.appendingPathComponent("calls.log").path
        let current = PropositionsVersion.current
        let stubs: [String: String] = [
            "swift": """
                echo "swift $*" >> "\(log)"
                case "$*" in
                  *--show-bin-path*) echo "\(built.path)" ;;
                  build*) printf '#!/bin/sh\\necho \(current)\\n' > "\(built.path)/propositions"; /bin/chmod +x "\(built.path)/propositions" ;;
                esac
                """,
            "git": """
                echo "git $*" >> "\(log)"
                case "$1" in
                  status) [ -z "$STUB_DIRTY" ] || echo " M Sources/changed.swift" ;;
                  rev-parse) case "$*" in
                      *--verify*) [ -n "$STUB_TAG_ELSEWHERE" ] || exit 1 ;;
                      *"^{commit}"*) echo ffffffffffffffff ;;
                      *) echo 0123456789abcdef ;;
                    esac ;;
                esac
                """,
            "codesign": "echo \"codesign $1\" >> \"\(log)\"",
            "ditto": "echo \"ditto\" >> \"\(log)\"; : > \"$4\"",
            "xcrun": "echo \"xcrun $1 $2\" >> \"\(log)\"; echo '{\"id\":\"x\",\"status\":\"\(notary)\"}'",
            "gh": "echo \"gh $1 $2\" >> \"\(log)\"",
        ]
        for (name, body) in stubs {
            let url = tools.appendingPathComponent(name)
            try ("#!/bin/sh\n" + body + "\n").write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script]
        var environment = ["PATH": "\(tools.path):/usr/bin:/bin", "NOTARY_PROFILE": "test-profile",
                           "HOME": box.path, "TMPDIR": box.path]
        if let version { environment["VERSION"] = version }
        if let developerID { environment["DEVELOPER_ID"] = developerID }
        if dirty { environment["STUB_DIRTY"] = "1" }
        if tagElsewhere { environment["STUB_TAG_ELSEWHERE"] = "1" }
        process.environment = environment
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let calls = (try? String(contentsOfFile: log, encoding: .utf8)) ?? ""
        return Outcome(exitCode: process.terminationStatus, output: String(decoding: data, as: UTF8.self), calls: calls)
    }

    // spec-example: citation-order / the release script refuses a version that is not the package's
    @Test func `The release script refuses a version that is not the package's`() throws {
        let outcome = try run(version: "9.9.9")
        #expect(outcome.exitCode == 1)
        #expect(outcome.output.contains("VERSION (9.9.9) differs from Sources/PropositionsKit/Version.swift"))
        #expect(outcome.calls.isEmpty)  // it stopped before any tool ran

        let missing = try run(version: nil)
        #expect(missing.exitCode != 0)
        #expect(missing.output.contains("VERSION is required"))
        #expect(missing.calls.isEmpty)
    }

    // spec-example: citation-order / a notarization that is not accepted publishes nothing
    @Test func `A notarization that is not accepted publishes nothing`() throws {
        let outcome = try run(version: PropositionsVersion.current, notary: "Invalid")
        #expect(outcome.exitCode == 1)
        #expect(outcome.output.contains("notarization was not accepted (status: Invalid)"))
        let calls = outcome.calls.components(separatedBy: "\n")
        let test = try #require(calls.firstIndex { $0.hasPrefix("swift test") })
        let build = try #require(calls.firstIndex { $0.hasPrefix("swift build") })
        let notarize = try #require(calls.firstIndex(of: "xcrun notarytool submit"))
        #expect(test < build && build < notarize)  // the tests ran before the build and the notarization
        #expect(!outcome.calls.contains("git tag"))
        #expect(!outcome.calls.contains("git push"))
        #expect(!outcome.calls.contains("gh release"))
    }

    // spec-example: citation-order / an accepted notarization is tagged and published
    @Test func `An accepted notarization is tagged and published`() throws {
        let outcome = try run(version: PropositionsVersion.current, notary: "Accepted")
        #expect(outcome.exitCode == 0)
        let calls = outcome.calls.components(separatedBy: "\n")
        let test = try #require(calls.firstIndex { $0.hasPrefix("swift test") })
        let notarize = try #require(calls.firstIndex(of: "xcrun notarytool submit"))
        let tag = try #require(calls.firstIndex { $0.hasPrefix("git tag propositions-cli-v\(PropositionsVersion.current)") })
        let release = try #require(calls.firstIndex(of: "gh release create"))
        #expect(test < notarize && notarize < tag && tag < release)
    }

    // spec-example: citation-order / the release script refuses a tree or a tag that is not the commit it builds
    @Test func `The release script refuses a tree or a tag that is not the commit it builds`() throws {
        let dirty = try run(version: PropositionsVersion.current, dirty: true)
        #expect(dirty.exitCode == 1)
        #expect(dirty.output.contains("the working tree is not clean"))
        #expect(!dirty.calls.contains("swift"))            // nothing was tested or built
        #expect(!dirty.calls.contains("gh release"))

        let tagged = try run(version: PropositionsVersion.current, tagElsewhere: true)
        #expect(tagged.exitCode == 1)
        #expect(tagged.output.contains("exists and names another commit"))
        #expect(!tagged.calls.contains("swift"))
        #expect(!tagged.calls.contains("git push"))

        let unsigned = try run(version: PropositionsVersion.current, developerID: nil)
        #expect(unsigned.exitCode != 0)
        #expect(unsigned.output.contains("DEVELOPER_ID is required"))
        #expect(unsigned.calls.isEmpty)
    }
}
