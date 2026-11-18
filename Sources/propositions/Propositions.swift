import ArgumentParser
import Foundation
import PropositionsKit

@main
struct Propositions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "propositions",
        abstract: "Mechanical checks for a propositions ledger.",
        version: PropositionsVersion.current,
        subcommands: [CiteOrderCommand.self])

    /// Wrong arguments exit with 2, as the Python tools of this repository do
    /// (swift-argument-parser's own default is 64).
    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch {
            if exitCode(for: error) == .validationFailure {
                FileHandle.standardError.write(Data((fullMessage(for: error) + "\n").utf8))
                Foundation.exit(2)
            }
            exit(withError: error)  // --help, --version and ExitCode(1)
        }
    }
}

struct CiteOrderCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cite-order",
        abstract: "Warn about every citation of a proposition that comes later in reading order.",
        discussion: """
            Reading order is taken from each proposition's location and the manuscript's \\input \
            tree, never from the order of the ledger's lines. Warnings do not fail the command.
            Exit codes: 0 no warning, or warnings only; 1 something could not be read, so the \
            check is incomplete; 2 a file is missing, the input tree cannot be read, or an \
            argument is wrong.
            """)

    @Option(help: "The ledger.")
    var jsonl = CiteOrderRun.defaultLedger

    @Option(help: "The manuscript's main file.")
    var tex = CiteOrderRun.defaultMainFile

    @Flag(help: "Print one JSON object instead of lines.")
    var json = false

    func run() throws {
        let result = CiteOrderRun.run(jsonl: jsonl, tex: tex, json: json)
        result.stdout.forEach { print($0) }
        result.stderr.forEach { FileHandle.standardError.write(Data(($0 + "\n").utf8)) }
        if result.exitCode != 0 { throw ExitCode(result.exitCode) }
    }
}
