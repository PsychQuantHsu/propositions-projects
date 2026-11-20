import Foundation

/// Proposes a paragraph plan from the TeX source: the Swift port of `derive-paragraphs.py`.
///
/// Each maximal run of non-blank lines of a file is one paragraph. Each proposition that is not
/// retired belongs to the paragraph that holds the first line of its `location`; when two
/// propositions that follow each other in the ledger are in different paragraphs, the second
/// starts a new one. Paragraphs that hold no proposition are skipped. A proposition that a
/// section of the structure sidecar starts with starts a paragraph too, so that no paragraph
/// crosses a section.
///
/// A location may name any file of the main file's input tree. A paragraph does not run from one
/// file into another: the lines of each file are grouped on their own.
public enum Paragraphs {
    public struct Failure: Error, Equatable {
        public let message: String
    }

    public struct Paragraph: Equatable, Sendable {
        public let id: String
        public let firstProp: String
    }

    /// For each line of a text, the number of its run of non-blank lines, or `nil` for a blank line.
    static func runs(_ lines: [String]) -> [Int?] {
        var ids: [Int?] = []
        var current = -1
        var previousBlank = true
        for line in lines {
            let blank = LedgerOrder.stripped(line).isEmpty
            if !blank && previousBlank { current += 1 }
            ids.append(blank ? nil : current)
            previousBlank = blank
        }
        return ids
    }

    /// The propositions of a ledger that are not retired, in the ledger's order: id and location.
    static func propositions(ledger text: String, name: String) throws -> [(id: String, location: String?)] {
        var result: [(String, String?)] = []
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        for (index, raw) in lines.enumerated() {
            let body = LedgerOrder.stripped(raw)
            if body.isEmpty || body.unicodeScalars.starts(with: "//".unicodeScalars) { continue }
            guard let value = try? JSONValue.parse(body) else {
                throw Failure(message: "\(name) line \(index + 1): invalid JSON")
            }
            guard let members = value.members, !members.contains(where: { $0.key == "retired" }) else { continue }
            guard let id = members.last(where: { $0.key == "id" })?.value.string else {
                throw Failure(message: "\(name) line \(index + 1): the proposition has no string id")
            }
            result.append((id, members.last { $0.key == "location" }?.value.string))
        }
        return result
    }

    /// The `first_prop` of each section of a structure sidecar.
    static func sectionStarts(structure text: String, name: String) throws -> Set<String> {
        guard let value = try? JSONValue.parse(text) else { throw Failure(message: "\(name): invalid JSON") }
        guard let members = value.members else { throw Failure(message: "\(name): not a JSON object") }
        guard let sections = members.last(where: { $0.key == "sections" })?.value else { return [] }
        guard let list = sections.array else { throw Failure(message: "\(name): sections is not a list") }
        return Set(list.compactMap { $0.members?.last { $0.key == "first_prop" }?.value.string })
    }

    /// `lines(of:)` gives the lines of a file of the input tree by the name `position` knows it
    /// under (`nil` for the main file), or `nil` when the file is not in the tree.
    static func derive(
        propositions: [(id: String, location: String?)], starts: Set<String>, lines: (String?) throws -> [String]?
    ) throws -> [Paragraph] {
        var runsByFile: [String: [Int?]] = [:]
        var firsts: [String] = []
        var previous: (file: String, run: Int)?
        for proposition in propositions {
            let name = CiteOrder.visible(proposition.id)
            guard let raw = proposition.location, let location = Location.parse(raw) else {
                throw Failure(message: "cannot parse the location of \(name)")
            }
            let shown = CiteOrder.visible(raw)
            let key = location.file.map(ReadingOrder.normalise).flatMap { $0 == "main.tex" ? nil : $0 }
            let file = key ?? ""
            if runsByFile[file] == nil {
                guard let text = try lines(key) else {
                    throw Failure(message: "location \(shown) of \(name) names a file that is not in the manuscript's input tree")
                }
                runsByFile[file] = runs(text)
            }
            let ids = runsByFile[file] ?? []
            guard location.start <= ids.count, let run = ids[location.start - 1] else {
                throw Failure(message: "location \(shown) of \(name) is not inside a TeX paragraph")
            }
            if previous?.file != file || previous?.run != run || starts.contains(proposition.id) {
                firsts.append(proposition.id)
            }
            previous = (file, run)
        }
        return firsts.enumerated().map { Paragraph(id: "p-\($0.offset + 1)", firstProp: $0.element) }
    }

