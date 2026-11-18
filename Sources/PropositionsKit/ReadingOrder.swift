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
/// The input tree is read as `resolve_input_tree` of the Python tools reads it
/// (plugins/propositions/scripts/_lib/latex_env_parser.py), with one difference: a verbatim-like
/// environment that begins inside a `%` comment, or begins and ends on one line, does not hide
/// the lines after it (the Python function still has that fault, issue 94). Change the two together.
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
        let main = mainFile.resolvingSymlinksInPath().standardizedFileURL
        let root = main.deletingLastPathComponent()
        var prefixes: [String: [Int]] = [:]
        var files: [String] = [main.lastPathComponent]
        var skipped: [String] = []
        var seen: Set<String> = [main.path]

        func visit(_ url: URL, name: String, prefix: [Int], stack: [URL]) throws {
            if stack.count > ReadingOrder.maxDepth {
                throw InputTreeError.tooDeep(file: name, limit: ReadingOrder.maxDepth)
            }
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                throw InputTreeError.unreadable(file: name)
            }
            var inVerbatim = false
            for (index, raw) in LatexLine.splitLines(text).enumerated() {
                let lineNumber = index + 1
                if inVerbatim {
                    if LatexLine.endsVerbatim(raw) { inVerbatim = false }
                    continue
                }
                let line = LatexLine.stripComment(raw)
                if LatexLine.beginsVerbatim(line) {
                    // An environment that also ends on this line hides nothing after it.
                    inVerbatim = !LatexLine.endsVerbatim(line)
                    continue
                }
                if LatexLine.hasUnsupportedImport(line) {
                    skipped.append("\(name):\(lineNumber)")
                    continue
                }
                for (offset, target) in LatexLine.inputTargets(line).enumerated() {
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
    /// A location names the main file when it writes no file or writes the main file's own
    /// name. The name `main.tex` in a manuscript whose main file has another name means a
    /// sub-file of that name when the tree holds one, and the main file otherwise (ledgers
    /// written before schema v1.6 prefix every location with `main.tex`).
    public func position(file: String?, line: Int) -> [Int]? {
        guard let file else { return [line] }
        let key = ReadingOrder.normalise(file)
        if let prefix = prefixes[key] { return prefix + [line] }
        if key == mainName || key == "main.tex" { return [line] }
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
    static let verbatimEnvironments = ["verbatim", "Verbatim", "lstlisting", "comment", "filecontents"]

    /// The characters that end a line for Python's `str.splitlines`, which the tools that write
    /// `location` use: line numbers have to be counted the same way here.
    private static let lineEnds: Set<Unicode.Scalar> = [
        "\n", "\r", "\u{0B}", "\u{0C}", "\u{1C}", "\u{1D}", "\u{1E}", "\u{85}", "\u{2028}", "\u{2029}",
    ]

    /// The lines of a text, split where `str.splitlines` splits (`\r\n` is one line end, and a
    /// text that ends with a line end has no empty last line).
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
            if lineEnds.contains(scalar) {
                lines.append(String(current))
                current = String.UnicodeScalarView()
            } else {
                current.append(scalar)
            }
        }
        if !current.isEmpty { lines.append(String(current)) }
        return lines
    }

    /// Drops everything from an unescaped `%` on. `\%` is a percent sign; `\\%` is a line
    /// break followed by a comment.
    static func stripComment(_ line: String) -> String {
        var run = 0
        var out = ""
        for ch in line {
            if ch == "%" && run % 2 == 0 { return out }
            run = ch == "\\" ? run + 1 : 0
            out.append(ch)
        }
        return out
    }

    static func beginsVerbatim(_ line: String) -> Bool { marks(line, "\\begin{") }
    static func endsVerbatim(_ line: String) -> Bool { marks(line, "\\end{") }

    private static func marks(_ line: String, _ opener: String) -> Bool {
        verbatimEnvironments.contains { line.contains("\(opener)\($0)}") || line.contains("\(opener)\($0)*}") }
    }

    static func hasUnsupportedImport(_ line: String) -> Bool {
        ["\\subimport", "\\subfile", "\\import"].contains { macro in
            var search = line[...]
            while let range = search.range(of: macro) {
                let after = search[range.upperBound...].drop(while: { $0 == " " || $0 == "\t" })
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
            while let range = search.range(of: macro) {
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
