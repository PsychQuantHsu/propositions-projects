import Foundation
import CryptoKit

/// `propositions write prepare|check|commit`: write one new paragraph into a draft, with its
/// propositions and its structure records, behind one confirmation (issue 49).
///
/// `prepare` copies the manuscript's input tree, the ledger and its two structure sidecars into a
/// staging directory and records where the paragraph goes. The paragraph, its propositions and
/// its records are made in the copies. `check` says whether the copies differ from the files only
/// as a new paragraph may make them differ. `commit` writes the four changed files, only when the
/// files are as `prepare` found them, after keeping a copy of each.
public enum WriteParagraph {
    public struct Failure: Error, Equatable {
        public let message: String
    }

    /// The written form of a placeholder: what is still to be supplied, which the paragraph does
    /// not invent (a result, a number, a citation).
    public static let placeholder = "{PENDING:"

    /// What `prepare` records in the staging directory.
    struct Manifest: Codable, Equatable {
        /// The four files a paragraph changes, by role: `manuscript`, `ledger`, `structure`, `discourse`.
        var originals: [String: String]
        /// Their copies, by the same roles.
        var staged: [String: String]
        var hashes: [String: String]
        /// The file of the input tree that gets the paragraph, as a location names it, and the line
        /// after which the paragraph goes.
        var file: String
        var after: Int
        /// The staged main file and ledger, for the checks the skill runs.
        var stagedMain: String
        var stagedMeta: String?
    }

    static let roles = ["manuscript", "ledger", "discourse", "structure"]

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func read(_ path: String) throws -> Data {
        guard let snapshot = LedgerOrder.read(URL(fileURLWithPath: path)) else {
            throw Failure(message: "cannot read \(CiteOrder.visible(path))")
        }
        return snapshot.data
    }

    /// The lines of a text, split as the tool that writes `location` splits them.
    static func lines(_ data: Data) -> [String] {
        LatexLine.splitLines(String(decoding: data, as: UTF8.self))
    }

    // MARK: prepare

    static func prepare(ledger: URL, main: URL, structure: URL, discourse: URL, stage: URL) throws -> (Manifest, [String]) {
        let fm = FileManager.default
        if fm.fileExists(atPath: stage.path), let items = try? fm.contentsOfDirectory(atPath: stage.path), !items.isEmpty {
            throw Failure(message: "the staging directory \(CiteOrder.visible(stage.path)) is not empty")
        }
        for (url, what) in [(ledger, "ledger"), (structure, "structure sidecar"), (discourse, "discourse sidecar")] {
            guard LedgerOrder.read(url) != nil else { throw Failure(message: "cannot read the \(what) \(CiteOrder.visible(url.path))") }
        }
        let order: ReadingOrder
        do { order = try ReadingOrder(mainFile: main) } catch { throw Failure(message: CiteOrder.visible("\(error)")) }
        let mainDirectory = main.resolvingSymlinksInPath().standardizedFileURL.deletingLastPathComponent()
        let ledgerLines = try ReviseLedger.lines(try read(ledger.path))
        // The last live proposition in reading order.
        var last: (position: [Int], file: String?, line: Int, id: String)?
        var retiredLater: [(file: String?, line: Int)] = []
        for line in ledgerLines {
            guard let id = line.id, let location = line.location else { continue }
            if line.isRetired { retiredLater.append((location.file, location.start)); continue }
            guard let position = order.position(file: location.file, line: location.start) else {
                throw Failure(message: "the location of \(CiteOrder.visible(id)) is not in the input tree")
            }
            if last == nil || ReadingOrder.precedes(last!.position, position) {
                last = (position, location.file, location.start, id)
            }
        }
        guard let last else { throw Failure(message: "the ledger has no live proposition to write after") }
        let key = last.file.flatMap { $0 == "main.tex" ? nil : ReadingOrder.normalise($0) }
        let fileURL = key.map { mainDirectory.appendingPathComponent($0) } ?? main.resolvingSymlinksInPath()
        let fileLines = lines(try read(fileURL.path))
        let runs = Paragraphs.runs(fileLines)
        guard last.line <= runs.count, let run = runs[last.line - 1] else {
            throw Failure(message: "the last proposition, \(CiteOrder.visible(last.id)), does not start inside a paragraph")
        }
        var end = last.line
        while end < runs.count, runs[end] == run { end += 1 }
        var notes: [String] = []
        let fileName = key ?? "main.tex"
        for item in retiredLater {
            let name = item.file.flatMap { $0 == "main.tex" ? nil : ReadingOrder.normalise($0) } ?? "main.tex"
            if name == fileName, item.line > end {
                notes.append("[warn] a retired proposition is located at \(CiteOrder.visible(name)):L\(item.line), after the new paragraph: its location will no longer name its old lines")
            }
        }
        // Copy the tree, the ledger, _meta.json and the sidecars.
        let manuscriptDir = stage.appendingPathComponent("manuscript")
        let ledgerDir = stage.appendingPathComponent("ledger")
        try fm.createDirectory(at: manuscriptDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: ledgerDir, withIntermediateDirectories: true)
        let mainName = main.resolvingSymlinksInPath().lastPathComponent
        for (index, name) in order.files.enumerated() {
            let source = index == 0 ? main.resolvingSymlinksInPath() : mainDirectory.appendingPathComponent(name)
            let relative = index == 0 ? mainName : name
            guard !relative.split(separator: "/").contains("..") else {
                throw Failure(message: "\(CiteOrder.visible(name)) is outside the main file's directory; it cannot be staged")
            }
            let target = manuscriptDir.appendingPathComponent(relative)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try read(source.path).write(to: target)
        }
        let meta = ledger.deletingLastPathComponent().appendingPathComponent("_meta.json")
        var stagedMeta: String?
        if let data = LedgerOrder.read(meta)?.data {
            let target = ledgerDir.appendingPathComponent("_meta.json")
            try data.write(to: target)
            stagedMeta = target.path
        }
        let originals = ["manuscript": fileURL.path, "ledger": ledger.path, "structure": structure.path, "discourse": discourse.path]
        var staged: [String: String] = [:]
        var hashes: [String: String] = [:]
        for role in roles {
            let data = try read(originals[role]!)
            hashes[role] = sha256(data)
            if role == "manuscript" {
                staged[role] = manuscriptDir.appendingPathComponent(key ?? mainName).path
            } else {
                let target = ledgerDir.appendingPathComponent(URL(fileURLWithPath: originals[role]!).lastPathComponent)
                try data.write(to: target)
                staged[role] = target.path
            }
        }
        let manifest = Manifest(originals: originals, staged: staged, hashes: hashes, file: fileName, after: end,
                                stagedMain: manuscriptDir.appendingPathComponent(mainName).path, stagedMeta: stagedMeta)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try (encoder.encode(manifest) + Data("\n".utf8)).write(to: stage.appendingPathComponent("write.json"))
        return (manifest, notes)
    }

