import Foundation

/// Why the input tree of a manuscript could not be read. The check stops on each of these.
public enum InputTreeError: Error, Equatable, CustomStringConvertible {
    case unreadable(file: String)
    case missing(target: String, in: String, line: Int)
    case absolute(target: String, in: String, line: Int)
    case cycle(chain: [String])
    case tooDeep(file: String, limit: Int)

    public var description: String {
        switch self {
        case .unreadable(let file):
            return "cannot read \(file)"
        case .missing(let target, let file, let line):
            return "\\input target not found: \(target) (referenced at \(file):\(line))"
        case .absolute(let target, let file, let line):
            return "absolute \\input path refused at \(file):\(line): \(target)"
        case .cycle(let chain):
            return "cyclic \\input chain: \(chain.joined(separator: " -> "))"
        case .tooDeep(let file, let limit):
            return "\\input nesting exceeds max depth \(limit) at \(file)"
        }
    }
}

/// Where each file of a manuscript sits in reading order.
///
/// A position is a list of numbers. Line L of the main file is `[L]`. Line c of the file that
/// the k-th include on line L of the main file names is `[L, k, c]`, and so on for deeper
/// files. Positions compare lexicographically, so the text of an included file comes after the
/// line that includes it, before the next line of the including file, and before the file
/// that a later include on the same line names.
///
/// What this has to agree with is the tool that writes `location`,
/// plugins/propositions/scripts/refresh-prop-locations.py: a line number in a ledger is the
/// number that tool counted, and a file name is the name it wrote. So lines end where that tool
/// ends them (line feed, carriage return, or the two together), and the prefix `main.tex`
/// always means the main file. The tree itself is read by this type's own rules, not by the
/// Python `resolve_input_tree` (issue 94 lists where the two differ); for a manuscript on
/// which they differ, the order here is the order of this tree.
public struct ReadingOrder: Sendable {
    public static let maxDepth = 3

    /// The prefix of every position in an included file, keyed by its path relative to the
    /// directory of the main file (`../shared/defs.tex` for a file outside it).
    private let prefixes: [String: [Int]]
    /// The name of the main file, without its directory.
    public let mainName: String
    /// Files in the order they are first included, the main file first.
    public let files: [String]
    /// Lines that hold an import macro this tool does not follow (`\subimport`, `\subfile`, `\import`).
    public let skippedImports: [String]

    public init(mainFile: URL) throws {
        try self.init(mainFile: mainFile, read: { try? String(contentsOf: $0, encoding: .utf8) })
    }

    /// The tree read through `read`, which gives the text of a file of the tree (issue 131: a
    /// check reads the bytes it was handed, not the file again). A file is still looked up on disk
    /// to find out whether it exists.
    public init(mainFile: URL, read: (URL) -> String?) throws {
        let main = mainFile.resolvingSymlinksInPath().standardizedFileURL
        let root = main.deletingLastPathComponent()
        // Paths are compared as `String`s, and `String` equality is canonical equivalence, so
        // `é.tex` written as one code point or as `e` plus a combining accent is one key. That is
        // deliberate (issue 105): APFS, in both its variants, and HFS+ treat the two names as one
        // file, and this binary runs only on macOS. Comparing bytes instead would break a tree whose
        // `\input` spells a name in one form and whose `location` spells it in the other.
        var prefixes: [String: [Int]] = [:]
        var files: [String] = [main.lastPathComponent]
        var skipped: [String] = []
        var seen: Set<String> = [main.path]

        func visit(_ url: URL, name: String, prefix: [Int], stack: [URL]) throws {
            if stack.count > ReadingOrder.maxDepth {
                throw InputTreeError.tooDeep(file: name, limit: ReadingOrder.maxDepth)
            }
            guard let text = read(url) else {
                throw InputTreeError.unreadable(file: name)
            }
            var environment: String?  // the verbatim-like environment the scan is inside, if any
            for (index, raw) in LatexLine.splitLines(text).enumerated() {
                let lineNumber = index + 1
                let found = LatexLine.scan(LatexLine.maskingLiteralText(raw), environment: &environment)
                if found.unsupportedImport { skipped.append("\(name):\(lineNumber)") }
                for (offset, target) in found.targets.enumerated() {
                    if target.hasPrefix("/") || target.hasPrefix("\\\\") {
                        throw InputTreeError.absolute(target: target, in: name, line: lineNumber)
                    }
                    let relative = target.hasSuffix(".tex") ? target : target + ".tex"
                    let child = root.appendingPathComponent(relative).resolvingSymlinksInPath().standardizedFileURL
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: child.path, isDirectory: &isDirectory),
                          !isDirectory.boolValue
                    else {
                        throw InputTreeError.missing(target: relative, in: name, line: lineNumber)
                    }
                    let chain = stack + [url]
                    if chain.contains(where: { $0.path == child.path }) {
                        throw InputTreeError.cycle(chain: (chain + [child]).map(\.lastPathComponent))
                    }
                    if seen.contains(child.path) { continue }  // counted where it is first included
                    seen.insert(child.path)
                    let key = ReadingOrder.relativePath(of: child, from: root)
                    let childPrefix = prefix + [lineNumber, offset + 1]
                    prefixes[key] = childPrefix
                    files.append(key)
                    try visit(child, name: key, prefix: childPrefix, stack: chain)
                }
            }
        }

