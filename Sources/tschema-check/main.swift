import Foundation
import PropositionsKit

// The Swift package declares this executable so that tschema-check has a home in it
// (.claude/rules/swift-is-the-implementation-language.md). It validates nothing yet: the
// validation is still plugins/tschema-check/scripts/validate-tschema.py.
let arguments = CommandLine.arguments.dropFirst()
if arguments == ["--version"] {
    print(PropositionsVersion.current)
    exit(0)
}
FileHandle.standardError.write(Data("""
    tschema-check \(PropositionsVersion.current): this executable validates nothing yet.
    Validation is still done by plugins/tschema-check/scripts/validate-tschema.py.

    """.utf8))
exit(arguments.isEmpty || arguments == ["--help"] ? 0 : 2)
