import Foundation

/// What a command prints and the exit code it asks for. The executables only print this and
/// exit, so that the behaviour a specification states can be tested without starting a process.
public struct CommandResult: Equatable, Sendable {
    public let stdout: [String]
    public let stderr: [String]
    public let exitCode: Int32

    public init(stdout: [String] = [], stderr: [String] = [], exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

/// `propositions cite-order`.
///
/// Exit codes: 0 when nothing is forward or there are warnings only; 1 when something could
/// not be read, so the check is incomplete; 2 when the ledger or the main file cannot be
/// read or the input tree cannot be resolved.
public enum CiteOrderRun {
    public static let defaultLedger = "manuscript/propositions/main.jsonl"
    public static let defaultMainFile = "manuscript/main.tex"

    /// Paths that are not absolute are taken from `workingDirectory`. Messages show a path as
    /// it was given, and text that comes from a file with its control characters escaped.
    public static func run(jsonl: String, tex: String, json: Bool, workingDirectory: URL) -> CommandResult {
        func resolve(_ path: String) -> URL {
            path.hasPrefix("/") ? URL(fileURLWithPath: path) : workingDirectory.appendingPathComponent(path)
        }
        let ledgerURL = resolve(jsonl)
        let mainURL = resolve(tex)
        guard let text = try? String(contentsOf: ledgerURL, encoding: .utf8) else {
            return CommandResult(stderr: ["cite-order: cannot read the ledger \(jsonl)"], exitCode: 2)
        }
        guard FileManager.default.fileExists(atPath: mainURL.path) else {
            return CommandResult(stderr: ["cite-order: cannot read the main file \(tex)"], exitCode: 2)
        }
        let order: ReadingOrder
        do {
            order = try ReadingOrder(mainFile: mainURL)
        } catch {
            return CommandResult(stderr: ["cite-order: \(CiteOrder.visible("\(error)"))"], exitCode: 2)
        }
        let notes = order.skippedImports.map {
            "[warn] non-standard import macro skipped at \(CiteOrder.visible($0)) (\\subimport/\\subfile/\\import unsupported)"
        }
        let report = CiteOrder.check(ledger: Ledger(jsonl: text), order: order)
        let lines: [String]
        if json {
            guard let object = try? CiteOrder.renderJSON(report) else {
                return CommandResult(stderr: notes + ["cite-order: the report could not be written as JSON"], exitCode: 2)
            }
            lines = [object]
        } else {
            lines = CiteOrder.render(report)
        }
        return CommandResult(stdout: lines, stderr: notes, exitCode: report.isComplete ? 0 : 1)
    }
}

/// `tschema-check`, which validates nothing yet: the validation is still the Python script
/// plugins/tschema-check/scripts/validate-tschema.py. Asked to validate, it says so and fails.
public enum TschemaCheckPlaceholder {
    public static func run(_ arguments: [String]) -> CommandResult {
        if arguments == ["--version"] {
            return CommandResult(stdout: [PropositionsVersion.current], exitCode: 0)
        }
        let message = [
            "tschema-check \(PropositionsVersion.current): this executable validates nothing yet.",
            "Validation is still done by plugins/tschema-check/scripts/validate-tschema.py.",
        ]
        return CommandResult(stderr: message, exitCode: arguments.isEmpty || arguments == ["--help"] ? 0 : 2)
    }
}

/// `propositions outline check`, `status` and `locators`.
public enum OutlineRun {
    private static func resolve(_ path: String, _ workingDirectory: URL) -> URL {
        path.hasPrefix("/") ? URL(fileURLWithPath: path) : workingDirectory.appendingPathComponent(path)
    }

    private static func read(_ directory: String, _ workingDirectory: URL, _ name: String)
        -> (Outline?, CommandResult?)
    {
        do {
            return (try Outline(directory: resolve(directory, workingDirectory)), nil)
        } catch {
            return (nil, CommandResult(stderr: ["outline \(name): \(error) in \(CiteOrder.visible(directory))"], exitCode: 2))
        }
    }

    public static func check(directory: String, workingDirectory: URL) -> CommandResult {
        let (outline, failure) = read(directory, workingDirectory, "check")
        guard let outline else { return failure! }
        let findings = OutlineCheck.findings(outline)
        if findings.isEmpty { return CommandResult(stdout: ["ok outline check"], exitCode: 0) }
        return CommandResult(stdout: findings, exitCode: 1)
    }

    public static func status(directory: String, workingDirectory: URL) -> CommandResult {
        let (outline, failure) = read(directory, workingDirectory, "status")
        guard let outline else { return failure! }
        do {
            return CommandResult(stdout: try OutlineStatus.lines(outline), exitCode: 0)
        } catch {
            return CommandResult(stderr: ["outline status: \(error)"], exitCode: 2)
        }
    }

    public static func locators(directory: String, root: String, workingDirectory: URL) -> CommandResult {
        let (outline, failure) = read(directory, workingDirectory, "locators")
        guard let outline else { return failure! }
        let rootURL = resolve(root, workingDirectory)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return CommandResult(stderr: ["outline locators: the root \(CiteOrder.visible(root)) is not a directory"], exitCode: 2)
        }
        guard OutlineLocators.isWorkTreeRoot(rootURL) else {
            return CommandResult(stderr: ["outline locators: the root \(CiteOrder.visible(root)) is not the root of a git repository"], exitCode: 2)
        }
        let findings = OutlineLocators.findings(paragraphs: outline.paragraphs, root: rootURL)
        if findings.isEmpty { return CommandResult(stdout: ["ok locators"], exitCode: 0) }
        return CommandResult(stdout: findings, exitCode: 1)
    }
}
