import Foundation

/// Rule R1: a path to a working file (code, notes, sources) written into the manuscript.
///
/// The Swift successor of `audit-symbols.py`. It reads every file of the input tree, and finds a
/// path in `\texttt{}`, `\url{}`, `\path{}`, `\nolinkurl{}`, the address of `\href{}`, `\verb`,
/// `\lstinline`, the text of verbatim-like environments, and running text. The arguments of
/// commands that name files or labels for LaTeX itself (`\input`, `\includegraphics`, `\label`,
/// the citation commands and the others in `quiet`) are not running text.
enum AuditSymbols {
    static let extensions = ["py", "md", "tex", "sh", "rs", "swift", "R", "jl"]

    /// A path with one of the extensions. Its body has no white space, except one parenthesised
    /// group after a space, as in `note (Hsu 2024-02).tex`.
    static let path = try! NSRegularExpression(
        pattern: #"[\w/.\-\\]+(?:\s+\([^)]*\))?\.(?:"# + extensions.joined(separator: "|") + #")\b"#)

    static let definite = [
        #"analysis/[\w\-/.]+\.py"#, #"manuscript/docs/[\w\-_/. ]+\.md"#, #"note\s*\([^)]+\)\.tex"#, #"manuscript/docs/[\w\-_/. ]+\.tex"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    static let whitelist: Set<String> = ["refs.bib", "bibliography.bib", "references.bib"]

    /// Commands whose arguments are a URL or a path shown as it is written.
    static let shownVerbatim: Set<String> = ["texttt", "url", "path", "nolinkurl"]

    /// Commands whose arguments name a file, a package or a label for LaTeX, or cite: not text.
    static let quiet: Set<String> = [
        "input", "include", "includeonly", "includegraphics", "includepdf", "includestandalone", "InputIfFileExists",
        "IfFileExists", "bibliography", "bibliographystyle", "addbibresource", "bibresource", "addglobalbib",
        "addsectionbib", "label", "ref", "eqref", "cref", "Cref", "crefrange", "Crefrange", "autoref", "pageref",
        "nameref", "vref", "Vref", "hyperref", "usepackage", "RequirePackage", "documentclass", "LoadClass",
        "graphicspath", "lstinputlisting", "verbatiminput", "inputminted", "import", "subimport", "subfile",
        "externaldocument", "bibitem", "newlabel", "hypertarget", "hyperlink",
    ]

    static func severity(_ found: String) -> String {
        let range = NSRange(found.startIndex..., in: found)
        if definite.contains(where: { $0.firstMatch(in: found, range: range) != nil }) { return "definite" }
        let ext = found.contains(".") ? String(found[found.index(after: found.lastIndex(of: ".")!)...]) : ""
        return ext == "tex" || ext == "sh" ? "likely" : "suspicious"
    }

    static func fix(_ found: String, _ severity: String) -> String {
        if severity == "definite" {
            if found.hasSuffix(".py") { return "刪除句 — formal manuscript 不引用 working scripts" }
            if found.hasSuffix(".md") { return "改成 content-based description,或刪 parenthetical" }
            if found.lowercased().contains("note") { return "刪 parenthetical (working note 引用),保留 sub-section 標籤" }
        }
        if severity == "likely" { return "review:確認非合法 reference,改 content-based 或加入 white-list" }
        return "review:可能 false positive,確認 context"
    }

    /// The pieces of one line to look for a path in, each with the column it starts at.
    static func segments(_ line: String) -> [(text: String, column: Int, escaped: Bool)] {
        let chars = Array(line)
        var plain = chars
        var pieces: [(String, Int, Bool)] = []
        var consumed = 0
        func blank(_ range: Range<Int>) { for i in range where i < plain.count { plain[i] = " " } }
        for command in LatexText.commands(chars) where command.start >= consumed {
            var at = command.end
            if shownVerbatim.contains(command.name) || command.name == "href" {
                at = LatexText.skipSpace(chars, from: at)
                guard let group = LatexText.group(chars, at: at), chars[at] == "{" else { continue }
                pieces.append((group.content, at + 1, command.name == "texttt"))
                blank(command.start..<group.end)
                consumed = group.end
            } else if command.name == "verb" || command.name == "lstinline" {
                if command.name == "verb", at < chars.count, chars[at] == "*" { at += 1 }
                if command.name == "lstinline", at < chars.count, chars[at] == "[", let options = LatexText.group(chars, at: at) {
                    at = options.end
                }
                guard at < chars.count else { continue }
                if chars[at] == "{", let group = LatexText.group(chars, at: at) {
                    pieces.append((group.content, at + 1, false))
                    blank(command.start..<group.end)
                    consumed = group.end
                } else if !chars[at].isLetter, !chars[at].isWhitespace,
                          let close = chars[(at + 1)...].firstIndex(of: chars[at]) {
                    pieces.append((String(chars[(at + 1)..<close]), at + 1, false))
                    blank(command.start..<(close + 1))
                    consumed = close + 1
                }
            } else if quiet.contains(command.name) || command.name.lowercased().contains("cite") {
                if at < chars.count, chars[at] == "*" { at += 1 }
                var end = at
                while true {
                    let next = LatexText.skipSpace(chars, from: end)
                    guard next < chars.count, "{[(".contains(chars[next]), let group = LatexText.group(chars, at: next) else { break }
                    end = group.end
                }
                blank(command.start..<end)
                consumed = end
            }
        }
        // Running text, with what was read above blanked so it is not read twice.
        pieces.append((String(plain), 0, true))
        return pieces
    }

    static func unescape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\_", with: "_").replacingOccurrences(of: "\\ ", with: " ")
    }

    static func paths(in text: String) -> [String] {
        path.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap {
            Range($0.range, in: text).map { String(text[$0]) }
        }
    }

    static func findings(_ manuscript: Audit.Manuscript, bibliographyNames: Set<String>) -> [Audit.Finding] {
        var findings: [Audit.Finding] = []
        for source in manuscript.sources {
            for (index, code) in source.code.enumerated() {
                var found: [(column: Int, path: String)] = []
                for piece in segments(code) {
                    let text = piece.escaped ? unescape(piece.text) : piece.text
                    for (offset, match) in paths(in: text).enumerated() {
                        found.append((piece.column + offset, match))
                    }
                }
                for match in paths(in: source.verbatim[index]) { found.append((Int.max, match)) }
                for item in found.sorted(by: { $0.column < $1.column }) {
                    let name = item.path
                    if whitelist.contains(name) || bibliographyNames.contains(name) || name.hasSuffix(".bib") { continue }
                    let level = severity(name)
                    findings.append(Audit.Finding(
                        rule: "R1", severity: level, file: source.shown, line: index + 1, match: name,
                        context: Audit.context(source.lines, line: index + 1), proposedFix: fix(name, level)))
                }
            }
        }
        return findings
    }
}
