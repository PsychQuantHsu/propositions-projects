import Foundation

/// The comparison of a text with the banned phrasings of `article.json` (issue 118).
///
/// Letter case does not count, a run of white space (a line break included) is one space, the
/// text from an unescaped `%` to the end of its line is not compared, both sides are in
/// normalisation form C, and a phrasing does not run across an empty line. It is literal.
enum Phrasing {
    /// Stands between two paragraphs in the folded text; no phrase holds it.
    static let paragraphBreak: UInt32 = 0

    /// A text without the difference of letter case, in form C: upper case and then lower case,
    /// so that `ß` and `SS`, and the two lower-case sigmas, compare equal.
    static func caseless(_ text: String) -> String {
        // Lower case first: the capital sharp s has no upper-case mapping of its own.
        text.precomposedStringWithCanonicalMapping.lowercased().uppercased().lowercased().precomposedStringWithCanonicalMapping
    }

    /// A phrase as it is compared: without letter case, in form C, each run of white space one
    /// space. White space at an end of the phrase is one space there too: `" cat "` is not `cat`.
    /// Empty when the phrase holds nothing but white space.
    static func fold(_ phrase: String) -> [UInt32] {
        var out: [UInt32] = []
        var space = false
        var any = false
        for scalar in caseless(phrase).unicodeScalars {
            if scalar.properties.isWhitespace { space = true; continue }
            if space { out.append(0x20) }
            space = false
            any = true
            out.append(scalar.value)
        }
        if space, any { out.append(0x20) }
        return any ? out : []
    }

    /// The line without its comment: the text before the first `%` that an odd number of
    /// backslashes does not come before.
    /// It looks at scalars, not characters: a `%` with a combining mark after it is still a `%`.
    static func withoutComment(_ line: String) -> Substring {
        var backslashes = 0
        let scalars = line.unicodeScalars
        for index in scalars.indices {
            if scalars[index] == "\\" { backslashes += 1; continue }
            if scalars[index] == "%", backslashes % 2 == 0 { return Substring(scalars[..<index]) }
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
                // The line break that ends a paragraph is white space after its last word.
                if space, let last = text.last, last != paragraphBreak { text.append(0x20); lineOf.append(lineOf[lineOf.count - 1]) }
                text.append(paragraphBreak); lineOf.append(first + offset)
                space = false
                continue
            }
            for scalar in caseless(String(withoutComment(line))).unicodeScalars {
                if scalar.properties.isWhitespace { space = true; continue }
                // White space before the first word of a paragraph is a space too.
                if space { text.append(0x20); lineOf.append(first + offset) }
                space = false
                text.append(scalar.value); lineOf.append(first + offset)
            }
            space = true
        }
        if space, let last = text.last, last != paragraphBreak { text.append(0x20); lineOf.append(lineOf[lineOf.count - 1]) }
        var found: [(at: Int, order: Int, line: String)] = []
        for (order, entry) in banned.enumerated() {
            let phrase = fold(entry.phrase)
            guard !phrase.isEmpty, phrase.count <= text.count else { continue }
            var start = 0
            while start + phrase.count <= text.count {
                if text[start] == phrase[0], text[start..<(start + phrase.count)].elementsEqual(phrase) {
                    // The line of the first character that is not the space a phrase can begin with.
                    let at = phrase[0] == 0x20 && start + 1 < text.count ? start + 1 : start
                    found.append((start, order, "\(CiteOrder.visible(file)):L\(lineOf[at]): the banned phrasing \(JSONValue.quoted(entry.phrase)) (\(CiteOrder.visible(entry.reason)))"))
                }
                start += 1   // every start is tried: occurrences can overlap
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