    /// A string as Python's `json.dumps(..., ensure_ascii=False)` writes it.
    static func pythonString(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    let hex = String(scalar.value, radix: 16)
                    out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }

    /// The list as `json.dumps(paragraphs, ensure_ascii=False, indent=1)` prints it, line by line.
    public static func render(_ paragraphs: [Paragraph]) -> [String] {
        if paragraphs.isEmpty { return ["[]"] }
        var lines = ["["]
        for (index, paragraph) in paragraphs.enumerated() {
            lines.append(" {")
            lines.append("  \"id\": \(pythonString(paragraph.id)),")
            lines.append("  \"first_prop\": \(pythonString(paragraph.firstProp))")
            lines.append(index == paragraphs.count - 1 ? " }" : " },")
        }
        lines.append("]")
        return lines
    }
}

/// `propositions paragraphs`.
///
/// Exit codes, as the Python tool has them: 0 the paragraphs were printed; 2 an input is missing
/// or cannot be read, a location cannot be parsed, names a file outside the input tree or lies
/// outside every paragraph, or an argument is wrong.
public enum ParagraphsRun {
    public static func run(jsonl: String, tex: String, structure: String?, workingDirectory: URL) -> CommandResult {
        func resolve(_ path: String) -> URL {
            path.hasPrefix("/") ? URL(fileURLWithPath: path) : workingDirectory.appendingPathComponent(path)
        }
        func refuse(_ message: String) -> CommandResult {
            CommandResult(stderr: ["error: \(message)"], exitCode: 2)
        }
        func regularFile(_ url: URL) -> String? {
            var info = stat()
            guard stat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }
        // The same order of checks as the Python tool: the main file, the structure, the ledger.
        let mainURL = resolve(tex)
        guard regularFile(mainURL) != nil else { return refuse("TeX file not found, or not UTF-8: \(CiteOrder.visible(tex))") }
        let order: ReadingOrder
        do {
            order = try ReadingOrder(mainFile: mainURL)
        } catch {
            return refuse(CiteOrder.visible("\(error)"))
        }
        let notes = order.skippedImports.map {
            "[warn] non-standard import macro skipped at \(CiteOrder.visible($0)) (\\subimport/\\subfile/\\import unsupported)"
        }
        let root = mainURL.resolvingSymlinksInPath().standardizedFileURL.deletingLastPathComponent()
        let inTree = Set(order.files.dropFirst())
        do {
            var starts: Set<String> = []
            if let structure {
                guard let text = regularFile(resolve(structure)) else {
                    throw Paragraphs.Failure(message: "structure sidecar not found, or not UTF-8: \(CiteOrder.visible(structure))")
                }
                starts = try Paragraphs.sectionStarts(
                    structure: text, name: CiteOrder.visible(URL(fileURLWithPath: structure).lastPathComponent))
            }
            guard let ledger = regularFile(resolve(jsonl)) else {
                throw Paragraphs.Failure(message: "ledger not found, or not UTF-8: \(CiteOrder.visible(jsonl))")
            }
            let propositions = try Paragraphs.propositions(
                ledger: ledger, name: CiteOrder.visible(URL(fileURLWithPath: jsonl).lastPathComponent))
            let paragraphs = try Paragraphs.derive(propositions: propositions, starts: starts) { key in
                guard let key else { return LatexLine.splitLines(regularFile(mainURL) ?? "") }
                guard inTree.contains(key) else { return nil }
                guard let text = regularFile(root.appendingPathComponent(key)) else {
                    throw Paragraphs.Failure(message: "cannot read \(CiteOrder.visible(key))")
                }
                return LatexLine.splitLines(text)
            }
            return CommandResult(stdout: Paragraphs.render(paragraphs), stderr: notes, exitCode: 0)
        } catch let failure as Paragraphs.Failure {
            return CommandResult(stderr: notes + ["error: \(failure.message)"], exitCode: 2)
        } catch {
            return CommandResult(stderr: notes + ["error: the inputs could not be read"], exitCode: 2)
        }
    }
}
