import Foundation
import CryptoKit

/// `propositions write prepare|check|commit`: write one new paragraph into a draft, with its
/// propositions and its structure records, behind one confirmation (issue 49).
///
/// `prepare` copies the manuscript's input tree, the ledger and its two structure sidecars into a
/// staging directory and records where the paragraph goes. The paragraph, its propositions and
/// its records are made in the copies. `check` says whether the copies differ from the files only
/// as a new paragraph may make them differ. `commit` reads every file once, checks those bytes,
/// keeps a copy of each original, and writes the same bytes it checked.
public enum WriteParagraph {
    public struct Failure: Error, Equatable {
        public let message: String
    }

    /// The written form of a placeholder: what is still to be supplied, which the paragraph does
    /// not invent (a result, a number, a citation).
    public static let placeholder = "{PENDING:"

    /// A file that is copied but not written back: a file of the input tree other than the one
    /// that gets the paragraph, and `_meta.json`. Its original and its copy have to stay as
    /// `prepare` found them, because the skill validates against the copies.
    struct Input: Codable, Equatable {
        var original: String
        var staged: String
        var hash: String
    }

    /// What `prepare` records in the staging directory.
    struct Manifest: Codable, Equatable {
        /// The four files a paragraph changes, by role: `manuscript`, `ledger`, `structure`, `discourse`.
        var originals: [String: String]
        /// Their copies, by the same roles.
        var staged: [String: String]
        var hashes: [String: String]
        var inputs: [Input]
        /// The file of the input tree that gets the paragraph, as a location names it, and the line
        /// after which the paragraph goes.
        var file: String
        var after: Int
        /// The staged main file and `_meta.json`, for the checks the skill runs.
        var stagedMain: String
        var stagedMeta: String?
        /// Whether the paragraph may come with one line of a section heading before it.
        var heading: Bool?
        /// The outline record the paragraph is written from, when it is.
        var outline: WriteFromOutline.Plan?
        /// A rewrite of the whole manuscript from the outline (issue 115), and the files of the input
        /// tree other than the main file, which a rewrite may change and commit writes back.
        var rewrite: WriteRewrite.Plan?
        var rewriteFiles: [Input]?
        /// `article.json`, when the run has one: an input whose banned phrasings the check reads.
        var article: Input?
    }

    static let roles = ["manuscript", "ledger", "discourse", "structure"]

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func snapshot(_ path: String) throws -> LedgerOrder.Snapshot {
        guard let snapshot = LedgerOrder.read(URL(fileURLWithPath: path)) else {
            throw Failure(message: "cannot read \(CiteOrder.visible(path))")
        }
        return snapshot
    }

    /// Writes a new file, refusing one that is already there (a link included).
    static func create(_ data: Data, at url: URL) throws {
        do { try data.write(to: url, options: .withoutOverwriting) } catch {
            throw Failure(message: "cannot create \(CiteOrder.visible(url.path)); it may exist already")
        }
    }

    static func canonical(_ url: URL) -> String { url.resolvingSymlinksInPath().standardizedFileURL.path }

    // MARK: lines as bytes

    /// For each line, the offset just past its line ending (LF, CR or CRLF; the last line may
    /// have none), numbered as `LatexLine.splitLines` numbers them.
    static func lineEnds(_ data: Data) -> [Int] {
        let bytes = [UInt8](data)
        var ends: [Int] = []
        var index = 0
        var start = 0
        while index < bytes.count {
            if bytes[index] == 0x0A || bytes[index] == 0x0D {
                if bytes[index] == 0x0D, index + 1 < bytes.count, bytes[index + 1] == 0x0A { index += 1 }
                ends.append(index + 1)
                start = index + 1
            }
            index += 1
        }
        if start < bytes.count { ends.append(bytes.count) }
        return ends
    }

    static func endsWithLineBreak(_ data: Data) -> Bool { data.last == 0x0A || data.last == 0x0D }

    // MARK: prepare

