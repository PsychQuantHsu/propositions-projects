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
            if let retire = command as? RetireOptions {
                return ReviseRun.retire(jsonl: retire.jsonl, retirements: retire.retire, since: retire.since,
                                        mechanism: retire.mechanism, match: retire.match, reason: retire.reason,
                                        ref: retire.ref, write: retire.write, workingDirectory: workingDirectory)
            }
            if let check = command as? ReviseCheckOptions {
                return ReviseRun.check(jsonl: check.jsonl, workingDirectory: workingDirectory)
            }
            if let redirect = command as? RedirectOptions {
                return ReviseRun.redirect(jsonl: redirect.jsonl, tex: redirect.tex, write: redirect.write,
                                          workingDirectory: workingDirectory)
            }
            if let prepare = command as? WritePrepareOptions {
                return WriteParagraphRun.prepare(jsonl: prepare.jsonl, tex: prepare.tex, structure: prepare.structure,
                                                 discourse: prepare.discourse, stage: prepare.stage, heading: prepare.heading,
                                                 outline: prepare.outline, outlineParagraph: prepare.outlineParagraph,
                                                 rewrite: prepare.rewrite,
                                                 workingDirectory: workingDirectory)
            }
            if let phrasing = command as? PhrasingOptions {
                return PhrasingRun.run(tex: phrasing.tex, article: phrasing.article, workingDirectory: workingDirectory)
            }
            if let check = command as? WriteCheckOptions {
                return WriteParagraphRun.check(stage: check.stage, workingDirectory: workingDirectory)
            }
            if let commit = command as? WriteCommitOptions {
                return WriteParagraphRun.commit(stage: commit.stage, workingDirectory: workingDirectory)
            }
            if let relocate = command as? RelocateOptions {
                return RelocateRun.run(jsonl: relocate.jsonl, tex: relocate.tex, write: relocate.write,
                                       workingDirectory: workingDirectory)
            }
            if let check = command as? OutlineCheckOptions {
                return OutlineRun.check(directory: check.directory, workingDirectory: workingDirectory)
            }
            if let length = command as? OutlineLengthOptions {
                return OutlineLengthRun.run(directory: length.directory, jsonl: length.jsonl, tex: length.tex, written: length.written, workingDirectory: workingDirectory)
            }
            if let trace = command as? OutlineTraceOptions {
                return OutlineTraceRun.run(directory: trace.directory, jsonl: trace.jsonl, workingDirectory: workingDirectory)
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
        if words.first == "write" {
            switch words.dropFirst().first {
            case "prepare": return Root.helpMessage(for: WritePrepareOptions.self)
            case "check": return Root.helpMessage(for: WriteCheckOptions.self)
            case "commit": return Root.helpMessage(for: WriteCommitOptions.self)
            default: return Root.helpMessage(for: WriteOptions.self)
            }
        }
        if words.first == "revise" {
            switch words.dropFirst().first {
            case "relocate": return Root.helpMessage(for: RelocateOptions.self)
            case "retire": return Root.helpMessage(for: RetireOptions.self)
            case "check": return Root.helpMessage(for: ReviseCheckOptions.self)
            case "redirect": return Root.helpMessage(for: RedirectOptions.self)
            default: return Root.helpMessage(for: ReviseOptions.self)
            }
        }
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
        case "trace": return Root.helpMessage(for: OutlineTraceOptions.self)
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
        subcommands: [CiteOrderOptions.self, LedgerOrderOptions.self, ParagraphsOptions.self, AuditOptions.self, ReviseOptions.self, WriteOptions.self, OutlineOptions.self, PhrasingOptions.self])
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

struct PhrasingOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "phrasing",
        abstract: "List where a manuscript holds a banned phrasing of article.json.",
        discussion: """
            Compares every file of the main file's input tree with the banned list of article.json. \
            Letter case does not count, a run of white space (a line break included) is one space, \
            a comment is not compared, and a phrasing does not run across an empty line. The \
            comparison is literal.
            Exit codes: 0 no occurrence; 1 an occurrence; 2 a file cannot be read, or article.json \
            is not in the format.
            """)

    @Option(help: "The manuscript's main file.")
    var tex: String

    @Option(help: "The article file, article.json.")
    var article: String
}

