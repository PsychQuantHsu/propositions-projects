import Foundation

/// Rule R1: a path to a working file (code, notes, sources) shown in the manuscript.
///
/// The Swift successor of `audit-symbols.py`. It reads every file of the input tree, and finds a
/// path in `\texttt{}`, `\url{}`, `\path{}`, `\nolinkurl{}`, the address of `\href{}`, `\verb`,
/// `\lstinline`, the body of verbatim-like environments that print it, and running text. The
/// arguments of commands that name a file, a package or a label for LaTeX (`quiet`), and the keys
/// of citations, are not shown text.
enum AuditSymbols {
    static let extensions = ["py", "md", "tex", "sh", "rs", "swift", "R", "jl"]

    /// A path with one of the extensions. Its body has no white space but one parenthesised group
    /// after a space, as in `note (Hsu 2024-02).tex`, and the extension is its end: `report.py.pdf`
    /// and `tools.py/README` are not paths that end in `.py`.
    static let path = try! NSRegularExpression(
        pattern: #"[\w/.\-\\+~@]+(?:\s+\([^)\n]*\))?\.(?:"# + extensions.joined(separator: "|") + #")(?![\w/\-+]|\.\w)"#)

    static let definite = [
        #"(?:^|/)analysis/[\w\-/.+]+\.py$"#, #"(?:^|/)manuscript/docs/[\w\-_/. +]+\.(?:md|tex)$"#, #"(?:^|/)note\s*\([^)]+\)\.tex$"#,
    ].map { try! NSRegularExpression(pattern: $0) }

    static let whitelist: Set<String> = ["refs.bib", "bibliography.bib", "references.bib"]

    /// Commands whose argument is a URL or a path shown as it is written.
    static let shownAsWritten: Set<String> = ["texttt", "url", "path", "nolinkurl"]

    /// Commands whose arguments name a file, a package or a label for LaTeX: how many optional and
    /// how many braced arguments are not shown. Arguments after those are read as text, so that the
    /// text of `\hyperref[label]{text}` is.
    static let quiet: [String: (optional: Int, braced: Int)] = [
        "input": (0, 1), "include": (0, 1), "includeonly": (0, 1), "includegraphics": (1, 1), "includepdf": (1, 1),
        "includestandalone": (1, 1), "InputIfFileExists": (0, 1), "IfFileExists": (0, 1), "bibliography": (0, 1),
        "bibliographystyle": (0, 1), "addbibresource": (1, 1), "bibresource": (1, 1), "addglobalbib": (1, 1),
        "addsectionbib": (1, 1), "label": (1, 1), "ref": (0, 1), "eqref": (0, 1), "cref": (0, 1), "Cref": (0, 1),
        "crefrange": (0, 2), "Crefrange": (0, 2), "autoref": (0, 1), "pageref": (0, 1), "nameref": (0, 1),
        "vref": (0, 1), "Vref": (0, 1), "hyperref": (1, 0), "usepackage": (1, 1), "RequirePackage": (1, 1),
        "documentclass": (1, 1), "LoadClass": (1, 1), "graphicspath": (0, 1), "lstinputlisting": (1, 1),
        "verbatiminput": (0, 1), "inputminted": (1, 2), "import": (0, 2), "subimport": (0, 2), "subfile": (0, 1),
        "externaldocument": (1, 1), "bibitem": (1, 1), "newlabel": (0, 2), "hypertarget": (0, 1), "hyperlink": (0, 1),
    ]

    static func severity(_ found: String) -> String {
        let range = NSRange(found.startIndex..., in: found)
        if definite.contains(where: { $0.firstMatch(in: found, range: range) != nil }) { return "definite" }
        let ext = found.lastIndex(of: ".").map { String(found[found.index(after: $0)...]) } ?? ""
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

    /// `\_` read as `_` and `\ ` as a space, each character keeping its offset.
    static func unescaped(_ piece: Audit.Piece) -> Audit.Piece {
        var out = Audit.Piece()
        var index = 0
        while index < piece.chars.count {
            if piece.chars[index] == "\\", index + 1 < piece.chars.count, piece.chars[index + 1] == "_" || piece.chars[index + 1] == " " {
                out.chars.append(piece.chars[index + 1])
                out.offsets.append(piece.offsets[index])
                index += 2
                continue
            }
            out.chars.append(piece.chars[index])
            out.offsets.append(piece.offsets[index])
            index += 1
        }
        return out
    }

    /// Each path in a piece, with the offset in the file where it starts.
    static func paths(in piece: Audit.Piece) -> [(offset: Int, path: String)] {
        let text = String(piece.chars)
        return path.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let index = text.distance(from: text.startIndex, to: range.lowerBound)
            return (piece.offsets[index], String(text[range]))
        }
    }

    /// The pieces of a file's source to look for a path in.
    static func pieces(_ code: Audit.Piece) -> [Audit.Piece] {
        let chars = code.chars
        var plain = code
        var pieces: [Audit.Piece] = []
        var consumed = 0
        func blank(_ range: Range<Int>) { for i in range where i < plain.chars.count { plain.chars[i] = " " } }
        func slice(_ range: Range<Int>) -> Audit.Piece {
            Audit.Piece(chars: Array(chars[range]), offsets: Array(code.offsets[range]))
        }
        for command in LatexText.commands(chars) where command.start >= consumed {
            let at = LatexText.skipSpace(chars, from: command.end)
            if shownAsWritten.contains(command.name) || command.name == "href" {
                guard at < chars.count, chars[at] == "{", let group = LatexText.group(chars, at: at) else { continue }
                pieces.append(command.name == "texttt" ? unescaped(slice(group.range)) : slice(group.range))
                blank(command.start..<group.end)
                consumed = group.end
            } else if let arity = quiet[command.name] {
                var end = command.end
                if end < chars.count, chars[end] == "*" { end += 1 }
                for _ in 0..<arity.optional {
                    let next = LatexText.skipSpace(chars, from: end)
                    guard next < chars.count, chars[next] == "[", let group = LatexText.group(chars, at: next) else { break }
                    end = group.end
                }
                for _ in 0..<arity.braced {
                    let next = LatexText.skipSpace(chars, from: end)
                    guard next < chars.count, chars[next] == "{", let group = LatexText.group(chars, at: next) else { break }
                    end = group.end
                }
                blank(command.start..<end)
                consumed = end
            } else if AuditCitations.isCitation(command.name),
                      let syntax = AuditCitations.syntax(chars, start: command.start, name: command.name, end: command.end) {
                // The keys are not shown; the notes in `[…]` and `(…)` are.
                blank(command.start..<syntax.nameEnd)
                syntax.keyGroups.forEach(blank)
            }
        }
        pieces.append(unescaped(plain))
        return pieces
    }

    static func findings(_ manuscript: Audit.Manuscript, bibliographyNames: Set<String>) -> [Audit.Finding] {
        var findings: [Audit.Finding] = []
        for source in manuscript.sources {
            var found = pieces(source.code).flatMap(paths)
            found += source.displayed.flatMap(paths)
            for item in found.sorted(by: { $0.offset < $1.offset }) {
                let name = item.path
                if whitelist.contains(name) || bibliographyNames.contains(name) || name.hasSuffix(".bib") { continue }
                let level = severity(name)
                let line = source.line(of: item.offset)
                findings.append(Audit.Finding(
                    rule: "R1", severity: level, file: source.shown, line: line, match: name,
                    context: Audit.context(source.lines, line: line), proposedFix: fix(name, level)))
            }
        }
        return findings
    }
}
