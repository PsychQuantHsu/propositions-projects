import Foundation

/// Length targets of sections and the length of what was written (issue 119): the key `length`
/// of a section record, the key `length` of `article.json`, and `propositions outline length`.
///
/// Lengths are counted in words by `words(in:)`. It is an estimate for planning, not the count
/// of any journal.
public enum OutlineLength {
    /// A whole number from 1 to 999 999 999, as a section's `length` and a `limit` are written.
    static func count(_ value: JSONValue?) -> Int? {
        guard case let .number(number)? = value, number.isPositiveInteger, number.digits.count + number.exponent <= 9 else { return nil }
        return Int(number.digits + String(repeating: "0", count: number.exponent))
    }

    // MARK: counting words

    static let mathEnvironments: Set<String> = ["equation", "align", "alignat", "gather", "multline", "eqnarray", "displaymath", "math", "flalign"]
    /// Commands whose arguments are names, not text.
    static let nameCommands: Set<String> = [
        "label", "ref", "eqref", "pageref", "autoref", "cref", "Cref", "nameref", "cite", "citep", "citet", "citealp", "citealt",
        "citeauthor", "citeyear", "parencite", "textcite", "autocite", "footcite", "nocite", "input", "include", "includegraphics",
        "bibliography", "bibliographystyle", "addbibresource", "usepackage", "documentclass", "begin", "end", "url", "href",
    ]

    static func isCJK(_ scalar: Unicode.Scalar) -> Bool {
        // Han, kana (full and half width) and hangul syllables; the punctuation of those blocks is not a word.
        switch scalar.value {
        case 0x3041...0x3096, 0x30A1...0x30FA, 0xFF66...0xFF6F, 0xFF71...0xFF9D, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xAC00...0xD7A3,
             0xF900...0xFAFF, 0x20000...0x2FFFF: return true
        default: return false
        }
    }

    /// The text of `lines` without comments, mathematics, command names and the arguments of
    /// commands that take names.
    static func prose(_ lines: [String]) -> String {
        let chars = Array(lines.map { String(Phrasing.withoutComment($0)) }.joined(separator: "\n"))
        var out = ""
        var index = 0
        func skip(to closing: String, from start: Int) -> Int {
            let target = Array(closing)
            var at = start
            while at + target.count <= chars.count {
                // A backslash takes the character after it, unless the two are the closing delimiter.
                if chars[at] == "\\", at + 1 < chars.count, !(target.first == "\\" && Array(chars[at..<(at + target.count)]) == target) { at += 2; continue }
                if Array(chars[at..<(at + target.count)]) == target { return at + target.count }
                at += 1
            }
            return chars.count
        }
        /// The index after `\end{name}` of the environment, white space allowed before the brace.
        func skipEnvironment(_ name: String, from start: Int) -> Int {
            var at = start
            let end = Array("\\end")
            while at + end.count <= chars.count {
                if Array(chars[at..<(at + end.count)]) == end {
                    var brace = at + end.count
                    while brace < chars.count, chars[brace].isWhitespace { brace += 1 }
                    if let close = group(at: brace), close - 1 > brace, chars[close - 1] == "}", String(chars[(brace + 1)..<(close - 1)]) == name { return close }
                }
                at += chars[at] == "\\" && at + 1 < chars.count && chars[at + 1] == "\\" ? 2 : 1
            }
            return chars.count
        }
        func spaces(_ start: Int) -> Int {
            var at = start
            // White space before an argument, a line break included; an empty line ends the paragraph and is not skipped.
            var breaks = 0
            while at < chars.count, chars[at].isWhitespace {
                if chars[at].isNewline { breaks += 1; if breaks > 1 { return start } }
                at += 1
            }
            return at
        }
        func group(at start: Int) -> Int? {
            guard start < chars.count, chars[start] == "{" || chars[start] == "[" else { return nil }
            let open = chars[start], close: Character = open == "{" ? "}" : "]"
            var depth = 0, at = start
            while at < chars.count {
                if chars[at] == "\\" { at += 2; continue }
                // A `]` inside braces does not close a bracket group.
                if open == "[", chars[at] == "{", let inner = group(at: at) { at = inner; continue }
                if chars[at] == open { depth += 1 } else if chars[at] == close { depth -= 1; if depth == 0 { return at + 1 } }
                at += 1
            }
            return chars.count
        }
        while index < chars.count {
            let char = chars[index]
            if char == "$" {
                let double = index + 1 < chars.count && chars[index + 1] == "$"
                index = skip(to: double ? "$$" : "$", from: index + (double ? 2 : 1))
                out.append(" ")
            } else if char == "\\" {
                guard index + 1 < chars.count else { break }
                let next = chars[index + 1]
                if next == "[" { index = skip(to: "\\]", from: index + 2); out.append(" "); continue }
                if next == "(" { index = skip(to: "\\)", from: index + 2); out.append(" "); continue }
                guard next.isLetter, next.isASCII else { index += 2; out.append(" "); continue }
                var end = index + 1
                while end < chars.count, chars[end].isLetter, chars[end].isASCII { end += 1 }
                let name = String(chars[(index + 1)..<end])
                if end < chars.count, chars[end] == "*" { end += 1 }
                index = end
                out.append(" ")
                if name == "begin", let close = group(at: spaces(index)), close - 1 > spaces(index) {
                    let raw = String(chars[(spaces(index) + 1)..<(close - 1)])
                    index = close
                    if mathEnvironments.contains(raw.replacingOccurrences(of: "*", with: "")) { index = skipEnvironment(raw, from: index) }
                } else if nameCommands.contains(name) {
                    // Any optional arguments, then the one argument that holds the name.
                    var at = spaces(index)
                    while at < chars.count, chars[at] == "[", let close = group(at: at) { at = spaces(close) }
                    if at < chars.count, chars[at] == "{", let close = group(at: at) { index = close }
                }
            } else {
                out.append(char)
                index += 1
            }
        }
        return out
    }