struct WriteOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "write",
        abstract: "Write one new paragraph into a draft, with its propositions and records, behind one confirmation.",
        subcommands: [WritePrepareOptions.self, WriteCheckOptions.self, WriteCommitOptions.self])
}

struct WritePrepareOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prepare",
        abstract: "Copy the manuscript, the ledger and its sidecars into a staging directory, and say where the paragraph goes.",
        discussion: """
            The paragraph goes after the paragraph that holds the start of the last live \
            proposition in reading order; when the ledger has none, after the last line of text \
            before \\end{document} in the main file. The staging directory has to be empty or new; \
            it gets the input tree under manuscript/, the ledger, _meta.json and the sidecars under \
            ledger/, and write.json, which records the originals and their hashes.
            With --outline and --outline-paragraph, the outline has to pass outline check and the \
            paragraph record's section has to stand as approved; the outline's files are copied \
            under outline/ and may not change, and commit appends a record to \
            outline-trace.jsonl in the outline directory.
            With --rewrite and --outline, the whole outline has to stand as approved; every file of \
            the input tree may change, the ledger keeps every proposition (only location and cites \
            may change, and retired may be added), and the staging directory has to hold \
            outline-map.jsonl, one line per paragraph record written, which commit copies into \
            outline-trace.jsonl.
            Exit codes: 0 staged; 2 a file cannot be read, the staging directory is not empty, \
            the paragraph has nowhere to go, or the outline record cannot be written from.
            """)

    @Option(help: "The ledger.")
    var jsonl: String

    @Option(help: "The manuscript's main file.")
    var tex: String

    @Option(help: "The structure sidecar, structure.json.")
    var structure: String

    @Option(help: "The discourse sidecar, discourse.jsonl.")
    var discourse: String

    @Option(help: "The staging directory, empty or new.")
    var stage: String

    @Flag(help: "Allow one line of a section heading before the paragraph.")
    var heading = false

    @Option(help: "The outline directory, when the paragraph is written from an outline record.")
    var outline: String?

    @Option(name: .customLong("outline-paragraph"), help: "The id of the outline's paragraph record the paragraph is written from.")
    var outlineParagraph: String?

    @Flag(help: "Rewrite the whole manuscript from the outline given with --outline, which has to stand as approved as a whole.")
    var rewrite = false
}

struct OutlineTraceOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "trace",
        abstract: "List which outline record each written paragraph came from, and check the records.",
        discussion: """
            Reads outline-trace.jsonl in the outline directory, which write commit appends to. Each \
            record has to name a paragraph record of the outline and a live proposition of the ledger, \
            and no proposition may be recorded twice.
            Exit codes: 0 every record holds; 1 a record does not; 2 a file cannot be read.
            """)

    @Argument(help: "The directory that holds the outline files.")
    var directory: String

    @Option(help: "The ledger.")
    var jsonl: String
}

struct WriteCheckOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Say whether the staged copies differ from the files only as one new paragraph does.",
        discussion: """
            The staged manuscript file has to be the file with a paragraph added where prepare \
            said, set off by blank lines, and nothing else changed; the staged ledger and discourse \
            sidecar the files with lines added at their ends. Counts the lines that hold \
            {PENDING: …}. The validators are run on the copies by the skill, not by this command.
            Exit codes: 0 the copies are a new paragraph; 1 they are not; 2 the staging directory \
            cannot be read.
            """)

    @Option(help: "The staging directory prepare made.")
    var stage: String
}

struct WriteCommitOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "commit",
        abstract: "Write the staged manuscript file, ledger and sidecars.",
        discussion: """
            Writes only when check passes and every original is as prepare found it, after keeping \
            a copy of each under backup/ in the staging directory. Writes the manuscript file, the \
            ledger, the discourse sidecar and the structure sidecar, in that order; a failure stops \
            and names the files already written.
            Exit codes: 0 written; 2 refused or failed.
            """)

    @Option(help: "The staging directory prepare made.")
    var stage: String
}

struct ReviseOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "revise",
        abstract: "Bring a ledger up to a revised manuscript.",
        subcommands: [RelocateOptions.self, RetireOptions.self, ReviseCheckOptions.self, RedirectOptions.self])
}

