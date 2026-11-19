import Foundation

/// A proposition's `location`, as `docs/SCHEMA.md` writes it from schema v1.6 on:
/// `[<relpath>.tex:]L<a>[-L<b>]`. The path is relative to the directory of the main file.
public struct Location: Equatable, Sendable {
    /// The file as the location writes it, or `nil` when it writes none (the main file).
    /// Which file a written name means is decided by `ReadingOrder`, which knows the manuscript.
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
    ///
    /// This reads what `parse_location_v16` of the Python tools reads
    /// (plugins/propositions/scripts/_lib/latex_env_parser.py), and ParityTests compare the two:
    /// the same white space is trimmed, a digit is any decimal digit, and a file is any run of
    /// characters without `:`, `{`, `}` or white space that ends in `.tex`. One difference
    /// remains: a line number too large for a 64-bit integer is refused here.
    public static func parse(_ raw: String) -> Location? {
        var scalars = Array(raw.unicodeScalars)
        while let first = scalars.first, isPythonSpace(first) { scalars.removeFirst() }
        while let last = scalars.last, isPythonSpace(last) { scalars.removeLast() }
        var file: String?
        if let colon = scalars.firstIndex(of: ":") {
            let name = scalars[..<colon]
            guard name.count >= 5, String(String.UnicodeScalarView(name)).hasSuffix(".tex"),
                  !name.contains(where: { $0 == "{" || $0 == "}" || isPythonSpace($0) })
            else { return nil }
            file = String(String.UnicodeScalarView(name))
            scalars = Array(scalars[(colon + 1)...])
        }
        let parts = scalars.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 1 || parts.count == 2, let start = lineNumber(parts[0]) else { return nil }
        var end = start
        if parts.count == 2 {
            guard let last = lineNumber(parts[1]) else { return nil }
            end = last
        }
        guard start >= 1, end >= start else { return nil }
        return Location(file: file, start: start, end: end)
    }

    private static func lineNumber(_ part: ArraySlice<Unicode.Scalar>) -> Int? {
        guard part.first == "L", part.count >= 2 else { return nil }
        var value = 0
        for scalar in part.dropFirst() {
            guard scalar.properties.numericType == .decimal, let digit = scalar.properties.numericValue else { return nil }
            let (times, over1) = value.multipliedReportingOverflow(by: 10)
            let (sum, over2) = times.addingReportingOverflow(Int(digit))
            if over1 || over2 { return nil }
            value = sum
        }
        return value
    }

    /// The characters Python's `str.strip()` and `\s` take for white space.
    private static func isPythonSpace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09...0x0D, 0x1C...0x20, 0x85, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000:
            return true
        default:
            return false
        }
    }
}