    /// The number of words of `lines`: a run of letters and digits is one word (an apostrophe, a
    /// hyphen or a full stop between two of them does not end it), and each Chinese character,
    /// kana or hangul syllable is one word.
    static func words(in lines: [String]) -> Int {
        let scalars = Array(prose(lines).unicodeScalars)
        var count = 0
        var inWord = false
        for (index, scalar) in scalars.enumerated() {
            if isCJK(scalar) { count += 1; inWord = false; continue }
            if scalar.properties.isAlphabetic || scalar.properties.numericType == .decimal {
                if !inWord { count += 1; inWord = true }
                continue
            }
            let joins = ["'", "\u{2019}", "-", "."].contains(String(scalar))
            let between = inWord && index + 1 < scalars.count && !isCJK(scalars[index + 1])
                && (scalars[index + 1].properties.isAlphabetic || scalars[index + 1].properties.numericType == .decimal)
            if !(joins && between) { inWord = false }
        }
        return count
    }

    // MARK: sections

    struct Section {
        let id: String
        let parent: String?
        let part: String
        let length: Int?
    }

    /// The sections that are not dropped, in file order, each with the part it goes to: its own
    /// `part`, else that of the section it is under, else `main`.
    static func sections(_ outline: Outline) -> [Section] {
        var out: [Section] = []
        var parts: [JSONKey: String] = [:]
        for record in outline.sections.compactMap(\.value) {
            guard let id = record["id"]?.string else { continue }
            let parent = record["parent"]?.string
            let part = record["part"]?.string ?? parent.flatMap { parts[JSONKey($0)] } ?? "main"
            parts[JSONKey(id)] = part
            if !record.has("dropped") { out.append(Section(id: id, parent: parent, part: part, length: count(record["length"]))) }
        }
        return out
    }

    public struct Failure: Error {
        public let message: String
    }

    /// The report. `written` gives the ledger and the main file when what was written is to be
    /// counted; without it only the targets are reported.
    /// With `documents`, each trace record is looked up in the ledger and main file of its part
    /// (issue 120); a record of a part without a document is not counted.
    static func report(outline: Outline, article: Article?, trace: Data?, written: (ledger: Data, main: URL)?,
                       documents: [String: (ledger: Data, main: URL)]? = nil) throws -> [String] {
        if let documents {
            // One pass per document (a main file with a ledger), over the trace records of its parts in trace
            // order, so that a paragraph two parts of one document name is counted once.
            var tables: [(words: [JSONKey: Int], done: [JSONKey: Int], unplaced: Int)] = []
            let groups = Dictionary(grouping: documents.keys.sorted()) {
                Data(((Article.real(documents[$0]!.main) ?? documents[$0]!.main.path) + "\n" + WriteParagraph.sha256(documents[$0]!.ledger)).utf8)
            }
            for parts in groups.values.sorted(by: { $0[0] < $1[0] }) {
                let lines = Outline.lines(of: trace ?? Data()).filter { parts.contains(WriteFromOutline.part(of: $0.value)) }
                tables.append(try count(outline: outline, trace: lines, written: documents[parts[0]]!))
            }
            let known = Set(documents.keys)
            let strays = Outline.lines(of: trace ?? Data()).filter { !known.contains(WriteFromOutline.part(of: $0.value)) }.count
            let words = tables.reduce(into: [JSONKey: Int]()) { $0.merge($1.words, uniquingKeysWith: +) }
            let done = tables.reduce(into: [JSONKey: Int]()) { $0.merge($1.done, uniquingKeysWith: +) }
            return render(outline: outline, article: article, words: words, done: done, counted: true,
                          unplaced: tables.reduce(strays) { $0 + $1.unplaced })
        }
        guard let written else {
            return render(outline: outline, article: article, words: [:], done: [:], counted: false, unplaced: 0)
        }
        let table = try count(outline: outline, trace: Outline.lines(of: trace ?? Data()), written: written)
        return render(outline: outline, article: article, words: table.words, done: table.done, counted: true, unplaced: table.unplaced)
    }

