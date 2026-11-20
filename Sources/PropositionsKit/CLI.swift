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
            if let check = command as? OutlineCheckOptions {
                return OutlineRun.check(directory: check.directory, workingDirectory: workingDirectory)
            }
            if let status = command as? OutlineStatusOptions {
                return OutlineRun.status(directory: status.directory, workingDirectory: workingDirectory)
            }
            if let locators = command as? OutlineLocatorsOptions {
                return OutlineRun.locators(
                    directory: locators.directory, root: locators.root, workingDirectory: workingDirectory)
            }
            // No subcommand, or help was asked for (the parser hands back its help command for
            // `--help`, `-h` and `help`): print the help of the command that was named.
            return CommandResult(stdout: lines(help(for: arguments)), exitCode: 0)
        } catch {
            let message = lines(Root.fullMessage(for: error))
            let code = Root.exitCode(for: error)
            if code == .success { return CommandResult(stdout: message, exitCode: 0) }  // --help, --version
            return CommandResult(stderr: message, exitCode: code == .validationFailure ? 2 : code.rawValue)
        }
    }

    private static func help(for arguments: [String]) -> String {
        if arguments.contains("cite-order") { return Root.helpMessage(for: CiteOrderOptions.self) }
        guard arguments.contains("outline") else { return Root.helpMessage() }
        if arguments.contains("check") { return Root.helpMessage(for: OutlineCheckOptions.self) }
        if arguments.contains("status") { return Root.helpMessage(for: OutlineStatusOptions.self) }
        if arguments.contains("locators") { return Root.helpMessage(for: OutlineLocatorsOptions.self) }
        return Root.helpMessage(for: OutlineOptions.self)
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
        subcommands: [CiteOrderOptions.self, OutlineOptions.self])
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

struct OutlineOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "outline",
        abstract: "Mechanical checks for the three files of an article outline.",
        subcommands: [OutlineCheckOptions.self, OutlineStatusOptions.self, OutlineLocatorsOptions.self])
}

struct OutlineCheckOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Check the format of the outline files in a directory.",
        discussion: """
            Reports what can be decided from the three files alone: lines that are not JSON \
            objects, keys written twice, required keys and their types, ids, the order of the \
            paragraph records, parent and uses, and the shape of locators. It does not resolve a \
            locator and does not judge a sentence.
            Exit codes: 0 nothing to report; 1 at least one finding; 2 a file is missing or an \
            argument is wrong.
            """)

    @Argument(help: "The directory that holds the outline files.")
    var directory: String
}

struct OutlineStatusOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Say which sections still stand as approved, and whether their order does.",
        discussion: """
            Prints one line for each section, one for the order of sections, one for the sections \
            removed since their approval, one for the paragraph records that name no section, \
            two counts, and `ok status`. Records are compared as JSON values.
            Exit codes: 0 the status was printed; 2 a file is missing, a line is not a record, or \
            an argument is wrong.
            """)

    @Argument(help: "The directory that holds the outline files.")
    var directory: String
}

struct OutlineLocatorsOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "locators",
        abstract: "Check that every locator of the paragraph file names exactly one place.",
        discussion: """
            A locator's file is a regular file inside the root, outside every .git directory, \
            that git lists. A label and opening words are counted with every run of white space \
            as one space, from every position. Runs git.
            Exit codes: 0 every locator resolves; 1 at least one does not; 2 a file is missing \
            or an argument is wrong.
            """)

    @Argument(help: "The directory that holds the outline files.")
    var directory: String

    @Option(help: "The root of the repository, from which a locator's file is written.")
    var root: String
}
