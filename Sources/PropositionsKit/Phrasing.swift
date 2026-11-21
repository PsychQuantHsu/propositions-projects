import Foundation

/// The comparison of a text with the banned phrasings of `article.json` (issue 118).
///
/// Letter case does not count, a run of white space (a line break included) is one space, the
/// text from an unescaped `%` to the end of its line is not compared, both sides are in
/// normalisation form C, and a phrasing does not run across an empty line. It is literal.
enum Phrasing {
    /// Stands between two paragraphs in the folded text; no phrase holds it.
    static let paragraphBreak: UInt32 = 0

    /// A phrase as it is compared: lower case, form C, each run of white space one space, none
    /// at either end.
    static func fold(_ phrase: String) -> [UInt32] {
        var out: [UInt32] = []
        var space = false
        for scalar in phrase.precomposedStringWithCanonicalMapping.lowercased().unicodeScalars {
            if scalar.properties.isWhitespace { space = true; continue }
            if space, !out.isEmpty { out.append(0x20) }
            space = false
            out.append(scalar.value)
        }
        return out
    }

    /// The line without its comment: the text before the first `%` that an odd number of
    /// backslashes does not come before.
    static func withoutComment(_ line: String) -> Substring {
        var backslashes = 0
        for index in line.indices {
            if line[index] == "\\" { backslashes += 1; continue }
            if line[index] == "%", backslashes % 2 == 0 { return line[..<index] }
            backslashes = 0
        }
        return line[...]
    }

    /// One line per occurrence, in the order of the text: `<file>:L<line>: the banned phrasing
    /// "<phrase>" (<reason>)`. `first` is the number of the first of `lines` in its file.
    static func occurrences(in lines: [String], first: Int = 1, file: String, banned: [Article.Banned]) -> [String] {
        var text: [UInt32] = []
        var lineOf: [Int] = []
        var space = false
        for (offset, line) in lines.enumerated() {
            if LedgerOrder.stripped(line).isEmpty {
                text.append(paragraphBreak); lineOf.append(first + offset)
                space = false
                continue
            }
            for scalar in String(withoutComment(line)).precomposedStringWithCanonicalMapping.lowercased().unicodeScalars {
                if scalar.properties.isWhitespace { space = true; continue }
                if space, let last = text.last, last != paragraphBreak { text.append(0x20); lineOf.append(first + offset) }
                space = false
                text.append(scalar.value); lineOf.append(first + offset)
            }
            space = true
        }
        var found: [(at: Int, order: Int, line: String)] = []
        for (order, entry) in banned.enumerated() {
            let phrase = fold(entry.phrase)
            guard !phrase.isEmpty, phrase.count <= text.count else { continue }
            var start = 0
            while start + phrase.count <= text.count {
                if text[start] == phrase[0], text[start..<(start + phrase.count)].elementsEqual(phrase) {
                    found.append((start, order, "\(CiteOrder.visible(file)):L\(lineOf[start]): the banned phrasing \(JSONValue.quoted(entry.phrase)) (\(CiteOrder.visible(entry.reason)))"))
                    start += phrase.count
                } else {
                    start += 1
                }
            }
        }
        return found.sorted { ($0.at, $0.order) < ($1.at, $1.order) }.map(\.line)
    }
}

/// `propositions phrasing`. Exit codes: 0 no occurrence; 1 an occurrence; 2 a file cannot be
/// read or `article.json` is not in the format.
public enum PhrasingRun {
    public static func run(tex: String, article: String, workingDirectory: URL) -> CommandResult {
        func refuse(_ message: String) -> CommandResult { CommandResult(stderr: ["error: \(message)"], exitCode: 2) }
        let main = WriteParagraphRun.resolve(tex, workingDirectory)
        guard let data = LedgerOrder.read(WriteParagraphRun.resolve(article, workingDirectory))?.data else {
            return refuse("cannot read \(CiteOrder.visible(article))")
        }
        let parsed: Article
        do { parsed = try Article.parse(data) } catch { return refuse((error as? Article.Failure)?.message ?? "article.json cannot be read") }
        let order: ReadingOrder
        do { order = try ReadingOrder(mainFile: main) } catch { return refuse(CiteOrder.visible("\(error)")) }
        let mainURL = main.resolvingSymlinksInPath()
        let directory = mainURL.standardizedFileURL.deletingLastPathComponent()
        var out: [String] = []
        for (index, name) in order.files.enumerated() {
            let url = index == 0 ? mainURL : directory.appendingPathComponent(name)
            guard let bytes = LedgerOrder.read(url)?.data, let text = String(data: bytes, encoding: .utf8) else {
                return refuse("cannot read \(CiteOrder.visible(name)) as UTF-8")
            }
            out += Phrasing.occurrences(in: LatexLine.splitLines(text), file: index == 0 ? mainURL.lastPathComponent : name, banned: parsed.banned)
        }
        let count = out.count
        out.append("\(count) occurrence(s) of \(parsed.banned.count) banned phrasing(s) in \(order.files.count) file(s)")
        return CommandResult(stdout: out, exitCode: count == 0 ? 0 : 1)
    }
}