    /// The words and the number of written records of each section, from the records `trace`.
    static func count(outline: Outline, trace: [OutlineLine], written: (ledger: Data, main: URL)) throws
        -> (words: [JSONKey: Int], done: [JSONKey: Int], unplaced: Int)
    {
        var words: [JSONKey: Int] = [:], done: [JSONKey: Int] = [:]
        var unplaced = 0
        do {
            let rows = try ReviseLedger.lines(written.ledger)
            let mainURL = written.main.resolvingSymlinksInPath().standardizedFileURL
            var files: [String: [String]] = [:]
            /// A file of the manuscript that cannot be read is not a missing proposition: it stops the report.
            func lines(_ name: String?) throws -> [String] {
                let key = name.flatMap { $0 == "main.tex" ? nil : ReadingOrder.normalise($0) }
                let url = key.map { mainURL.deletingLastPathComponent().appendingPathComponent($0) } ?? mainURL
                if let known = files[url.path] { return known }
                guard let data = LedgerOrder.read(url)?.data, let text = String(data: data, encoding: .utf8) else {
                    throw WriteParagraph.Failure(message: "cannot read \(CiteOrder.visible(url.path)) as UTF-8")
                }
                let split = LatexLine.splitLines(text)
                files[url.path] = split
                return split
            }
            _ = try lines(nil)
            let records = outline.paragraphs.compactMap(\.value)
            // A paragraph: a file and a run of lines in it.
            var seen = Set<Data>()
            for line in trace {
                guard let outlineID = line.value?["outline"]?.string, let first = line.value?["first_prop"]?.string else { continue }
                guard let record = records.first(where: { WriteFromOutline.same($0["id"]?.string, outlineID) }), !record.has("dropped"),
                      let section = record["section"]?.string else { continue }
                let live = rows.filter { WriteFromOutline.same($0.id, first) && !$0.isRetired }
                guard live.count == 1, let location = live[0].location else { unplaced += 1; continue }
                let text = try lines(location.file)
                guard location.start >= 1, location.start <= text.count, let run = Paragraphs.runs(text)[location.start - 1] else { unplaced += 1; continue }
                // A paragraph is counted once, for the first record that names a proposition in it.
                let file = location.file.flatMap { $0 == "main.tex" ? nil : ReadingOrder.normalise($0) } ?? ""
                guard seen.insert(Data("\(file)\n\(run)".utf8)).inserted else { continue }
                let runs = Paragraphs.runs(text)
                let own = text.indices.filter { runs[$0] == run && !WriteParagraph.beginsHeading(text[$0]) }.map { text[$0] }
                words[JSONKey(section), default: 0] += OutlineLength.words(in: own)
                done[JSONKey(section), default: 0] += 1
            }
        }
        return (words, done, unplaced)
    }