        try visit(main, name: main.lastPathComponent, prefix: [], stack: [])
        self.prefixes = prefixes
        self.mainName = main.lastPathComponent
        self.files = files
        self.skippedImports = skipped
    }

    /// The position of a line, or `nil` when the file is not in the input tree.
    ///
    /// A location names the main file when it writes no file or writes `main.tex`, whatever the
    /// main file is called: the tool that writes locations writes that prefix for every
    /// proposition of the main file, and reads no other name for it. An included file that is
    /// itself called `main.tex`, beside a main file of another name, can therefore not be named
    /// by a location. A file written from the root of the file system is in no tree.
    public func position(file: String?, line: Int) -> [Int]? {
        guard let file else { return [line] }
        if file.hasPrefix("/") { return nil }
        let key = ReadingOrder.normalise(file)
        if key == "main.tex" { return [line] }
        if let prefix = prefixes[key] { return prefix + [line] }
        return nil
    }

    /// Whether position `a` comes strictly before position `b`.
    public static func precedes(_ a: [Int], _ b: [Int]) -> Bool {
        for (x, y) in zip(a, b) where x != y { return x < y }
        return a.count < b.count
    }

    /// The path of `url` relative to the directory `root`, with `..` where it leaves it.
    static func relativePath(of url: URL, from root: URL) -> String {
        let target = url.pathComponents
        let base = root.pathComponents
        var common = 0
        while common < target.count, common < base.count, target[common] == base[common] { common += 1 }
        let up = Array(repeating: "..", count: base.count - common)
        return (up + target[common...]).joined(separator: "/")
    }

    /// A relative path with `.` parts dropped and `x/..` folded, as Python's `posixpath.normpath` does.
    static func normalise(_ file: String) -> String {
        var parts: [Substring] = []
        for part in file.split(separator: "/") where part != "." {
            if part == "..", let last = parts.last, last != ".." { parts.removeLast() } else { parts.append(part) }
        }
        return parts.joined(separator: "/")
    }
}

/// The few facts about one line of LaTeX that reading the input tree needs.
enum LatexLine {
    static let verbatimEnvironments = ["verbatim", "Verbatim", "BVerbatim", "lstlisting", "minted", "comment", "filecontents"]

    /// The lines of a text, split where the tool that writes `location` splits them: at a line
    /// feed, at a carriage return, and at the two together as one line end. A form feed and the
    /// other characters Python's `str.splitlines` splits at do not end a line here.
    static func splitLines(_ text: String) -> [String] {
        var lines: [String] = []
        var current = String.UnicodeScalarView()
        var previousWasCR = false
        for scalar in text.unicodeScalars {
            if scalar == "\n" && previousWasCR {
                previousWasCR = false
                continue
            }
            previousWasCR = scalar == "\r"
            if scalar == "\n" || scalar == "\r" {
                lines.append(String(current))
                current = String.UnicodeScalarView()
            } else {
                current.append(scalar)
            }
        }
        if !current.isEmpty { lines.append(String(current)) }
        return lines
    }

    /// The line with each `\verb|…|` and `\lstinline|…|` on it, delimiters included, and the braced
    /// argument of `\url`, `\path`, `\nolinkurl` and `\href`, replaced by spaces: a command written
    /// there as an example (`\verb|\input{x}|`) is not read, nor is a `%` there a comment. A span
    /// that does not close on the line is left as it is.
    static func maskingLiteralText(_ line: String) -> String {
        var chars = Array(line)
        var index = 0
        func blank(_ range: Range<Int>) { for i in range { chars[i] = " " } }
        while index < chars.count {
            guard chars[index] == "\\", index + 1 < chars.count else { index += 1; continue }
            guard chars[index + 1].isLetter else { index += 2; continue }
            var end = index + 1
            while end < chars.count, chars[end].isLetter { end += 1 }
            let name = String(chars[(index + 1)..<end])
            var at = end
            switch name {
            case "verb", "lstinline":
                if name == "verb", at < chars.count, chars[at] == "*" { at += 1 }
                if name == "lstinline", at < chars.count, chars[at] == "[", let options = LatexText.group(chars, at: at) {
                    at = options.end
                }
                guard at < chars.count, !chars[at].isLetter, !chars[at].isWhitespace else { index = end; continue }
                if name == "lstinline", chars[at] == "{", let group = LatexText.group(chars, at: at) {
                    blank(end..<group.end)
                    index = group.end
                    continue
                }
                guard let close = chars[(at + 1)...].firstIndex(of: chars[at]) else { index = end; continue }
                blank(end..<(close + 1))
                index = close + 1
            case "url", "path", "nolinkurl", "href":
                if name == "href", at < chars.count, chars[at] == "[", let options = LatexText.group(chars, at: at) {
                    at = options.end
                }
                while at < chars.count, chars[at] == " " || chars[at] == "\t" { at += 1 }
                guard at < chars.count, chars[at] == "{", let close = chars[(at + 1)...].firstIndex(of: "}") else {
                    index = end
                    continue
                }
                blank((at + 1)..<close)
                index = close + 1
            default:
                index = end
            }
        }
        return String(chars)
    }

