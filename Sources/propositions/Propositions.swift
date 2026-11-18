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
        } catch let stop as Stop {
            FileHandle.standardError.write(Data((stop.message + "\n").utf8))
            Foundation.exit(stop.code)
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

    @Option(help: "The ledger (default: manuscript/propositions/main.jsonl).")
    var jsonl = "manuscript/propositions/main.jsonl"

    @Option(help: "The manuscript's main file (default: manuscript/main.tex).")
    var tex = "manuscript/main.tex"

    @Flag(help: "Print one JSON object instead of lines.")
    var json = false

    func run() throws {
        guard let text = try? String(contentsOf: URL(fileURLWithPath: jsonl), encoding: .utf8) else {
            throw Stop(code: 2, message: "cite-order: cannot read the ledger \(jsonl)")
        }
        guard FileManager.default.fileExists(atPath: tex) else {
            throw Stop(code: 2, message: "cite-order: cannot read the main file \(tex)")
        }
        let order: ReadingOrder
        do {
            order = try ReadingOrder(mainFile: URL(fileURLWithPath: tex))
        } catch {
            throw Stop(code: 2, message: "cite-order: \(error)")
        }
        for skipped in order.skippedImports {
            FileHandle.standardError.write(Data(
                "[warn] non-standard import macro skipped at \(skipped) (\\subimport/\\subfile unsupported)\n".utf8))
        }
        let report = CiteOrder.check(ledger: Ledger(jsonl: text), order: order)
        if json {
            print(try CiteOrder.renderJSON(report))
        } else {
            CiteOrder.render(report).forEach { print($0) }
        }
        if !report.isComplete { throw ExitCode(1) }
    }
}

/// An error that carries the message to print and the exit code to use.
struct Stop: Error, CustomStringConvertible {
    let code: Int32
    let message: String
    var description: String { message }
}
