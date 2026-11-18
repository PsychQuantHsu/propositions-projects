import ArgumentParser
import Foundation

/// The `propositions` command: its arguments, what it prints and its exit code.
///
/// Everything is decided here so that it can be tested without starting a process; the
/// executable prints the result and exits. Wrong arguments exit with 2, as the Python tools
/// of this repository do (swift-argument-parser's own default is 64).
public enum PropositionsCLI {
    public static func run(_ arguments: [String], workingDirectory: URL) -> CommandResult {
        do {
            let command = try Root.parseAsRoot(arguments)
            if let citeOrder = command as? CiteOrderOptions {
                return CiteOrderRun.run(
                    jsonl: citeOrder.jsonl, tex: citeOrder.tex, json: citeOrder.json,
                    workingDirectory: workingDirectory)
            }
            // The root command with no subcommand: print its help.
            return CommandResult(stdout: lines(Root.helpMessage()), exitCode: 0)
        } catch {
            let message = lines(Root.fullMessage(for: error))
            let code = Root.exitCode(for: error)
            if code == .success { return CommandResult(stdout: message, exitCode: 0) }  // --help, --version
            return CommandResult(stderr: message, exitCode: code == .validationFailure ? 2 : code.rawValue)
        }
    }

    private static func lines(_ text: String) -> [String] {
        text.isEmpty ? [] : text.components(separatedBy: "\n")
    }
}

struct Root: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "propositions",
        abstract: "Mechanical checks for a propositions ledger.",
        version: PropositionsVersion.current,
        subcommands: [CiteOrderOptions.self])
}

struct CiteOrderOptions: ParsableCommand {
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
}