struct RelocateOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "relocate",
        abstract: "Find each proposition's text in the revised manuscript, and write where it now stands.",
        discussion: """
            A dry run unless --write is given. Each proposition that is not retired is looked for in \
            every file of the main file's \\input tree, as written, then with runs of white space \
            read as one. It is in place, moved (a new location), rewrapped (a new text with other \
            line breaks, and a new location), ambiguous (in several places outside the file its \
            location names) or missing. Only moved and rewrapped lines are written again.
            Exit codes: 0 every proposition in place, or written with nothing left; 1 something \
            would change, or a proposition is ambiguous or missing; 2 a file cannot be read, a \
            line is not JSON, a proposition has no text, or an argument is wrong.
            """)

    @Option(help: "The ledger.")
    var jsonl: String

    @Option(help: "The manuscript's main file.")
    var tex: String

    @Flag(help: "Write the new locations and texts.")
    var write = false
}

struct RetireOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "retire",
        abstract: "Mark propositions retired, each with the propositions that replace it.",
        discussion: """
            A dry run unless --write is given. Each --retire names a proposition, and after `=` the \
            ids that replace it, separated by commas; none means it was deleted. It gets a retired \
            block with since, mechanism, match, reason, ref when given, and replaced_by (schema \
            v1.8). Every id has to name one live proposition; nothing is written otherwise.
            Exit codes: 0 written, or nothing to change; 1 a dry run; 2 an argument is wrong, an \
            id names no live proposition, or the ledger cannot be read.
            """)

    @Option(help: "The ledger.")
    var jsonl: String

    @Option(help: "<id> or <id>=<new id>,<new id>. Repeat for each proposition.")
    var retire: [String] = []

    @Option(help: "The date the passage left the paper, YYYY-MM-DD.")
    var since: String

    @Option(help: "comment_env, line_comment or removed.")
    var mechanism = "removed"

    @Option(help: "exact or by_reading.")
    var match = "exact"

    @Option(help: "One line on why.")
    var reason: String

    @Option(help: "The issue or commit that retired it.")
    var ref: String?

    @Flag(help: "Write the ledger.")
    var write = false
}

struct ReviseCheckOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Check that every replaced_by names live propositions of the ledger.",
        discussion: """
            Reports each id of a replaced_by that is not a proposition of the ledger, is retired, \
            or is the retired proposition itself, and counts the retirements that are replaced, \
            deleted (an empty list) and without replaced_by.
            Exit codes: 0 no problem; 1 at least one; 2 the ledger cannot be read.
            """)

    @Option(help: "The ledger.")
    var jsonl: String
}

struct RedirectOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "redirect",
        abstract: "Point the citations of retired propositions at the propositions that replace them.",
        discussion: """
            A dry run unless --write is given. A citation of a retired proposition becomes its \
            replacements, those that do not come before the citing proposition in reading order \
            left out; one without replacements is dropped. Other citations are left as they are.
            Exit codes: 0 written, or nothing to change; 1 a dry run that would change the ledger; \
            2 a file cannot be read, a line is not JSON, or an argument is wrong.
            """)

    @Option(help: "The ledger.")
    var jsonl: String

    @Option(help: "The manuscript's main file.")
    var tex: String

    @Flag(help: "Write the ledger.")
    var write = false
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
        subcommands: [OutlineCheckOptions.self, OutlineStatusOptions.self, OutlineLocatorsOptions.self, OutlineTraceOptions.self, OutlineLengthOptions.self])
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

struct OutlineLengthOptions: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "length",
        abstract: "Report the length target of each section, what was written from it, and the totals against the limit.",
        discussion: """
            Prints one line for each section that is not dropped: its id, the part it goes to, its \
            target, and, with --jsonl and --tex, the words written from its paragraph records (as \
            outline-trace.jsonl names them) and how many of its records are written. Then one line \
            for each part, one for the limit of article.json when it has one, and `ok length`. \
            A length over its target or its limit is marked; the exit code does not change. Words \
            are an estimate: mathematics, comments and command names are not counted, and each \
            Chinese character, kana or hangul syllable is one word.
            Exit codes: 0 the report was printed; 2 a file cannot be read, the outline does not \
            pass outline check, or an argument is wrong.
            """)

    @Argument(help: "The directory that holds the outline files.")
    var directory: String

    @Option(help: "The ledger, to count what was written.")
    var jsonl: String?

    @Option(help: "The manuscript's main file, to count what was written.")
    var tex: String?

    @Flag(help: "Count what was written from the documents article.json names as destinations.")
    var written = false
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
