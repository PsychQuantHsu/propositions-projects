import Foundation

/// The commands `revise retire`, `revise check` and `revise redirect`.
public enum ReviseRun {
    static func resolve(_ path: String, _ directory: URL) -> URL {
        path.hasPrefix("/") ? URL(fileURLWithPath: path) : directory.appendingPathComponent(path)
    }

    static func refuse(_ message: String) -> CommandResult { CommandResult(stderr: ["error: \(message)"], exitCode: 2) }

    static func readLedger(_ jsonl: String, _ directory: URL) -> LedgerOrder.Snapshot? {
        LedgerOrder.read(resolve(jsonl, directory))
    }

    /// Writes the ledger when `write` is set and it changed. A dry run that would change it exits
    /// with 1; a write, and a run that changes nothing, with 0.
    static func finish(_ out: [String], new: Data, snapshot: LedgerOrder.Snapshot, jsonl: String, write: Bool,
                       directory: URL, notes: [String] = []) -> CommandResult {
        guard new != snapshot.data else { return CommandResult(stdout: out + ["nothing to change"], stderr: notes, exitCode: 0) }
        guard write else { return CommandResult(stdout: out, stderr: notes, exitCode: 1) }
        do {
            let synced = try LedgerOrder.write(new, to: resolve(jsonl, directory), replacing: snapshot)
            let warn = synced ? [] : ["[warn] the ledger was replaced, but its directory could not be synced"]
            return CommandResult(stdout: out + ["written: \(CiteOrder.visible(jsonl))"], stderr: notes + warn, exitCode: 0)
        } catch let failure as LedgerOrder.Failure {
            return CommandResult(stdout: out, stderr: notes + ["error: \(failure.message)"], exitCode: 2)
        } catch {
            return CommandResult(stdout: out, stderr: notes + ["error: the ledger could not be written"], exitCode: 2)
        }
    }

    /// Exit codes: 0 written; 1 a dry run; 2 an argument is wrong, an id does not name one live
    /// proposition, a replacement is not a live proposition, or the ledger cannot be read.
    public static func retire(jsonl: String, retirements: [String], since: String, mechanism: String, match: String,
                              reason: String, ref: String?, write: Bool, workingDirectory: URL) -> CommandResult {
        guard !retirements.isEmpty else { return refuse("name at least one proposition with --retire") }
        guard let snapshot = readLedger(jsonl, workingDirectory) else {
            return refuse("ledger not found, or not a regular file that can be read: \(CiteOrder.visible(jsonl))")
        }
        do {
            let (new, out) = try ReviseLedger.retire(snapshot.data, retirements: retirements.map(ReviseLedger.retirement),
                                                     since: since, mechanism: mechanism, match: match, reason: reason, ref: ref)
            return finish(out, new: new, snapshot: snapshot, jsonl: jsonl, write: write, directory: workingDirectory)
        } catch let failure as Revise.Failure {
            return refuse(failure.message)
        } catch {
            return refuse("the ledger could not be read")
        }
    }

    /// Exit codes: 0 every `replaced_by` names live propositions; 1 at least one does not; 2 the
    /// ledger cannot be read.
    public static func check(jsonl: String, workingDirectory: URL) -> CommandResult {
        guard let snapshot = readLedger(jsonl, workingDirectory) else {
            return refuse("ledger not found, or not a regular file that can be read: \(CiteOrder.visible(jsonl))")
        }
        do {
            let result = try ReviseLedger.check(snapshot.data)
            let summary = "\(result.replaced) replaced, \(result.deleted) deleted, \(result.unrecorded) without replaced_by, "
                + "\(result.problems.count) problem(s)"
            return CommandResult(stdout: result.problems + [summary], exitCode: result.problems.isEmpty ? 0 : 1)
        } catch let failure as Revise.Failure {
            return refuse(failure.message)
        } catch {
            return refuse("the ledger could not be read")
        }
    }

    /// Exit codes: 0 written, or nothing to redirect; 1 a dry run that would change the ledger;
    /// 2 a file cannot be read, a line is not JSON, or an argument is wrong.
    public static func redirect(jsonl: String, tex: String, write: Bool, workingDirectory: URL) -> CommandResult {
        guard let snapshot = readLedger(jsonl, workingDirectory) else {
            return refuse("ledger not found, or not a regular file that can be read: \(CiteOrder.visible(jsonl))")
        }
        let main = resolve(tex, workingDirectory)
        guard Audit.text(of: main) != nil else { return refuse("cannot read the main file \(CiteOrder.visible(tex))") }
        do {
            let order: ReadingOrder
            do { order = try ReadingOrder(mainFile: main) } catch { throw Revise.Failure(message: CiteOrder.visible("\(error)")) }
            let (new, out, unplaced) = try ReviseLedger.redirect(snapshot.data, order: order)
            let notes = unplaced.map { "[warn] \($0) has no location in the input tree: the replacements it cites are not checked for order" }
            return finish(out, new: new, snapshot: snapshot, jsonl: jsonl, write: write, directory: workingDirectory, notes: notes)
        } catch let failure as Revise.Failure {
            return refuse(failure.message)
        } catch {
            return refuse("the ledger could not be read")
        }
    }
}
