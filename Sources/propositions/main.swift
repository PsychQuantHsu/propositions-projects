import Foundation
import PropositionsKit

// What the command does is in PropositionsKit (PropositionsCLI); this file prints and exits.
let result = PropositionsCLI.run(
    Array(CommandLine.arguments.dropFirst()),
    workingDirectory: URL(fileURLWithPath: FileManager.default.currentDirectoryPath))
result.stdout.forEach { print($0) }
result.stderr.forEach { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
exit(result.exitCode)
