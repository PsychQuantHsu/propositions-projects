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
            if let ledgerOrder = command as? LedgerOrderOptions {
                return LedgerOrderRun.run(
                    jsonl: ledgerOrder.jsonl, tex: ledgerOrder.tex, write: ledgerOrder.write,
                    workingDirectory: workingDirectory)
            }
            if let paragraphs = command as? ParagraphsOptions {
                return ParagraphsRun.run(
                    jsonl: paragraphs.jsonl, tex: paragraphs.tex, structure: paragraphs.structure,
                    workingDirectory: workingDirectory)
            }
            if let audit = command as? AuditSymbolsOptions {
                return AuditRun.run(.symbols, manuscriptRoot: audit.common.manuscriptRoot, tex: audit.common.tex,
                                    format: audit.common.reportFormat, workingDirectory: workingDirectory)
            }
            if let audit = command as? AuditCitationsOptions {
                return AuditRun.run(.citations, manuscriptRoot: audit.common.manuscriptRoot, tex: audit.common.tex,
                                    format: audit.common.reportFormat, workingDirectory: workingDirectory)
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
        // The command is named by the first words, not by any argument that happens to read
        // like one: a directory can be called `status`.
        let words = Array((arguments.first == "help" ? Array(arguments.dropFirst()) : arguments).prefix { !$0.hasPrefix("-") })
        if words.first == "cite-order" { return Root.helpMessage(for: CiteOrderOptions.self) }
        if words.first == "ledger-order" { return Root.helpMessage(for: LedgerOrderOptions.self) }
        if words.first == "paragraphs" { return Root.helpMessage(for: ParagraphsOptions.self) }
        if words.first == "audit" {
            switch words.dropFirst().first {
            case "symbols": return Root.helpMessage(for: AuditSymbolsOptions.self)
            case "citations": return Root.helpMessage(for: AuditCitationsOptions.self)
            default: return Root.helpMessage(for: AuditOptions.self)
            }
        }
        guard words.first == "outline" else { return Root.helpMessage() }
        switch words.dropFirst().first {
        case "check": return Root.helpMessage(for: OutlineCheckOptions.self)
        case "status": return Root.helpMessage(for: OutlineStatusOptions.self)
        case "locators": return Root.helpMessage(for: OutlineLocatorsOptions.self)
        default: return Root.helpMessage(for: OutlineOptions.self)
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
        subcommands: [CiteOrderOptions.self, LedgerOrderOptions.self, ParagraphsOptions.self, AuditOptions.self, OutlineOptions.self])
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

struct LedgerOrderOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ledger-order",
        abstract: "Say whether a ledger's lines are in reading order, and put them in it.",
        discussion: """
            A dry run unless --write is given. Lines are moved, never edited. A retired \
            proposition, a comment and an empty line stay behind the proposition they followed. \
            Propositions that start on the same line keep their order and are reported.
            Without --tex the order is that of the first line of each location, and a location \
            that names another file is refused. With --tex the order is the manuscript's reading \
            order through its \\input tree, so a manuscript of several files can be ordered.
            Exit codes: 0 in reading order, or written; 1 a dry run in which lines would move; \
            2 a file cannot be read, a line is not JSON, a location cannot be used, or an \
            argument is wrong.
            """)

    @Option(help: "The ledger.")
    var jsonl: String

    @Option(help: "The manuscript's main file. Needed for a manuscript of several files.")
    var tex: String?

    @Flag(help: "Rewrite the ledger.")
    var write = false
}

struct ParagraphsOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "paragraphs",
        abstract: "Propose the paragraph plan of a structure sidecar from the TeX source.",
        discussion: """
            Each run of non-blank lines of a file is a paragraph. A proposition belongs to the \
            paragraph that holds the first line of its location; paragraphs without a proposition \
            are skipped. With --structure, a proposition that a section starts with starts a \
            paragraph. A location may name any file of the main file's \\input tree; a paragraph \
            does not run from one file into another. Propositions are taken in the ledger's \
            order. Prints the `paragraphs` list as JSON.
            Exit codes: 0 the list was printed; 2 an input cannot be read, a location cannot be \
            used, or an argument is wrong.
            """)

    @Option(help: "The ledger.")
    var jsonl: String

    @Option(help: "The manuscript's main file.")
    var tex: String

    @Option(help: "A structure sidecar whose sections the paragraphs must not cross.")
    var structure: String?
}

struct AuditOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "audit",
        abstract: "Cross-artifact audits of a manuscript: paths of working files, and citations.",
        subcommands: [AuditSymbolsOptions.self, AuditCitationsOptions.self])
}

struct AuditCommonOptions: ParsableArguments {
    @Option(help: "The directory of the manuscript. Reports name files from it.")
    var manuscriptRoot: String

    @Option(help: "The manuscript's main file (default: main.tex in the manuscript directory).")
    var tex: String?

    @Option(help: "md or json.")
    var reportFormat = "md"
}

struct AuditSymbolsOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "symbols",
        abstract: "Rule R1: a path to a working file written in the manuscript.",
        discussion: """
            Reads every file of the main file's \\input tree, and looks for a path with a code \
            or note extension in \\texttt, \\url, \\path, \\href, \\verb, \\lstinline, \
            verbatim-like environments and running text. Comments are not read.
            Exit codes: 0 no finding; 1 at least one finding; 2 a file cannot be read, or an \
            argument is wrong.
            """)

    @OptionGroup var common: AuditCommonOptions
}

struct AuditCitationsOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "citations",
        abstract: "Rules R2 and R2-bis: leaked labels in citations, and cited keys against the bibliography.",
        discussion: """
            Reads every file of the main file's \\input tree and the bibliography files it \
            declares (\\bibliography, \\addbibresource and the like); when it declares none, \
            refs.bib in the manuscript directory. Every entry type counts but @string, @comment \
            and @preamble. A citation command may have two optional arguments and, for \\cites \
            and its kin, several groups of keys.
            Exit codes: 0 no finding; 1 at least one finding; 2 a file cannot be read, or an \
            argument is wrong.
            """)

    @OptionGroup var common: AuditCommonOptions
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
