import Foundation

/// The manuscript as the two audits read it: every file of the main file's input tree, each read
/// as one stream of characters, as TeX reads it, with the place of every character kept.
public enum Audit {
    public struct Failure: Error, Equatable {
        public let message: String
    }

    public struct Finding: Equatable, Sendable {
        public let rule: String
        public let severity: String
        public let file: String
        public let line: Int
        public let match: String
        public let context: String
        public let proposedFix: String
    }

    public static let severities = ["definite", "likely", "suspicious", "FYI"]

    /// Characters taken from a file, each with its offset in the file's text.
    struct Piece {
        var chars: [Character] = []
        var offsets: [Int] = []

        mutating func take(_ text: [Character], _ range: Range<Int>) {
            for index in range where index < text.count {
                chars.append(text[index])
                offsets.append(index)
            }
        }
    }

    /// One file of the manuscript.
    struct Source {
        /// The name a report gives it: the manuscript root as it was given, then the path from it.
        let shown: String
        let url: URL
        /// Its name in the input tree; `nil` for the main file.
        let key: String?
        /// The lines as written, for the context of a finding.
        let lines: [String]
        /// The text, its lines joined with line feeds.
        let text: [Character]
        let lineStarts: [Int]
        /// What TeX reads as source: comments (with the line end they swallow), the text of
        /// `\verb`, `\lstinline` and verbatim-like environments are not in it.
        let code: Piece
        /// The text TeX prints as it is written: `\verb`, `\lstinline`, and verbatim-like
        /// environments that print their body.
        let displayed: [Piece]

        func line(of offset: Int) -> Int {
            var low = 0, high = lineStarts.count - 1
            while low < high {
                let mid = (low + high + 1) / 2
                if lineStarts[mid] <= offset { low = mid } else { high = mid - 1 }
            }
            return low + 1
        }
    }

    struct Manuscript {
        let sources: [Source]
        let order: ReadingOrder
        /// The directory of the main file: where LaTeX and BibTeX look for a file it names.
        let mainDirectory: URL
        let root: URL
        let rootShown: String
        let notes: [String]

        /// Where a line of a source comes in the manuscript's reading order.
        func position(source: Int, offset: Int) -> [Int] {
            let item = sources[source]
            return order.position(file: item.key, line: item.line(of: offset)) ?? [Int.max]
        }

        /// Whether a place comes before another: by reading order, then, on one line, by offset.
        static func precedes(_ a: (position: [Int], offset: Int), _ b: (position: [Int], offset: Int)) -> Bool {
            a.position == b.position ? a.offset < b.offset : ReadingOrder.precedes(a.position, b.position)
        }
    }

    /// Strict UTF-8 that keeps a byte-order mark as the character it is.
    static func text(of url: URL) -> String? {
        var info = stat()
        guard stat(url.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG,
              let data = FileManager.default.contents(atPath: url.path)
        else { return nil }
        var scalars = String.UnicodeScalarView()
        var decoder = UTF8()
        var bytes = data.makeIterator()
        while true {
            switch decoder.decode(&bytes) {
            case .scalarValue(let scalar): scalars.append(scalar)
            case .emptyInput: return String(scalars)
            case .error: return nil
            }
        }
    }

    /// How a report names a file: the root as it was given, then the path from it. A file outside
    /// the root is named by its full path.
    static func shown(_ url: URL, root: URL, rootShown: String) -> String {
        let relative = ReadingOrder.relativePath(of: url.standardizedFileURL, from: root.standardizedFileURL)
        if relative.split(separator: "/").first == ".." { return url.standardizedFileURL.path }
        if rootShown == "." { return relative }
        return rootShown.hasSuffix("/") ? rootShown + relative : rootShown + "/" + relative
    }

    static func read(root: URL, rootShown given: String, main: URL) throws -> Manuscript {
        var rootShown = given
        while rootShown.count > 1, rootShown.hasSuffix("/") { rootShown.removeLast() }
        guard text(of: main) != nil else {
            throw Failure(message: "\(CiteOrder.visible(shown(main, root: root, rootShown: rootShown))) not found, or not a UTF-8 file")
        }
        let order: ReadingOrder
        do {
            order = try ReadingOrder(mainFile: main)
        } catch {
            throw Failure(message: CiteOrder.visible("\(error)"))
        }
        let resolved = main.resolvingSymlinksInPath().standardizedFileURL
        let directory = resolved.deletingLastPathComponent()
        var sources: [Source] = []
        for (index, key) in order.files.enumerated() {
            // The main file under the name it was given; an included file from the main file's directory.
            let url = index == 0 ? main.standardizedFileURL : directory.appendingPathComponent(key).standardizedFileURL
            guard let content = text(of: index == 0 ? resolved : url) else {
                throw Failure(message: "cannot read \(CiteOrder.visible(key)) as UTF-8")
            }
            let lines = LatexLine.splitLines(content)
            let text = Array(lines.joined(separator: "\n"))
            var starts = [0]
            for (offset, ch) in text.enumerated() where ch == "\n" { starts.append(offset + 1) }
            let (code, displayed) = LatexText.tokenize(text)
            sources.append(Source(
                shown: shown(url, root: root, rootShown: rootShown), url: url, key: index == 0 ? nil : key,
                lines: lines, text: text, lineStarts: starts, code: code, displayed: displayed))
        }
        let notes = order.skippedImports.map {
            "[warn] non-standard import macro skipped at \(CiteOrder.visible($0)) (\\subimport/\\subfile/\\import unsupported)"
        }
        return Manuscript(sources: sources, order: order, mainDirectory: directory, root: root, rootShown: rootShown, notes: notes)
    }

    /// The lines around a line, as the report shows them: the one before, the line, the one after.
    static func context(_ lines: [String], line: Int) -> String {
        let start = max(0, line - 2)
        let end = min(lines.count, line + 1)
        return start < end ? lines[start..<end].joined(separator: "\n") : ""
    }
}

/// Reading LaTeX source a character at a time.
enum LatexText {
    /// Verbatim-like environments, and whether they print their body.
    static let literalEnvironments: [String: Bool] = [
        "verbatim": true, "Verbatim": true, "BVerbatim": true, "lstlisting": true, "minted": true,
        "comment": false, "filecontents": false,
    ]