    static func manifest(_ stage: URL) throws -> Manifest {
        guard let data = LedgerOrder.read(stage.appendingPathComponent("write.json"))?.data,
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else { throw Failure(message: "\(CiteOrder.visible(stage.path)) holds no write.json from prepare") }
        return manifest
    }

    // MARK: check

    struct Report {
        var problems: [String] = []
        /// The inserted lines, with their numbers in the staged file.
        var inserted: [(line: Int, text: String)] = []
        var placeholders: [Int] = []
        var newPropositions = 0
        var newRecords = 0
    }

    /// Whether `new` is `old` with lines appended, the old bytes kept.
    static func appended(_ old: Data, _ new: Data) -> Bool {
        guard new.count >= old.count, new.prefix(old.count) == old else { return false }
        return old.isEmpty || old.last == 0x0A || new.count == old.count
    }

    static func check(_ manifest: Manifest) throws -> Report {
        var report = Report()
        let original = lines(try read(manifest.originals["manuscript"]!))
        let staged = lines(try read(manifest.staged["manuscript"]!))
        let after = manifest.after
        let added = staged.count - original.count
        let fits = added > 0 && staged.prefix(after).elementsEqual(original.prefix(after))
            && staged.suffix(original.count - after).elementsEqual(original.suffix(original.count - after))
        if !fits {
            report.problems.append("the staged \(CiteOrder.visible(manifest.file)) is not the file with lines added after line \(after) and nothing else changed")
        } else {
            let block = Array(staged[after..<(after + added)])
            report.inserted = block.enumerated().map { (after + $0.offset + 1, $0.element) }
            if !LedgerOrder.stripped(block.first ?? "x").isEmpty {
                report.problems.append("the new paragraph does not start with a blank line after line \(after)")
            }
            if !block.contains(where: { !LedgerOrder.stripped($0).isEmpty }) {
                report.problems.append("the lines added after line \(after) hold no text")
            }
            if after < original.count, !LedgerOrder.stripped(original[after]).isEmpty, !LedgerOrder.stripped(block.last ?? "").isEmpty {
                report.problems.append("the new paragraph does not end with a blank line before the text that follows it")
            }
            report.placeholders = report.inserted.filter { $0.text.contains(placeholder) }.map(\.line)
        }
        for role in ["ledger", "discourse"] {
            let old = try read(manifest.originals[role]!), new = try read(manifest.staged[role]!)
            if !appended(old, new) {
                report.problems.append("the staged \(role) is not the \(role) with lines added at its end")
            } else {
                let count = Revise.lines(new).count - Revise.lines(old).count
                if role == "ledger" { report.newPropositions = count } else { report.newRecords = count }
            }
        }
        if report.newPropositions == 0 { report.problems.append("the staged ledger has no new proposition") }
        return report
    }

    // MARK: commit

