import Foundation
import PropositionsKit

// The Swift package declares this executable so that tschema-check has a home in it
// (.claude/rules/swift-is-the-implementation-language.md). What it does is in PropositionsKit.
let result = TschemaCheckPlaceholder.run(Array(CommandLine.arguments.dropFirst()))
result.stdout.forEach { print($0) }
result.stderr.forEach { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
exit(result.exitCode)