    static func prepare(ledger: URL, main: URL, structure: URL, discourse: URL, stage: URL,
                        heading: Bool = false, outline: (directory: URL, paragraph: String)? = nil,
                        rewrite: URL? = nil) throws -> (Manifest, [String]) {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        if fm.fileExists(atPath: stage.path, isDirectory: &isDirectory) {
            guard isDirectory.boolValue, let items = try? fm.contentsOfDirectory(atPath: stage.path) else {
                throw Failure(message: "the staging directory \(CiteOrder.visible(stage.path)) cannot be listed")
            }
            guard items.isEmpty else { throw Failure(message: "the staging directory \(CiteOrder.visible(stage.path)) is not empty") }
        }
        // The three files beside the ledger keep their names in the copy; they have to be three files.
        let side = [("ledger", ledger), ("structure", structure), ("discourse", discourse)]
        let names = side.map { $0.1.lastPathComponent }
        guard Set(names).count == 3, !names.contains("_meta.json") else {
            throw Failure(message: "the ledger and the two sidecars need three different file names, none of them _meta.json")
        }
        let order: ReadingOrder
        do { order = try ReadingOrder(mainFile: main) } catch { throw Failure(message: CiteOrder.visible("\(error)")) }
        let mainURL = main.resolvingSymlinksInPath()
        let mainDirectory = mainURL.standardizedFileURL.deletingLastPathComponent()
        // Every file is read once; placement, the copies and the hashes come from these bytes.
        var read: [String: LedgerOrder.Snapshot] = [:]
        for (role, url) in side { read[role] = try snapshot(url.path) }
        let ledgerLines = try ReviseLedger.lines(read["ledger"]!.data)
        var last: (position: [Int], file: String?, line: Int, id: String)?
        var retired: [(file: String?, line: Int)] = []
        for line in ledgerLines {
            guard let id = line.id, let location = line.location else { continue }
            if line.isRetired { retired.append((location.file, location.start)); continue }
            guard let position = order.position(file: location.file, line: location.start) else {
                throw Failure(message: "the location of \(CiteOrder.visible(id)) is not in the input tree")
            }
            if last == nil || ReadingOrder.precedes(last!.position, position) {
                last = (position, location.file, location.start, id)
            }
        }
        let outlineDirectory = outline?.directory ?? rewrite
        let outlineBytes = try outlineDirectory.map { try WriteFromOutline.read($0) }
        let plan = try outline.map { try WriteFromOutline.gate(directory: $0.directory, paragraph: $0.paragraph, bytes: outlineBytes!) }
        let rewritePlan = try rewrite.map { try WriteRewrite.gate(directory: $0, bytes: outlineBytes!) }
        let key = rewrite != nil ? nil : last?.file.flatMap { $0 == "main.tex" ? nil : ReadingOrder.normalise($0) }
        let fileName = key ?? "main.tex"
        var tree: [(name: String, relative: String, url: URL)] = []
        for (index, name) in order.files.enumerated() {
            let relative = index == 0 ? mainURL.lastPathComponent : name
            guard !relative.split(separator: "/").contains("..") else {
                throw Failure(message: "\(CiteOrder.visible(name)) is outside the main file's directory; it cannot be staged")
            }
            tree.append((index == 0 ? "main.tex" : name, relative, index == 0 ? mainURL : mainDirectory.appendingPathComponent(name)))
        }
        guard let target = tree.first(where: { $0.name == fileName }) else {
            throw Failure(message: "\(CiteOrder.visible(fileName)) is not in the input tree")
        }
        let originals = ["manuscript": target.url.path, "ledger": ledger.path, "structure": structure.path, "discourse": discourse.path]
        let written = roles.map { canonical(URL(fileURLWithPath: originals[$0]!)) }
        guard Set(written).count == 4 else {
            throw Failure(message: "the manuscript file, the ledger and the two sidecars have to be four different files")
        }
        let treeTargets = rewrite != nil ? tree.filter { $0.name != "main.tex" }.map { canonical($0.url) } : []
        guard Set(written + treeTargets).count == written.count + treeTargets.count,
              !(written + treeTargets).contains(canonical(ledger.deletingLastPathComponent().appendingPathComponent("_meta.json")))
        else { throw Failure(message: "a file the run writes is named twice, or is _meta.json") }
        if let directory = outlineDirectory {
            let others = (WriteFromOutline.files + [WriteFromOutline.traceFile]).map { canonical(directory.appendingPathComponent($0)) }
            guard Set(others).isDisjoint(with: written + treeTargets) else {
                throw Failure(message: "a file of the outline, or its trace, is one of the files the paragraph changes")
            }
        }
        read["manuscript"] = try snapshot(target.url.path)
        let fileLines = LatexLine.splitLines(String(decoding: read["manuscript"]!.data, as: UTF8.self))
        var end: Int
        if rewrite != nil {
            end = 1   // a rewrite has no place: the whole tree may change
        } else if let last {
            let runs = Paragraphs.runs(fileLines)
            guard last.line <= runs.count, let run = runs[last.line - 1] else {
                throw Failure(message: "the last proposition, \(CiteOrder.visible(last.id)), does not start inside a paragraph")
            }
            end = last.line
            while end < runs.count, runs[end] == run { end += 1 }
        } else {
            // No proposition yet: the end of the draft is its last line of text before \end{document}.
            guard let close = fileLines.firstIndex(where: { LedgerOrder.stripped($0) == "\\end{document}" }) else {
                throw Failure(message: "the ledger has no live proposition, and the main file has no line \\end{document} to write before")
            }
            guard let text = fileLines[..<close].lastIndex(where: { !LedgerOrder.stripped($0).isEmpty }) else {
                throw Failure(message: "the main file has no line before \\end{document} to write after")
            }
            end = text + 1
        }
        if rewrite == nil, end == fileLines.count, !endsWithLineBreak(read["manuscript"]!.data) {
            throw Failure(message: "line \(end) of \(CiteOrder.visible(fileName)) has no line ending; add one and prepare again")
        }
        let notes = retired.compactMap { item -> String? in
            let name = item.file.flatMap { $0 == "main.tex" ? nil : ReadingOrder.normalise($0) } ?? "main.tex"
            guard rewrite == nil, name == fileName, item.line > end else { return nil }
            return "[warn] a retired proposition is located at \(CiteOrder.visible(name)):L\(item.line), after the new paragraph: its location will no longer name its old lines"
        }
        // Copy the tree, the ledger, _meta.json and the sidecars, each into a new file.
        let manuscriptDir = stage.appendingPathComponent("manuscript")
        let ledgerDir = stage.appendingPathComponent("ledger")
        try fm.createDirectory(at: manuscriptDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: ledgerDir, withIntermediateDirectories: true)
        var staged: [String: String] = [:]
        var inputs: [Input] = []
        var rewriteFiles: [Input] = []
        for file in tree {
            let copy = manuscriptDir.appendingPathComponent(file.relative)
            try fm.createDirectory(at: copy.deletingLastPathComponent(), withIntermediateDirectories: true)
            if file.name == fileName {
                try create(read["manuscript"]!.data, at: copy)
                staged["manuscript"] = copy.path
            } else {
                let data = try snapshot(file.url.path).data
                try create(data, at: copy)
                let input = Input(original: file.url.path, staged: copy.path, hash: sha256(data))
                if rewrite != nil { rewriteFiles.append(input) } else { inputs.append(input) }
            }
        }
        let meta = ledger.deletingLastPathComponent().appendingPathComponent("_meta.json")
        var stagedMeta: String?
        if fm.fileExists(atPath: meta.path) {
            let data = try snapshot(meta.path).data
            let copy = ledgerDir.appendingPathComponent("_meta.json")
            try create(data, at: copy)
            inputs.append(Input(original: meta.path, staged: copy.path, hash: sha256(data)))
            stagedMeta = copy.path
        }
        // What is true of the whole article: beside the outline when the run has one, else beside the ledger.
        var articleInput: Input?
        if let found = try Article.read(in: outlineDirectory ?? ledger.deletingLastPathComponent()) {
            guard !(written + treeTargets).contains(canonical(found.url)) else {
                throw Failure(message: "\(Article.fileName) is one of the files the run writes")
            }
            let articleDir = stage.appendingPathComponent("article")
            try fm.createDirectory(at: articleDir, withIntermediateDirectories: true)
            let copy = articleDir.appendingPathComponent(Article.fileName)
            try create(found.data, at: copy)
            let input = Input(original: found.url.path, staged: copy.path, hash: sha256(found.data))
            inputs.append(input)
            articleInput = input
        }
        if let directory = outlineDirectory {
            // The outline is read, not written: its three files have to stay as they are.
            let outlineDir = stage.appendingPathComponent("outline")
            try fm.createDirectory(at: outlineDir, withIntermediateDirectories: true)
            for (name, data) in zip(WriteFromOutline.files, outlineBytes!) {
                let original = directory.appendingPathComponent(name)
                let copy = outlineDir.appendingPathComponent(name)
                try create(data, at: copy)
                inputs.append(Input(original: original.path, staged: copy.path, hash: sha256(data)))
            }
        }
        for (role, url) in side {
            let copy = ledgerDir.appendingPathComponent(url.lastPathComponent)
            try create(read[role]!.data, at: copy)
            staged[role] = copy.path
        }
        // A save made while this ran would pair the placement with other bytes.
        var hashes: [String: String] = [:]
        for role in roles {
            hashes[role] = sha256(read[role]!.data)
            guard try snapshot(originals[role]!).data == read[role]!.data else {
                throw Failure(message: "\(CiteOrder.visible(originals[role]!)) changed while it was being staged; prepare again in a new directory")
            }
        }
        let manifest = Manifest(originals: originals, staged: staged, hashes: hashes, inputs: inputs, file: fileName,
                                after: end, stagedMain: manuscriptDir.appendingPathComponent(mainURL.lastPathComponent).path,
                                stagedMeta: stagedMeta, heading: heading ? true : nil, outline: plan,
                                rewrite: rewritePlan, rewriteFiles: rewrite != nil ? rewriteFiles : nil, article: articleInput)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try create(try encoder.encode(manifest) + Data("\n".utf8), at: stage.appendingPathComponent("write.json"))
        return (manifest, notes)
    }