    /// Writes the staged files in the order manuscript, ledger, discourse, structure, after
    /// checking that each original is as `prepare` found it and keeping a copy of each in
    /// `backup/`. Returns the files written; on a failure after the first write, the error names them.
    static func commit(_ manifest: Manifest, stage: URL) throws -> [String] {
        var snapshots: [String: LedgerOrder.Snapshot] = [:]
        for role in roles {
            let path = manifest.originals[role]!
            guard let snapshot = LedgerOrder.read(URL(fileURLWithPath: path)), sha256(snapshot.data) == manifest.hashes[role] else {
                throw Failure(message: "\(CiteOrder.visible(path)) changed after prepare; nothing was written. Prepare again")
            }
            snapshots[role] = snapshot
        }
        let report = try check(manifest)
        guard report.problems.isEmpty else { throw Failure(message: report.problems[0] + "; nothing was written") }
        let backup = stage.appendingPathComponent("backup")
        try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        for role in roles { try snapshots[role]!.data.write(to: backup.appendingPathComponent(role)) }
        var written: [String] = []
        for role in roles {
            let path = manifest.originals[role]!
            do {
                _ = try LedgerOrder.write(try read(manifest.staged[role]!), to: URL(fileURLWithPath: path), replacing: snapshots[role]!)
            } catch let failure as LedgerOrder.Failure {
                let done = written.isEmpty ? "nothing was written" : "already written: \(written.map(CiteOrder.visible).joined(separator: ", "))"
                throw Failure(message: "\(CiteOrder.visible(path)): \(failure.message); \(done). The originals are in \(CiteOrder.visible(backup.path))")
            }
            written.append(path)
        }
        return written
    }
}

/// The commands. Exit codes: prepare 0 staged, 2 refused; check 0 the copies are a new paragraph,
/// 1 they are not, 2 the staging directory cannot be read; commit 0 written, 2 refused or failed.
public enum WriteParagraphRun {
    static func resolve(_ path: String, _ directory: URL) -> URL {
        (path.hasPrefix("/") ? URL(fileURLWithPath: path) : directory.appendingPathComponent(path)).standardizedFileURL
    }

    public static func prepare(jsonl: String, tex: String, structure: String, discourse: String, stage: String,
                               workingDirectory: URL) -> CommandResult {
        do {
            let (manifest, notes) = try WriteParagraph.prepare(
                ledger: resolve(jsonl, workingDirectory), main: resolve(tex, workingDirectory),
                structure: resolve(structure, workingDirectory), discourse: resolve(discourse, workingDirectory),
                stage: resolve(stage, workingDirectory))
            return CommandResult(stdout: [
                "the new paragraph goes after line \(manifest.after) of \(CiteOrder.visible(manifest.file))",
                "staged manuscript file: \(CiteOrder.visible(manifest.staged["manuscript"]!))",
                "staged main file: \(CiteOrder.visible(manifest.stagedMain))",
                "staged ledger: \(CiteOrder.visible(manifest.staged["ledger"]!))",
                "staged structure: \(CiteOrder.visible(manifest.staged["structure"]!))",
                "staged discourse: \(CiteOrder.visible(manifest.staged["discourse"]!))",
            ], stderr: notes, exitCode: 0)
        } catch let failure as WriteParagraph.Failure {
            return CommandResult(stderr: ["error: \(failure.message)"], exitCode: 2)
        } catch let failure as Revise.Failure {
            return CommandResult(stderr: ["error: \(failure.message)"], exitCode: 2)
        } catch {
            return CommandResult(stderr: ["error: the files could not be staged"], exitCode: 2)
        }
    }

    public static func check(stage: String, workingDirectory: URL) -> CommandResult {
        do {
            let report = try WriteParagraph.check(WriteParagraph.manifest(resolve(stage, workingDirectory)))
            var out = report.problems
            out.append("\(report.inserted.count) line(s) added, \(report.newPropositions) new proposition(s), "
                       + "\(report.newRecords) new record(s), \(report.placeholders.count) placeholder line(s)"
                       + (report.placeholders.isEmpty ? "" : ": \(report.placeholders.map(String.init).joined(separator: ", "))"))
            return CommandResult(stdout: out, exitCode: report.problems.isEmpty ? 0 : 1)
        } catch let failure as WriteParagraph.Failure {
            return CommandResult(stderr: ["error: \(failure.message)"], exitCode: 2)
        } catch {
            return CommandResult(stderr: ["error: the staging directory could not be read"], exitCode: 2)
        }
    }

    public static func commit(stage: String, workingDirectory: URL) -> CommandResult {
        let directory = resolve(stage, workingDirectory)
        do {
            let manifest = try WriteParagraph.manifest(directory)
            let written = try WriteParagraph.commit(manifest, stage: directory)
            return CommandResult(stdout: written.map { "written: \(CiteOrder.visible($0))" }
                                 + ["the originals are kept in \(CiteOrder.visible(directory.appendingPathComponent("backup").path))"],
                                 exitCode: 0)
        } catch let failure as WriteParagraph.Failure {
            return CommandResult(stderr: ["error: \(failure.message)"], exitCode: 2)
        } catch {
            return CommandResult(stderr: ["error: the paragraph could not be written"], exitCode: 2)
        }
    }
}
