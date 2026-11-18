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

    public static func run(jsonl: String, tex: String, json: Bool) -> CommandResult {
        guard let text = try? String(contentsOf: URL(fileURLWithPath: jsonl), encoding: .utf8) else {
            return CommandResult(stderr: ["cite-order: cannot read the ledger \(jsonl)"], exitCode: 2)
        }
        guard FileManager.default.fileExists(atPath: tex) else {
            return CommandResult(stderr: ["cite-order: cannot read the main file \(tex)"], exitCode: 2)
        }
        let order: ReadingOrder
        do {
            order = try ReadingOrder(mainFile: URL(fileURLWithPath: tex))
        } catch {
            return CommandResult(stderr: ["cite-order: \(error)"], exitCode: 2)
        }
        let notes = order.skippedImports.map {
            "[warn] non-standard import macro skipped at \($0) (\\subimport/\\subfile unsupported)"
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