    static func manifest(_ stage: URL) throws -> Manifest {
        guard let data = LedgerOrder.read(stage.appendingPathComponent("write.json"))?.data,
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data)
        else { throw Failure(message: "\(CiteOrder.visible(stage.path)) holds no write.json from prepare") }
        guard roles.allSatisfy({ manifest.originals[$0] != nil && manifest.staged[$0] != nil && manifest.hashes[$0] != nil }),
              manifest.after > 0,
              (manifest.rewrite == nil) == (manifest.rewriteFiles == nil),
              manifest.rewrite == nil || (manifest.outline == nil && manifest.heading == nil)
        else { throw Failure(message: "the write.json in \(CiteOrder.visible(stage.path)) is not one prepare wrote") }
        return manifest
    }

    // MARK: check

    /// The bytes of every file `check` and `commit` look at, read once.
    struct Payload {
        var originals: [String: LedgerOrder.Snapshot]
        var staged: [String: Data]
        /// Inputs whose original or copy is not as `prepare` found it.
        var changedInputs: [String]
        /// For a rewrite: the other files of the input tree, by original path.
        var rewriteOriginals: [String: LedgerOrder.Snapshot] = [:]
        var rewriteStaged: [String: Data] = [:]
        /// For a rewrite: the outline files and outline-map.jsonl, each read once.
        var outline: Outline?
        var outlineProblem: String?
        var map: Data?
        /// The banned phrasings of the staged `article.json`, or why it cannot be read.
        var banned: [Article.Banned] = []
        var articleProblem: String?
    }

    static func load(_ manifest: Manifest) throws -> Payload {
        var originals: [String: LedgerOrder.Snapshot] = [:]
        var staged: [String: Data] = [:]
        for role in roles {
            originals[role] = try snapshot(manifest.originals[role]!)
            guard let data = LedgerOrder.read(URL(fileURLWithPath: manifest.staged[role]!))?.data else {
                throw Failure(message: "the staged \(role), \(CiteOrder.visible(manifest.staged[role]!)), cannot be read; nothing was written")
            }
            staged[role] = data
        }
        var changed: [String] = []
        for input in manifest.inputs {
            let original = LedgerOrder.read(URL(fileURLWithPath: input.original)).map { sha256($0.data) }
            let copy = LedgerOrder.read(URL(fileURLWithPath: input.staged)).map { sha256($0.data) }
            if original != input.hash { changed.append("\(CiteOrder.visible(input.original)) changed after prepare") }
            if copy != input.hash { changed.append("its copy \(CiteOrder.visible(input.staged)) was changed; only the four files are written") }
        }
        var payload = Payload(originals: originals, staged: staged, changedInputs: changed)
        for file in manifest.rewriteFiles ?? [] {
            payload.rewriteOriginals[file.original] = try snapshot(file.original)
            guard let data = LedgerOrder.read(URL(fileURLWithPath: file.staged))?.data else {
                throw Failure(message: "the staged \(CiteOrder.visible(file.staged)) cannot be read; nothing was written")
            }
            payload.rewriteStaged[file.original] = data
        }
        if let article = manifest.article {
            guard manifest.inputs.contains(article) else {
                throw Failure(message: "write.json names an \(Article.fileName) prepare did not record; nothing was written")
            }
            do {
                guard let data = LedgerOrder.read(URL(fileURLWithPath: article.staged))?.data else {
                    throw Article.Failure(message: "the staged \(Article.fileName) cannot be read")
                }
                payload.banned = try Article.parse(data).banned
            } catch {
                payload.articleProblem = (error as? Article.Failure)?.message ?? "the staged \(Article.fileName) cannot be read"
            }
        }
        if let plan = manifest.rewrite {
            let directory = URL(fileURLWithPath: plan.directory)
            do {
                let bytes = try WriteFromOutline.read(directory)
                // The bytes judged are the bytes recorded at prepare.
                for (name, data) in zip(WriteFromOutline.files, bytes) {
                    let recorded = manifest.inputs.first { $0.original == directory.appendingPathComponent(name).path }
                    guard recorded?.hash == sha256(data) else { throw Failure(message: "\(name) is not as prepare recorded it") }
                }
                _ = try WriteRewrite.gate(directory: directory, bytes: bytes)
                let text = bytes.map { String(decoding: $0, as: UTF8.self) }
                payload.outline = Outline(sections: text[0], paragraphs: text[1], approvals: text[2])
            } catch {
                payload.outlineProblem = (error as? Failure)?.message ?? "the outline cannot be read"
            }
            let stage = URL(fileURLWithPath: manifest.staged["ledger"]!).deletingLastPathComponent().deletingLastPathComponent()
            payload.map = LedgerOrder.read(stage.appendingPathComponent(WriteRewrite.mapFile))?.data
        }
        return payload
    }

    struct Report {
        var problems: [String] = []
        var inserted = 0
        var placeholders: [Int] = []
        var newPropositions = 0
        var newRecords = 0
        var heading: String?
        /// The id of the first proposition added to the ledger.
        var firstNew: String?
    }

    /// A line that is one sectioning command and nothing else: `\part`, `\chapter`, `\section`,
    /// `\subsection` or `\subsubsection`, starred or not, with an optional short title in brackets and
    /// one braced argument (braces inside it balanced, one level), then optionally one `\label{…}`
    /// and a comment.
    static let headingPattern = try! NSRegularExpression(pattern:
        #"^\\(part|chapter|section|subsection|subsubsection)\*?(\[[^\]]*\])?\{[^{}]*(\{[^{}]*\}[^{}]*)*\}\s*(\\label\{[^{}]*\})?\s*(%.*)?$"#)

    static func isHeading(_ line: String) -> Bool {
        let text = LedgerOrder.stripped(line)
        return headingPattern.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    /// Whether a line begins a sectioning command, complete or not.
    static func beginsHeading(_ line: String) -> Bool {
        let text = LedgerOrder.stripped(line)
        return ["part", "chapter", "section", "subsection", "subsubsection"].contains { text.hasPrefix("\\" + $0) }
    }

    /// The lines `new` adds at the end of `old`, when it is `old` with whole lines added and
    /// nothing else changed; `nil` otherwise. A last line of `old` without a line ending may get one.
    static func addedLines(_ old: Data, _ new: Data) -> [String]? {
        guard new.count > old.count, new.prefix(old.count) == old else { return nil }
        var tail = Data(new.suffix(from: new.startIndex + old.count))
        if !old.isEmpty, !endsWithLineBreak(old) {
            guard tail.first == 0x0A || tail.first == 0x0D else { return nil }
            tail = Data(tail.drop(while: { $0 == 0x0A || $0 == 0x0D }))
        }
        guard let text = String(data: tail, encoding: .utf8) else { return nil }
        return LatexLine.splitLines(text)
    }

    /// Whether `new` keeps everything `old` has: equal values, an object with every key of
    /// `old` kept (and possibly more), an array with every element of `old` kept in its place
    /// (and possibly more after them).
    static func extends(_ old: JSONValue, _ new: JSONValue) -> Bool {
        switch (old, new) {
        case let (.array(a), .array(b)):
            return b.count >= a.count && zip(a, b).allSatisfy { extends($0, $1) }
        case (.object, .object):
            let b = new.dictionary
            return old.dictionary.allSatisfy { key, value in b[key].map { extends(value, $0) } ?? false }
        default:
            return old == new
        }
    }

    static func check(_ manifest: Manifest, _ payload: Payload) -> Report {
        if manifest.rewrite != nil { return rewriteCheck(manifest, payload) }
        var report = Report()
        report.problems += payload.changedInputs
        if let problem = payload.articleProblem { report.problems.append(problem) }
        let original = payload.originals["manuscript"]!.data, staged = payload.staged["manuscript"]!
        let ends = lineEnds(original)
        let name = CiteOrder.visible(manifest.file)
        if manifest.after > ends.count {
            report.problems.append("\(name) has fewer than \(manifest.after) lines")
        } else {
            let cut = ends[manifest.after - 1]
            let added = staged.count - original.count
            let keeps = added > 0 && staged.prefix(cut) == original.prefix(cut)
                && staged.suffix(original.count - cut) == original.suffix(original.count - cut)
            let block = keeps ? Data(staged[(staged.startIndex + cut)..<(staged.startIndex + cut + added)]) : Data()
            if !keeps {
                report.problems.append("the staged \(name) is not the file with lines added after line \(manifest.after), every other byte as it was")
            } else if let text = String(data: block, encoding: .utf8) {
                let lines = LatexLine.splitLines(text)
                report.inserted = lines.count
                let blank = lines.map { LedgerOrder.stripped($0).isEmpty }
                let starts = zip(blank, [true] + blank).enumerated().filter { !$0.element.0 && $0.element.1 }.map(\.offset)
                var runs = starts.count
                if manifest.heading == true, let first = starts.first, isHeading(lines[first]),
                   first + 1 < lines.count, blank[first + 1] {
                    report.heading = lines[first]
                    runs -= 1
                }
                let headings = lines.indices.filter { beginsHeading(lines[$0]) && lines[$0] != report.heading }
                if !headings.isEmpty {
                    report.problems.append("line \(manifest.after + headings[0] + 1) begins a sectioning command"
                                           + (manifest.heading == true ? " that is not one heading line before the paragraph, set off by blank lines" : "; prepare with --heading to write a heading"))
                }
                if blank.first != true { report.problems.append("the new paragraph does not start with a blank line after line \(manifest.after)") }
                if runs != 1 {
                    let what = manifest.heading == true ? "after a heading line, " : ""
                    report.problems.append("the lines added after line \(manifest.after) hold \(what)\(runs) paragraphs, not one")
                }
                if cut < original.count, !endsWithLineBreak(block) {
                    report.problems.append("the lines added after line \(manifest.after) do not end with a line ending")
                }
                let next = LatexLine.splitLines(String(decoding: original.suffix(original.count - cut), as: UTF8.self)).first
                if let next, !LedgerOrder.stripped(next).isEmpty, blank.last != true {
                    report.problems.append("the new paragraph does not end with a blank line before the text that follows it")
                }
                report.problems += Phrasing.occurrences(in: lines, first: manifest.after + 1, file: manifest.file, banned: payload.banned)
                report.placeholders = lines.enumerated().filter { $0.element.contains(placeholder) }.map { manifest.after + $0.offset + 1 }
            } else {
                report.problems.append("the lines added after line \(manifest.after) are not UTF-8")
            }
        }
        for role in ["ledger", "discourse"] {
            guard let lines = addedLines(payload.originals[role]!.data, payload.staged[role]!) else {
                report.problems.append("the staged \(role) is not the \(role) with lines added at its end")
                continue
            }
            let rows = lines.filter { !LedgerOrder.stripped($0).isEmpty }
            for row in rows {
                guard let value = try? JSONValue.parse(row), case .object = value else {
                    report.problems.append("a line added to the staged \(role) is not a JSON object"); break
                }
            }
            if role == "ledger" {
                report.newPropositions = rows.count
                report.firstNew = rows.first.flatMap { try? JSONValue.parse($0) }?["id"]?.string
            } else {
                report.newRecords = rows.count
            }
        }
        if report.newPropositions == 0 { report.problems.append("the staged ledger has no new proposition") }
        if manifest.outline != nil, report.newPropositions > 0 {
            if let first = report.firstNew {
                // It has to be one live proposition that starts in the new lines.
                let rows = (try? ReviseLedger.lines(payload.staged["ledger"]!)) ?? []
                let live = rows.filter { WriteFromOutline.same($0.id, first) && !$0.isRetired }
                let all = rows.filter { WriteFromOutline.same($0.id, first) }
                let file = live.first?.location.map { ($0.file.flatMap { $0 == "main.tex" ? nil : ReadingOrder.normalise($0) }) ?? "main.tex" }
                let start = live.first?.location?.start ?? 0
                if live.count != 1 || all.count != 1 {
                    report.problems.append("the first proposition added, \(CiteOrder.visible(first)), is not exactly one live proposition of the staged ledger")
                } else if file != manifest.file || start <= manifest.after || start > manifest.after + report.inserted {
                    report.problems.append("the first proposition added, \(CiteOrder.visible(first)), does not start in the new lines")
                }
            } else {
                report.problems.append("the first proposition added to the staged ledger has no id")
            }
        }
        if let plan = manifest.outline {
            // What the paragraph opens and discharges has to be what its outline record plans (issue 116).
            let source = URL(fileURLWithPath: plan.directory).appendingPathComponent(Outline.paragraphFile).path
            let copy = manifest.inputs.first { $0.original == source }.flatMap { LedgerOrder.read(URL(fileURLWithPath: $0.staged))?.data }
            let records = copy.map(OutlineCommitments.objects) ?? []
            let record = records.first { WriteFromOutline.same($0["id"]?.string, plan.paragraph) }
            let added = ["ledger", "discourse"].map { role in
                (addedLines(payload.originals[role]!.data, payload.staged[role]!) ?? []).compactMap { try? JSONValue.parse($0) }
            }
            if let record, !OutlineCommitments.plansAny(records) {
                _ = record   // an outline that plans no commitment is not compared
            } else if let record {
                let written = OutlineCommitments.written(discourse: added[1], propositions: added[0].compactMap { $0["id"]?.string })
                report.problems += OutlineCommitments.differences(record: record, written: written)
            } else {
                report.problems.append("the copy of the outline's paragraph file does not hold the record \(CiteOrder.visible(plan.paragraph))")
            }
        }
        let oldStructure = try? JSONValue.parse(String(decoding: payload.originals["structure"]!.data, as: UTF8.self))
        let newStructure = try? JSONValue.parse(String(decoding: payload.staged["structure"]!, as: UTF8.self))
        if let oldStructure, let newStructure {
            if !extends(oldStructure, newStructure) {
                report.problems.append("the staged structure drops or changes something the structure has; it may only add")
            }
        } else {
            report.problems.append("the structure or its copy is not JSON")
        }
        return report
    }

    /// The check of a rewrite: every file of the tree may change (and has to be UTF-8); the ledger
    /// keeps every proposition (see `WriteRewrite.ledger`); the sidecars are JSON and left to the
    /// structure validator; `outline-map.jsonl` lists every paragraph record of the outline.
    static func rewriteCheck(_ manifest: Manifest, _ payload: Payload) -> Report {
        var report = Report()
        report.problems += payload.changedInputs
        if let problem = payload.articleProblem { report.problems.append(problem) }
        for data in [payload.staged["manuscript"]!] + Array(payload.rewriteStaged.values) where String(data: data, encoding: .utf8) == nil {
            report.problems.append("a staged file of the manuscript is not UTF-8")
            break
        }
        // The banned phrasings, over every staged file of the tree, in the order prepare read them.
        let stagedRoot = URL(fileURLWithPath: manifest.stagedMain).deletingLastPathComponent().path + "/"
        let tree = [(manifest.file, payload.staged["manuscript"]!)]
            + (manifest.rewriteFiles ?? []).compactMap { file in
                payload.rewriteStaged[file.original].map { (file.staged.hasPrefix(stagedRoot) ? String(file.staged.dropFirst(stagedRoot.count)) : file.staged, $0) }
            }
        for (name, data) in tree {
            guard let text = String(data: data, encoding: .utf8) else { continue }
            report.problems += Phrasing.occurrences(in: LatexLine.splitLines(text), file: name, banned: payload.banned)
        }
        let ledger = WriteRewrite.ledger(old: payload.originals["ledger"]!.data, new: payload.staged["ledger"]!)
        report.problems += ledger.problems
        report.newPropositions = ledger.added.count
        report.firstNew = ledger.added.first
        if String(data: payload.staged["discourse"]!, encoding: .utf8) == nil || (try? ReviseLedger.lines(payload.staged["discourse"]!)) == nil {
            report.problems.append("the staged discourse sidecar is not one JSON object per line")
        }
        if (String(data: payload.staged["structure"]!, encoding: .utf8).flatMap { try? JSONValue.parse($0) }) == nil {
            report.problems.append("the staged structure is not JSON")
        }
        var mapped: [String] = []
        if let outline = payload.outline {
            let map = WriteRewrite.map(payload.map, outline: outline, ledger: payload.staged["ledger"]!)
            report.problems += map.problems
            report.newRecords = map.records.count
            mapped = map.records.map(\.1)
            report.problems += WriteRewrite.commitments(records: map.records, outline: outline, stagedMain: URL(fileURLWithPath: manifest.stagedMain),
                                                         ledger: payload.staged["ledger"]!, discourse: payload.staged["discourse"]!)
        } else {
            report.problems.append(payload.outlineProblem ?? "the outline cannot be read")
        }
        report.problems += WriteRewrite.locations(stagedMain: URL(fileURLWithPath: manifest.stagedMain),
                                                   ledger: payload.staged["ledger"]!, mapped: mapped)
        let changed = (payload.staged["manuscript"]! != payload.originals["manuscript"]!.data ? 1 : 0)
            + payload.rewriteStaged.filter { payload.rewriteOriginals[$0.key]?.data != $0.value }.count
        report.inserted = changed
        return report
    }

    // MARK: commit

    /// Reads every file once, refuses when an original changed after `prepare` or the check
    /// reports a problem, keeps a copy of each original in a new `backup/`, then writes the
    /// checked bytes in the order manuscript, ledger, discourse, structure.
    static func commit(_ manifest: Manifest, stage: URL) throws -> [String] {
        let payload = try load(manifest)
        for role in roles where sha256(payload.originals[role]!.data) != manifest.hashes[role] {
            throw Failure(message: "\(CiteOrder.visible(manifest.originals[role]!)) changed after prepare; nothing was written. Prepare again")
        }
        for file in manifest.rewriteFiles ?? [] where sha256(payload.rewriteOriginals[file.original]!.data) != file.hash {
            throw Failure(message: "\(CiteOrder.visible(file.original)) changed after prepare; nothing was written. Prepare again")
        }
        let trace = try manifest.outline.map { try WriteFromOutline.traceSnapshot($0) }
        if let plan = manifest.outline { try WriteFromOutline.confirm(plan, inputs: manifest.inputs) }
        let rewriteTrace = try manifest.rewrite.map { plan -> LedgerOrder.Snapshot? in
            guard payload.outline != nil else {
                throw Failure(message: (payload.outlineProblem ?? "the outline cannot be read") + "; nothing was written")
            }
            return try WriteFromOutline.traceSnapshot(WriteFromOutline.Plan(directory: plan.directory, paragraph: "", section: "",
                                                                             approvalLine: 0, traceHash: plan.traceHash))
        }
        // The trace a rewrite writes, settled before anything is written.
        var rewriteTraceLines: Data?
        if manifest.rewrite != nil, let outline = payload.outline {
            let map = WriteRewrite.map(payload.map, outline: outline, ledger: payload.staged["ledger"]!)
            rewriteTraceLines = WriteRewrite.traceLines(map.records, outline: outline)
        }
        let report = check(manifest, payload)
        guard report.problems.isEmpty else { throw Failure(message: report.problems[0] + "; nothing was written") }
        if let first = report.firstNew, manifest.outline != nil, WriteFromOutline.names(trace ?? nil, first) {
            throw Failure(message: "the trace already names \(CiteOrder.visible(first)); nothing was written")
        }
        let backup = stage.appendingPathComponent("backup")
        do { try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false) } catch {
            throw Failure(message: "\(CiteOrder.visible(backup.path)) exists already or cannot be made; nothing was written")
        }
        for role in roles { try create(payload.originals[role]!.data, at: backup.appendingPathComponent(role)) }
        var restore: [String] = roles.map { #"{"backup": "\#($0)", "destination": \#(Revise.quoted(manifest.originals[$0]!))}"# }
        for (index, file) in (manifest.rewriteFiles ?? []).enumerated() {
            try create(payload.rewriteOriginals[file.original]!.data, at: backup.appendingPathComponent("file-\(index + 1)"))
            restore.append(#"{"backup": "file-\#(index + 1)", "destination": \#(Revise.quoted(file.original))}"#)
        }
        if let plan = manifest.rewrite {
            let trace = Revise.quoted(URL(fileURLWithPath: plan.directory).appendingPathComponent(WriteFromOutline.traceFile).path)
            if let snapshot = rewriteTrace ?? nil {
                try create(snapshot.data, at: backup.appendingPathComponent("trace"))
                restore.append(#"{"backup": "trace", "destination": \#(trace)}"#)
            } else {
                restore.append(#"{"backup": null, "destination": \#(trace), "absent": true}"#)
            }
        }
        if manifest.rewrite != nil { try create(Data((restore.joined(separator: "\n") + "\n").utf8), at: backup.appendingPathComponent("restore.jsonl")) }
        var written: [String] = []
        // A rewrite writes the other files of the tree that changed, after the main file.
        let changedFiles = (manifest.rewriteFiles ?? []).filter { payload.rewriteStaged[$0.original] != payload.rewriteOriginals[$0.original]!.data }
        let order = ["manuscript"] + changedFiles.map(\.original) + ["ledger", "discourse", "structure"]
        for item in order {
            let role = roles.contains(item) ? item : nil
            let path = role.map { manifest.originals[$0]! } ?? item
            let content = role.map { payload.staged[$0]! } ?? payload.rewriteStaged[item]!
            let original = role.map { payload.originals[$0]! } ?? payload.rewriteOriginals[item]!
            if manifest.rewrite != nil, content == original.data { continue }   // a rewrite leaves unchanged files alone
            do {
                _ = try LedgerOrder.write(content, to: URL(fileURLWithPath: path), replacing: original)
            } catch {
                let reason = (error as? LedgerOrder.Failure)?.message ?? "it could not be written"
                let done = written.isEmpty ? "nothing was written" : "already written: \(written.map(CiteOrder.visible).joined(separator: ", "))"
                throw Failure(message: "\(CiteOrder.visible(path)): \(reason); \(done). The originals are in \(CiteOrder.visible(backup.path))")
            }
            written.append(path)
        }
        if let plan = manifest.outline, let first = report.firstNew {
            do {
                try WriteFromOutline.append(plan, firstProposition: first, to: trace ?? nil)
            } catch {
                throw Failure(message: "\(CiteOrder.visible(WriteFromOutline.traceURL(plan).path)): the record could not be added; already written: \(written.map(CiteOrder.visible).joined(separator: ", ")). The originals are in \(CiteOrder.visible(backup.path))")
            }
            written.append(WriteFromOutline.traceURL(plan).path)
        }
        if let plan = manifest.rewrite, let lines = rewriteTraceLines {
            let url = URL(fileURLWithPath: plan.directory).appendingPathComponent(WriteFromOutline.traceFile)
            do {
                if let snapshot = rewriteTrace ?? nil {
                    _ = try LedgerOrder.write(lines, to: url, replacing: snapshot)
                } else {
                    try create(lines, at: url)
                }
            } catch {
                throw Failure(message: "\(CiteOrder.visible(url.path)): the records could not be added; already written: \(written.map(CiteOrder.visible).joined(separator: ", ")). The originals are in \(CiteOrder.visible(backup.path))")
            }
            written.append(url.path)
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

    static func refuse(_ error: Error, _ fallback: String) -> CommandResult {
        let message = (error as? WriteParagraph.Failure)?.message ?? (error as? Revise.Failure)?.message ?? fallback
        return CommandResult(stderr: ["error: \(message)"], exitCode: 2)
    }

    public static func prepare(jsonl: String, tex: String, structure: String, discourse: String, stage: String,
                               heading: Bool = false, outline: String? = nil, outlineParagraph: String? = nil,
                               rewrite: Bool = false, workingDirectory: URL) -> CommandResult {
        if rewrite {
            guard outline != nil, outlineParagraph == nil, !heading else {
                return CommandResult(stderr: ["error: --rewrite takes --outline, and neither --outline-paragraph nor --heading"], exitCode: 2)
            }
        } else if (outline == nil) != (outlineParagraph == nil) {
            return CommandResult(stderr: ["error: --outline and --outline-paragraph go together"], exitCode: 2)
        }
        do {
            let (manifest, notes) = try WriteParagraph.prepare(
                ledger: resolve(jsonl, workingDirectory), main: resolve(tex, workingDirectory),
                structure: resolve(structure, workingDirectory), discourse: resolve(discourse, workingDirectory),
                stage: resolve(stage, workingDirectory), heading: heading,
                outline: rewrite ? nil : outline.map { (resolve($0, workingDirectory), outlineParagraph!) },
                rewrite: rewrite ? outline.map { resolve($0, workingDirectory) } : nil)
            let first = manifest.rewrite != nil
                ? "rewrite: every file of the input tree may change; list the outline records in \(CiteOrder.visible(resolve(stage, workingDirectory).appendingPathComponent(WriteRewrite.mapFile).path))"
                : "the new paragraph goes after line \(manifest.after) of \(CiteOrder.visible(manifest.file))"
            return CommandResult(stdout: [
                first,
                "staged manuscript file: \(CiteOrder.visible(manifest.staged["manuscript"]!))",
                "staged main file: \(CiteOrder.visible(manifest.stagedMain))",
                "staged ledger: \(CiteOrder.visible(manifest.staged["ledger"]!))",
                "staged structure: \(CiteOrder.visible(manifest.staged["structure"]!))",
                "staged discourse: \(CiteOrder.visible(manifest.staged["discourse"]!))",
            ], stderr: notes, exitCode: 0)
        } catch {
            return refuse(error, "the files could not be staged")
        }
    }

    public static func check(stage: String, workingDirectory: URL) -> CommandResult {
        do {
            let manifest = try WriteParagraph.manifest(resolve(stage, workingDirectory))
            let report = WriteParagraph.check(manifest, try WriteParagraph.load(manifest))
            var out = report.problems
            if let heading = report.heading { out.append("heading: \(heading)") }
            if manifest.rewrite != nil {
                out.append("rewrite: \(report.inserted) file(s) changed, \(report.newPropositions) new proposition(s), \(report.newRecords) outline record(s) listed")
                return CommandResult(stdout: out, exitCode: report.problems.isEmpty ? 0 : 1)
            }
            out.append("\(report.inserted) line(s) added, \(report.newPropositions) new proposition(s), "
                       + "\(report.newRecords) new record(s), \(report.placeholders.count) placeholder line(s)"
                       + (report.placeholders.isEmpty ? "" : ": \(report.placeholders.map(String.init).joined(separator: ", "))"))
            return CommandResult(stdout: out, exitCode: report.problems.isEmpty ? 0 : 1)
        } catch {
            return refuse(error, "the staging directory could not be read")
        }
    }

    public static func commit(stage: String, workingDirectory: URL) -> CommandResult {
        let directory = resolve(stage, workingDirectory)
        do {
            let written = try WriteParagraph.commit(try WriteParagraph.manifest(directory), stage: directory)
            return CommandResult(stdout: written.map { "written: \(CiteOrder.visible($0))" }
                                 + ["the originals are kept in \(CiteOrder.visible(directory.appendingPathComponent("backup").path))"],
                                 exitCode: 0)
        } catch {
            return refuse(error, "the paragraph could not be written")
        }
    }
}
