import Foundation

/// The manuscript as the two audits read it: every file of the main file's input tree, each with
/// its lines as written and the lines with comments removed.
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

    /// One file of the manuscript.
    struct Source {
        /// The name a report gives it: the manuscript root as it was given, then the path from it.
        let shown: String
        let url: URL
        /// The lines as written.
        let lines: [String]
        /// The lines with comments and every verbatim-like environment removed.
        let code: [String]
        /// The text inside verbatim-like environments other than `comment`, line by line: it is
        /// printed as it is written, so a path in it is read like a path in running text.
        let verbatim: [String]
    }

    struct Manuscript {
        let sources: [Source]
        /// The directory of the main file: where LaTeX and BibTeX look for a file it names.
        let mainDirectory: URL
        let root: URL
        let rootShown: String
        let notes: [String]
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

    /// How a report names a file: from the root as it was given, as Python's `Path` would join them.
    static func shown(_ url: URL, root: URL, rootShown: String) -> String {
        let relative = ReadingOrder.relativePath(of: url.standardizedFileURL, from: root.standardizedFileURL)
        if relative.hasPrefix("..") { return url.standardizedFileURL.path }
        return rootShown == "." ? relative : rootShown + "/" + relative
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
            let (code, verbatim) = LatexText.split(lines)
            sources.append(Source(shown: shown(url, root: root, rootShown: rootShown), url: url,
                                  lines: lines, code: code, verbatim: verbatim))
        }
        let notes = order.skippedImports.map {
            "[warn] non-standard import macro skipped at \(CiteOrder.visible($0)) (\\subimport/\\subfile/\\import unsupported)"
        }
        return Manuscript(sources: sources, mainDirectory: directory, root: root, rootShown: rootShown, notes: notes)
    }

    /// The lines around a line, as the report shows them: the one before, the line, the one after.
    static func context(_ lines: [String], line: Int) -> String {
        let start = max(0, line - 2)
        let end = min(lines.count, line + 1)
        return start < end ? lines[start..<end].joined(separator: "\n") : ""
    }
}

/// Reading LaTeX source a character at a time: comments, verbatim-like environments, groups.
enum LatexText {
    /// For each line, the text outside comments and verbatim-like environments, and the text
    /// inside verbatim-like environments other than `comment`.
    static func split(_ lines: [String]) -> (code: [String], verbatim: [String]) {
        var code: [String] = []
        var verbatim: [String] = []
        var environment: String?
        for raw in lines {
            var rest = raw[...]
            var codeOut = ""
            var verbatimOut = ""
            while true {
                if let inside = environment {
                    let kept = !inside.hasPrefix("comment")
                    guard let end = LatexLine.command("\\end{\(inside)}", in: rest) else {
                        if kept { verbatimOut += rest }
                        break
                    }
                    if kept { verbatimOut += rest[..<end.lowerBound] }
                    environment = nil
                    rest = rest[end.upperBound...]
                    continue
                }
                let comment = commentStart(rest)
                var begin: (range: Range<Substring.Index>, name: String)?
                for name in LatexLine.verbatimEnvironments.flatMap({ [$0, $0 + "*"] }) {
                    if let range = LatexLine.command("\\begin{\(name)}", in: rest),
                       begin == nil || range.lowerBound < begin!.range.lowerBound {
                        begin = (range, name)
                    }
                }
                if let begin, comment == nil || begin.range.lowerBound < comment! {
                    codeOut += rest[..<begin.range.lowerBound]
                    environment = begin.name
                    rest = rest[begin.range.upperBound...]
                    continue
                }
                codeOut += comment.map { rest[..<$0] } ?? rest
                break
            }
            code.append(codeOut)
            verbatim.append(verbatimOut)
        }
        return (code, verbatim)
    }

    /// Where a `%` comment starts. `\%` is a percent sign, `\\%` a line break and a comment, and a
    /// `%` inside `\verb|…|` or `\lstinline|…|` is text.
    static func commentStart(_ text: Substring) -> Substring.Index? {
        var index = text.startIndex
        while index < text.endIndex {
            let ch = text[index]
            if ch == "%" { return index }
            guard ch == "\\" else { index = text.index(after: index); continue }
            let next = text.index(after: index)
            guard next < text.endIndex else { return nil }
            guard text[next].isLetter else { index = text.index(after: next); continue }
            var end = next
            while end < text.endIndex, text[end].isLetter { end = text.index(after: end) }
            let name = text[next..<end]
            if name == "verb" || name == "lstinline" {
                var start = end
                if name == "verb", start < text.endIndex, text[start] == "*" { start = text.index(after: start) }
                if start < text.endIndex, !text[start].isLetter, !text[start].isWhitespace, text[start] != "{", text[start] != "[" {
                    let delimiter = text[start]
                    let body = text.index(after: start)
                    guard let close = text[body...].firstIndex(of: delimiter) else { return nil }
                    index = text.index(after: close)
                    continue
                }
            }
            index = end
        }
        return nil
    }

    /// The group that opens at `start` (`{`, `[` or `(`), as the content and the index after it.
    /// Groups of the same kind nest; a backslash keeps the character after it from counting.
    static func group(_ chars: [Character], at start: Int) -> (content: String, end: Int)? {
        guard start < chars.count else { return nil }
        let open = chars[start]
        let close: Character
        switch open {
        case "{": close = "}"
        case "[": close = "]"
        case "(": close = ")"
        default: return nil
        }
        var depth = 0
        var index = start
        while index < chars.count {
            let ch = chars[index]
            if ch == "\\" { index += 2; continue }
            if ch == open { depth += 1 }
            if ch == close {
                depth -= 1
                if depth == 0 { return (String(chars[(start + 1)..<index]), index + 1) }
            }
            index += 1
        }
        return nil
    }

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