    /// Commands whose braced argument TeX reads as it is written, `%` included.
    static let literalArgument: Set<String> = ["url", "path", "nolinkurl", "href"]

    /// What stands in the source for text read as it is written (`\verb|…|`, the body of a verbatim
    /// environment, the address of `\url`): not white space, so that what is around it is not joined,
    /// and not a character a command, a key or a path is made of.
    static let opaque: Character = "\u{FFFC}"

    /// Splits a file's text into what TeX reads as source and what it prints as it is written.
    static func tokenize(_ text: [Character]) -> (code: Audit.Piece, displayed: [Audit.Piece]) {
        var code = Audit.Piece()
        var displayed: [Audit.Piece] = []
        let count = text.count
        func show(_ range: Range<Int>) {
            var piece = Audit.Piece()
            piece.take(text, range)
            displayed.append(piece)
        }
        func hide(at offset: Int) {
            code.chars.append(opaque)
            code.offsets.append(offset)
        }
        /// The index of `ch` after `start` on the same line.
        func onLine(_ ch: Character, after start: Int) -> Int? {
            var index = start
            while index < count, text[index] != "\n" {
                if text[index] == ch { return index }
                index += 1
            }
            return nil
        }
        /// The argument of a command that reads it as written: copied into the source with its text
        /// made opaque, and shown.
        func literal(_ group: (range: Range<Int>, end: Int), open: Int) {
            code.take(text, open..<(open + 1))
            for offset in group.range { hide(at: offset) }
            code.take(text, (group.end - 1)..<group.end)
            show(group.range)
        }
        var index = 0
        while index < count {
            let ch = text[index]
            if ch == "%" {
                // A comment, and the line end it swallows.
                while index < count, text[index] != "\n" { index += 1 }
                index += 1
                continue
            }
            guard ch == "\\", index + 1 < count else { code.take(text, index..<(index + 1)); index += 1; continue }
            guard text[index + 1].isLetter else { code.take(text, index..<(index + 2)); index += 2; continue }
            var end = index + 1
            while end < count, text[end].isLetter { end += 1 }
            let name = String(text[(index + 1)..<end])
            switch name {
            case "begin":
                guard let (environment, after) = environmentName(text, from: end) else { break }
                let base = environment.hasSuffix("*") ? String(environment.dropLast()) : environment
                guard let printed = literalEnvironments[base] else { break }
                var body = after
                if ["lstlisting", "minted", "Verbatim", "BVerbatim"].contains(base) {
                    if body < count, text[body] == "[", let group = group(text, at: body) { body = group.end }
                }
                if base == "minted" {
                    let next = skipSpace(text, from: body)
                    if next < count, text[next] == "{", let group = group(text, at: next) { body = group.end }
                }
                let close = endOfEnvironment(text, environment, from: body, ownLine: base == "comment") ?? (count, count)
                hide(at: index)
                if printed { show(body..<close.0) }
                index = close.1
                continue
            case "verb":
                var at = end
                if at < count, text[at] == "*" { at += 1 }
                if at < count, !text[at].isLetter, !text[at].isWhitespace, let close = onLine(text[at], after: at + 1) {
                    hide(at: index)
                    show((at + 1)..<close)
                    index = close + 1
                    continue
                }
            case "lstinline":
                var at = end
                if at < count, text[at] == "[", let group = group(text, at: at) { at = group.end }
                if at < count, text[at] == "{", let group = group(text, at: at) {
                    hide(at: index)
                    show(group.range)
                    index = group.end
                    continue
                }
                if at < count, !text[at].isLetter, !text[at].isWhitespace, let close = onLine(text[at], after: at + 1) {
                    hide(at: index)
                    show((at + 1)..<close)
                    index = close + 1
                    continue
                }
            default:
                guard literalArgument.contains(name) else { break }
                code.take(text, index..<end)
                var at = end
                if name == "href", at < count, text[at] == "[", let options = group(text, at: at) {
                    code.take(text, at..<options.end)
                    at = options.end
                }
                let next = skipSpace(text, from: at)
                code.take(text, at..<next)
                if next < count, text[next] == "{", let group = group(text, at: next) {
                    literal(group, open: next)
                    index = group.end
                } else {
                    index = next
                }
                continue
            }
            code.take(text, index..<end)
            index = end
        }
        return (code, displayed)
    }