    /// What one line holds outside comments and verbatim-like environments.
    struct Found {
        var targets: [String] = []
        var unsupportedImport = false
    }

    /// Reads one line. `environment` is the verbatim-like environment the line starts inside, and
    /// is left as the one it ends inside. An environment ends only at its own `\end`; a `%`
    /// starts a comment only outside one; text before and after an environment on the same line
    /// is read like any other.
    static func scan(_ raw: String, environment: inout String?) -> Found {
        var found = Found()
        var rest = raw[...]
        while true {
            if let inside = environment {
                // Only its own \end closes it: `verbatim*` does not end at `\end{verbatim}`.
                guard let end = command("\\end{\(inside)}", in: rest) else { return found }
                environment = nil
                rest = rest[end.upperBound...]
                continue
            }
            let comment = commentStart(rest)
            var begin: (range: Range<Substring.Index>, name: String)?
            for name in verbatimEnvironments.flatMap({ [$0, $0 + "*"] }) {
                if let range = command("\\begin{\(name)}", in: rest),
                   begin == nil || range.lowerBound < begin!.range.lowerBound {
                    begin = (range, name)
                }
            }
            if let begin, comment == nil || begin.range.lowerBound < comment! {
                read(String(rest[..<begin.range.lowerBound]), into: &found)
                environment = begin.name
                rest = rest[begin.range.upperBound...]
                continue
            }
            read(String(comment.map { rest[..<$0] } ?? rest), into: &found)
            return found
        }
    }

    /// The first place `token`, which begins with a backslash, stands as a command: its backslash
    /// is not the second half of a `\\\\` before it. In `x\\\\input{a}` the word "input" follows a
    /// line break and no command is there; in `x\\\\\\input{a}` one is.
    static func command(_ token: String, in text: Substring) -> Range<Substring.Index>? {
        var search = text
        while let range = search.range(of: token) {
            var before = 0
            var index = range.lowerBound
            while index > text.startIndex {
                let previous = text.index(before: index)
                if text[previous] != "\\" { break }
                before += 1
                index = previous
            }
            if before % 2 == 0 { return range }
            search = search[search.index(after: range.lowerBound)...]
        }
        return nil
    }

    private static func read(_ text: String, into found: inout Found) {
        if hasUnsupportedImport(text) { found.unsupportedImport = true }
        found.targets += inputTargets(text)
    }

    /// Where a `%` comment starts, if it does. `\%` is a percent sign; `\\%` is a line break
    /// followed by a comment.
    private static func commentStart(_ text: Substring) -> Substring.Index? {
        var run = 0
        for index in text.indices {
            let ch = text[index]
            if ch == "%" && run % 2 == 0 { return index }
            run = ch == "\\" ? run + 1 : 0
        }
        return nil
    }

    static func hasUnsupportedImport(_ line: String) -> Bool {
        ["\\subimport", "\\subfile", "\\import"].contains { macro in
            var search = line[...]
            while let range = command(macro, in: search) {
                var after = search[range.upperBound...]
                if after.first == "*" { after = after.dropFirst() }  // \subimport*, \import*
                after = after.drop(while: { $0 == " " || $0 == "\t" })
                if after.first == "{" { return true }
                search = search[range.upperBound...]
            }
            return false
        }
    }

    /// The targets of every `\input{…}` and `\include{…}` on the line, in order.
    static func inputTargets(_ line: String) -> [String] {
        var found: [(String.Index, String)] = []
        for macro in ["\\input", "\\include"] {
            var search = line[...]
            while let range = command(macro, in: search) {
                var rest = search[range.upperBound...]
                search = rest
                // `\include` must not match `\includegraphics`, nor `\input` match `\inputencoding`.
                if let next = rest.first, next.isLetter { continue }
                rest = rest.drop(while: { $0 == " " || $0 == "\t" })
                guard rest.first == "{", let close = rest.firstIndex(of: "}") else { continue }
                let target = rest[rest.index(after: rest.startIndex)..<close]
                    .trimmingCharacters(in: .whitespaces)
                found.append((range.lowerBound, target))  // an empty name is a missing file, not no include
            }
        }
        return found.sorted { $0.0 < $1.0 }.map(\.1)
    }
}