    static func render(outline: Outline, article: Article?, words: [JSONKey: Int], done: [JSONKey: Int], counted: Bool, unplaced: Int) -> [String] {
        let all = sections(outline)
        var planned: [JSONKey: Int] = [:]
        for record in outline.paragraphs.compactMap(\.value) where !record.has("dropped") {
            if let section = record["section"]?.string { planned[JSONKey(section), default: 0] += 1 }
        }
        // A section's numbers take in the sections under it.
        func under(_ id: String) -> [Section] { all.filter { $0.parent.map { WriteFromOutline.same($0, id) } ?? false }.flatMap { [$0] + under($0.id) } }
        func total(_ table: [JSONKey: Int], _ section: Section) -> Int { ([section] + under(section.id)).reduce(0) { $0 + (table[JSONKey($1.id)] ?? 0) } }
        func ancestors(_ section: Section) -> [Section] {
            guard let parent = section.parent, let above = all.first(where: { WriteFromOutline.same($0.id, parent) }) else { return [] }
            return [above] + ancestors(above)
        }
        var out: [String] = []
        for section in all {
            let below = under(section.id).filter { $0.parent.map { WriteFromOutline.same($0, section.id) } ?? false }.compactMap(\.length).reduce(0, +)
            var line = "\(JSONValue.quoted(section.id))\t\(section.part)\ttarget \(section.length.map(String.init) ?? "-")"
            if counted {
                let count = total(words, section)
                line += "\twritten \(count)\t\(total(done, section)) of \(total(planned, section)) record(s)"
                if let target = section.length, count > target { line += "\tover its target by \(count - target)" }
            }
            if let target = section.length, below > target { line += "\tits subsections plan \(below)" }
            out.append(line)
        }
        let parts = ["main", "appendix", "supplement"].filter { part in all.contains { $0.part == part } }
        func targets(_ part: String) -> Int { all.filter { $0.part == part && !ancestors($0).contains { $0.length != nil } }.compactMap(\.length).reduce(0, +) }
        func count(_ part: String) -> Int { all.filter { $0.part == part }.reduce(0) { $0 + (words[JSONKey($1.id)] ?? 0) } }
        for part in parts {
            out.append("part \(part)\ttargets \(targets(part))" + (counted ? "\twritten \(count(part))" : ""))
        }
        if let limit = article?.length {
            let sum = limit.parts.reduce(0) { $0 + targets($1) }
            var line = "limit \(limit.limit)\t\(limit.parts.joined(separator: ","))\ttargets \(sum)" + (sum > limit.limit ? " (over by \(sum - limit.limit))" : "")
            if counted {
                let total = limit.parts.reduce(0) { $0 + count($1) }
                line += "\twritten \(total)" + (total > limit.limit ? " (over by \(total - limit.limit))" : "")
            }
            out.append(line)
        }
        if unplaced > 0 { out.append("\(unplaced) record(s) of the trace name no live proposition of this ledger that starts in a paragraph; they are not counted") }
        out.append("ok length")
        return out
    }
}

/// `propositions outline length`. Exit codes: 0 the report was printed; 2 a file cannot be read.
public enum OutlineLengthRun {
    public static func run(directory: String, jsonl: String?, tex: String?, written fromDestinations: Bool = false, workingDirectory: URL) -> CommandResult {
        func refuse(_ message: String) -> CommandResult { CommandResult(stderr: ["outline length: \(message)"], exitCode: 2) }
        guard (jsonl == nil) == (tex == nil) else { return refuse("--jsonl and --tex go together") }
        guard !(fromDestinations && jsonl != nil) else { return refuse("--written reads the destinations of article.json; it does not go with --jsonl and --tex") }
        let dir = WriteParagraphRun.resolve(directory, workingDirectory)
        do {
            let outline = try Outline(directory: dir)
            if let first = OutlineCheck.findings(outline).first { return refuse("the outline does not pass outline check: \(first)") }
            let article = try Article.read(in: dir)?.article
            var written: (Data, URL)?
            var trace: Data?
            var documents: [String: (ledger: Data, main: URL)]?
            let traceURL = dir.appendingPathComponent(WriteFromOutline.traceFile)
            if fromDestinations {
                guard let destinations = article?.destinations else { return refuse("--written needs the destinations of \(Article.fileName); give --jsonl and --tex for one manuscript") }
                var table: [String: (ledger: Data, main: URL)] = [:]
                for (part, destination) in destinations {
                    let main = Article.resolve(destination.tex, dir)
                    guard let ledger = LedgerOrder.read(Article.resolve(destination.jsonl, dir))?.data, LedgerOrder.read(main) != nil else {
                        return refuse("cannot read the main file or the ledger of the part \(part)")
                    }
                    table[part] = (ledger, main)
                }
                documents = table
                if try !WriteFromOutline.absent(traceURL) { trace = try WriteFromOutline.regular(traceURL).data }
            } else if jsonl != nil, article?.destinations != nil {
                return refuse("\(Article.fileName) names destinations; use --written, which reads each part from its own document")
            }
            if let jsonl, let tex {
                guard let ledger = LedgerOrder.read(WriteParagraphRun.resolve(jsonl, workingDirectory))?.data else {
                    return refuse("cannot read the ledger \(CiteOrder.visible(jsonl))")
                }
                let main = WriteParagraphRun.resolve(tex, workingDirectory)
                guard LedgerOrder.read(main) != nil else { return refuse("cannot read \(CiteOrder.visible(tex))") }
                written = (ledger, main)
                let url = dir.appendingPathComponent(WriteFromOutline.traceFile)
                if try !WriteFromOutline.absent(url) { trace = try WriteFromOutline.regular(url).data }
            }
            return CommandResult(stdout: try OutlineLength.report(outline: outline, article: article, trace: trace, written: written, documents: documents), exitCode: 0)
        } catch {
            return refuse((error as? WriteParagraph.Failure)?.message ?? (error as? Revise.Failure)?.message ?? "\(error)")
        }
    }
}
