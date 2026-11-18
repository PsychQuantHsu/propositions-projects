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
/// A position is a list of line numbers: line L of the main file is `[L]`; line k of a file
/// that line L of the main file includes is `[L, k]`, and so on. Positions compare
/// lexicographically, so the text of an included file comes after the line that includes it
/// and before the next line of the including file.
public struct ReadingOrder: Sendable {
    public static let maxDepth = 3

    /// The prefix of every position in a file, keyed by its path relative to the directory of
    /// the main file (`nil` key is not used: the main file is the empty prefix).
    private let prefixes: [String: [Int]]
    /// Files in the order they are first included, the main file first.
    public let files: [String]
    /// Lines that hold an import macro this tool does not follow (`\subimport`, `\subfile`, `\import`).
    public let skippedImports: [String]

    public init(mainFile: URL) throws {
        let main = mainFile.standardizedFileURL
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
            // `components(separatedBy:)` keeps empty lines, so indices are the file's line numbers.
            let lines = text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
            for (index, raw) in lines.enumerated() {
                let lineNumber = index + 1
                if inVerbatim {
                    if LatexLine.endsVerbatim(raw) { inVerbatim = false }
                    continue
                }
                if LatexLine.beginsVerbatim(raw) {
                    inVerbatim = true
                    continue
                }
                let line = LatexLine.stripComment(raw)
                if LatexLine.hasUnsupportedImport(line) {
                    skipped.append("\(name):\(lineNumber)")
                    continue
                }
                for target in LatexLine.inputTargets(line) {
                    if target.hasPrefix("/") || target.hasPrefix("\\\\") {
                        throw InputTreeError.absolute(target: target, in: name, line: lineNumber)
                    }
                    let relative = target.hasSuffix(".tex") ? target : target + ".tex"
                    let child = root.appendingPathComponent(relative).standardizedFileURL
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
                    let key = ReadingOrder.relativePath(of: child, under: root)
                    prefixes[key] = prefix + [lineNumber]
                    files.append(key)
                    try visit(child, name: key, prefix: prefix + [lineNumber], stack: chain)
                }
            }
        }

        try visit(main, name: main.lastPathComponent, prefix: [], stack: [])
        self.prefixes = prefixes
        self.files = files
        self.skippedImports = skipped
    }

    /// The position of a line, or `nil` when the file is not in the input tree.
    public func position(file: String?, line: Int) -> [Int]? {
        guard let file else { return [line] }
        let key = ReadingOrder.normalise(file)
        guard let prefix = prefixes[key] else { return nil }
        return prefix + [line]
    }

    /// Whether position `a` comes strictly before position `b`.
    public static func precedes(_ a: [Int], _ b: [Int]) -> Bool {
        for (x, y) in zip(a, b) where x != y { return x < y }
        return a.count < b.count
    }

    static func relativePath(of url: URL, under root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return url.path.hasPrefix(rootPath) ? String(url.path.dropFirst(rootPath.count)) : url.path
    }

    static func normalise(_ file: String) -> String {
        let parts = file.split(separator: "/").filter { $0 != "." }
        return parts.joined(separator: "/")
    }
}

/// The few facts about one line of LaTeX that reading the input tree needs.
enum LatexLine {
    static let verbatimEnvironments = ["verbatim", "Verbatim", "lstlisting", "comment", "filecontents"]

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
                if !target.isEmpty { found.append((range.lowerBound, target)) }
            }
        }
        return found.sorted { $0.0 < $1.0 }.map(\.1)
    }
}
