import Foundation

/// A proposition's `location`, as `docs/SCHEMA.md` writes it from schema v1.6 on:
/// `[<relpath>.tex:]L<a>[-L<b>]`. The path is relative to the directory of the main file.
public struct Location: Equatable, Sendable {
    /// `nil` for the main file (no prefix, or the prefix `main.tex`).
    public let file: String?
    public let start: Int
    public let end: Int

    public init(file: String?, start: Int, end: Int) {
        self.file = file
        self.start = start
        self.end = end
    }

    /// Parses a location, or returns `nil` when it is not written as the schema writes it.
    /// Nothing is guessed: `main.tex:12`, `L0` and `L9-L3` are all refused.
    public static func parse(_ raw: String) -> Location? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        var file: String?
        var rest = Substring(text)
        if let colon = text.range(of: ".tex:") {
            let name = String(text[text.startIndex..<colon.lowerBound]) + ".tex"
            guard !name.isEmpty, name != ".tex",
                  !name.contains(where: { $0 == ":" || $0 == "{" || $0 == "}" || $0.isWhitespace })
            else { return nil }
            file = name
            rest = text[colon.upperBound...]
        }
        let parts = rest.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2, let start = lineNumber(parts[0]) else { return nil }
        var end = start
        if parts.count == 2 {
            guard let last = lineNumber(parts[1]) else { return nil }
            end = last
        }
        guard start >= 1, end >= start else { return nil }
        return Location(file: file == "main.tex" ? nil : file, start: start, end: end)
    }

    private static func lineNumber(_ part: Substring) -> Int? {
        guard part.first == "L" else { return nil }
        let digits = part.dropFirst()
        guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }) else { return nil }
        return Int(digits)
    }
}