    /// The name in `{…}` after `\begin`, and the index after its closing brace. White space and a
    /// comment may stand between them.
    static func environmentName(_ text: [Character], from start: Int) -> (String, Int)? {
        var at = start
        while at < text.count {
            if text[at].isWhitespace { at += 1; continue }
            if text[at] == "%" {
                while at < text.count, text[at] != "\n" { at += 1 }
                continue
            }
            break
        }
        guard at < text.count, text[at] == "{", let close = text[at...].firstIndex(of: "}") else { return nil }
        return (String(text[(at + 1)..<close]).trimmingCharacters(in: .whitespaces), close + 1)
    }

    /// Where `\end{name}` starts and the index after it, from `start`. Inside the environment
    /// nothing is a command but its own end; with `ownLine`, as for `comment`, only an end that
    /// begins its line counts.
    static func endOfEnvironment(_ text: [Character], _ name: String, from start: Int, ownLine: Bool) -> (Int, Int)? {
        var index = start
        let marker = Array("\\end")
        while index + marker.count <= text.count {
            if Array(text[index..<(index + marker.count)]) == marker,
               let (found, after) = environmentName(text, from: index + marker.count), found == name {
                var lineStart = index
                while lineStart > 0, text[lineStart - 1] != "\n" { lineStart -= 1 }
                if !ownLine || text[lineStart..<index].allSatisfy({ $0 == " " || $0 == "\t" }) { return (index, after) }
            }
            index += 1
        }
        return nil
    }

    /// The group that opens at `start` (`{`, `[` or `(`): the range of its content, and the index
    /// after it. Braces nest; `[…]` and `(…)` close at their own delimiter only outside braces. A
    /// backslash keeps the character after it from counting.
    static func group(_ chars: [Character], at start: Int) -> (range: Range<Int>, end: Int)? {
        guard start < chars.count else { return nil }
        let open = chars[start]
        let close: Character
        switch open {
        case "{": close = "}"
        case "[": close = "]"
        case "(": close = ")"
        default: return nil
        }
        var braces = 0
        var index = start + 1
        while index < chars.count {
            let ch = chars[index]
            if ch == "\\" { index += 2; continue }
            if open == "{" {
                if ch == "{" { braces += 1 }
                if ch == "}" {
                    if braces == 0 { return ((start + 1)..<index, index + 1) }
                    braces -= 1
                }
            } else {
                if ch == "{" { braces += 1 }
                if ch == "}" { braces = max(0, braces - 1) }
                if ch == close, braces == 0 { return ((start + 1)..<index, index + 1) }
            }
            index += 1
        }
        return nil
    }

    static func content(_ chars: [Character], _ range: Range<Int>) -> String { String(chars[range]) }

    /// The index of the first character at or after `index` that is not white space.
    static func skipSpace(_ chars: [Character], from index: Int) -> Int {
        var at = index
        while at < chars.count, chars[at].isWhitespace { at += 1 }
        return at
    }

    /// Every command in the text: where its backslash is, its name, and the index after the name.
    /// A command written after a backslash that is the second half of `\\` is found; the `\\` is not.
    static func commands(_ chars: [Character]) -> [(start: Int, name: String, end: Int)] {
        var found: [(Int, String, Int)] = []
        var index = 0
        while index < chars.count {
            guard chars[index] == "\\" else { index += 1; continue }
            let next = index + 1
            guard next < chars.count else { break }
            guard chars[next].isLetter else { index = next + 1; continue }
            var end = next
            while end < chars.count, chars[end].isLetter { end += 1 }
            found.append((index, String(chars[next..<end]), end))
            index = end
        }
        return found
    }
}
