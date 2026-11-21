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
        switch scalar.value {
        case 0x3040...0x30FF, 0x3400...0x4DBF, 0x4E00...0x9FFF, 0xAC00...0xD7AF, 0xF900...0xFAFF, 0x20000...0x2FFFF: return true
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
                if chars[at] == "\\", target.first != "\\", at + 1 < chars.count { at += 2; continue }
                if Array(chars[at..<(at + target.count)]) == target { return at + target.count }
                at += 1
            }
            return chars.count
        }
        func group(at start: Int) -> Int? {
            guard start < chars.count, chars[start] == "{" || chars[start] == "[" else { return nil }
            let open = chars[start], close: Character = open == "{" ? "}" : "]"
            var depth = 0, at = start
            while at < chars.count {
                if chars[at] == "\\" { at += 2; continue }
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
                if name == "begin", let close = group(at: index) {
                    let raw = String(chars[min(index + 1, close - 1)..<(close - 1)])
                    index = close
                    if mathEnvironments.contains(raw.replacingOccurrences(of: "*", with: "")) { index = skip(to: "\\end{" + raw + "}", from: index) }
                } else if nameCommands.contains(name) {
                    while let close = group(at: index) { index = close }
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
            if scalar.properties.isAlphabetic || scalar.properties.numericType != nil {
                if !inWord { count += 1; inWord = true }
                continue
            }
            let joins = ["'", "\u{2019}", "-", "."].contains(String(scalar))
            let between = inWord && index + 1 < scalars.count && !isCJK(scalars[index + 1])
                && (scalars[index + 1].properties.isAlphabetic || scalars[index + 1].properties.numericType != nil)
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
    static func report(outline: Outline, article: Article?, trace: Data?, written: (ledger: Data, main: URL)?) throws -> [String] {
        let all = sections(outline)
        var words: [JSONKey: Int] = [:], done: [JSONKey: Int] = [:], planned: [JSONKey: Int] = [:]
        var unplaced = 0
        if let written {
            let rows = try ReviseLedger.lines(written.ledger)
            let mainURL = written.main.resolvingSymlinksInPath().standardizedFileURL
            var files: [String: [String]] = [:]
            func lines(_ name: String?) -> [String]? {
                let key = name.flatMap { $0 == "main.tex" ? nil : ReadingOrder.normalise($0) }
                let url = key.map { mainURL.deletingLastPathComponent().appendingPathComponent($0) } ?? mainURL
                if let known = files[url.path] { return known }
                guard let data = LedgerOrder.read(url)?.data, let text = String(data: data, encoding: .utf8) else { return nil }
                files[url.path] = LatexLine.splitLines(text)
                return files[url.path]
            }
            let records = outline.paragraphs.compactMap(\.value)
            var seen = Set<[UInt32]>()
            for line in Outline.lines(of: trace ?? Data()) {
                guard let outlineID = line.value?["outline"]?.string, let first = line.value?["first_prop"]?.string,
                      seen.insert(ReviseLedger.key(first)).inserted else { continue }
                guard let record = records.first(where: { WriteFromOutline.same($0["id"]?.string, outlineID) }), !record.has("dropped"),
                      let section = record["section"]?.string else { continue }
                let live = rows.filter { WriteFromOutline.same($0.id, first) && !$0.isRetired }
                guard live.count == 1, let location = live[0].location, let text = lines(location.file), location.start >= 1, location.start <= text.count,
                      let run = Paragraphs.runs(text)[location.start - 1] else { unplaced += 1; continue }
                let runs = Paragraphs.runs(text)
                let own = text.indices.filter { runs[$0] == run && !WriteParagraph.beginsHeading(text[$0]) }.map { text[$0] }
                words[JSONKey(section), default: 0] += OutlineLength.words(in: own)
                done[JSONKey(section), default: 0] += 1
            }
        }
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
            if written != nil {
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
            out.append("part \(part)\ttargets \(targets(part))" + (written != nil ? "\twritten \(count(part))" : ""))
        }
        if let limit = article?.length {
            let sum = limit.parts.reduce(0) { $0 + targets($1) }
            var line = "limit \(limit.limit)\t\(limit.parts.joined(separator: ","))\ttargets \(sum)" + (sum > limit.limit ? " (over by \(sum - limit.limit))" : "")
            if written != nil {
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
    public static func run(directory: String, jsonl: String?, tex: String?, workingDirectory: URL) -> CommandResult {
        func refuse(_ message: String) -> CommandResult { CommandResult(stderr: ["outline length: \(message)"], exitCode: 2) }
        guard (jsonl == nil) == (tex == nil) else { return refuse("--jsonl and --tex go together") }
        let dir = WriteParagraphRun.resolve(directory, workingDirectory)
        do {
            let outline = try Outline(directory: dir)
            if let first = OutlineCheck.findings(outline).first { return refuse("the outline does not pass outline check: \(first)") }
            let article = try Article.read(in: dir)?.article
            var written: (Data, URL)?
            var trace: Data?
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
            return CommandResult(stdout: try OutlineLength.report(outline: outline, article: article, trace: trace, written: written), exitCode: 0)
        } catch {
            return refuse((error as? WriteParagraph.Failure)?.message ?? (error as? Revise.Failure)?.message ?? "\(error)")
        }
    }
}
