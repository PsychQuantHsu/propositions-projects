import Foundation

/// Rules R2 and R2-bis: a label of another document leaked into a citation, and the keys the
/// manuscript cites against the entries of its bibliography.
///
/// The Swift successor of `audit-citations.py`. It reads every file of the input tree and the
/// bibliography files the manuscript declares (`\bibliography`, `\addbibresource` and the like);
/// only when it declares none does it read `refs.bib` in the manuscript root, as the Python tool did.
enum AuditCitations {
    struct Entry {
        let key: String
        let file: String
        let line: Int
    }

    struct Bibliography {
        /// Each file read, as a report names it.
        var files: [String] = []
        /// Every entry, in the order of the files and of the entries in them.
        var entries: [Entry] = []
        var keys: Set<[UInt32]> = []
    }

    /// A label: a word with at least one underscore, escaped or not.
    static let label = try! NSRegularExpression(pattern: #"\A[a-zA-Z][a-zA-Z0-9]*(?:\\?_[a-zA-Z0-9]+)+\z"#)
    static let directives: Set<String> = ["string", "comment", "preamble"]
    /// Commands that have "cite" in their name and take no keys. `\citetext` holds text, and the
    /// citations inside it are read on their own.
    static let notCiting: Set<String> = ["citestyle", "citeindextrue", "citeindexfalse", "citeindextype", "citesetup", "citetext"]

    static func scalars(_ text: String) -> [UInt32] { text.unicodeScalars.map(\.value) }

    static func sortedKeys(_ keys: some Sequence<String>) -> [String] {
        keys.sorted { scalars($0).lexicographicallyPrecedes(scalars($1)) }
    }

    // MARK: the syntax of a citation command

    struct Syntax {
        let start: Int
        /// The index after the name, and after a `*`.
        let nameEnd: Int
        let optionals: [Range<Int>]
        /// Each `{…}` of keys, braces included.
        let keyGroups: [Range<Int>]
        let end: Int
    }

    /// Commands that define or configure citation commands, not cite: their names begin so.
    static let defining = ["declare", "def", "new", "renew", "provide", "set"]

    static func isCitation(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.contains("cite") && !notCiting.contains(name) && !defining.contains { lower.hasPrefix($0) }
    }

    /// Reads a citation command: up to two optional arguments before its keys; a command whose
    /// name ends in `s` (`\cites`, `\parencites` …) may have up to two `(…)` notes and then several
    /// groups. `nil` when no group of keys follows.
    static func syntax(_ chars: [Character], start: Int, name: String, end: Int) -> Syntax? {
        var at = end
        let starred = LatexText.skipSpace(chars, from: end)
        if starred < chars.count, chars[starred] == "*" { at = starred + 1 }
        let nameEnd = at
        let multiple = name.hasSuffix("s")
        // `\volcite[pre]{volume}[page]{key}` and its kin: the first braced argument is a volume.
        let volume = name.lowercased().contains("volcite")
        var optionals: [Range<Int>] = []
        var groups: [Range<Int>] = []
        if multiple {
            for _ in 0..<2 {
                let next = LatexText.skipSpace(chars, from: at)
                guard next < chars.count, chars[next] == "(", let group = LatexText.group(chars, at: next) else { break }
                optionals.append(group.range)
                at = group.end
            }
        }
        while true {
            var next = LatexText.skipSpace(chars, from: at)
            var count = 0
            var round: [Range<Int>] = []
            if volume {
                if next < chars.count, chars[next] == "[", let group = LatexText.group(chars, at: next) {
                    round.append(group.range)
                    at = group.end
                    next = LatexText.skipSpace(chars, from: at)
                }
                guard next < chars.count, chars[next] == "{", let number = LatexText.group(chars, at: next) else { break }
                round.append(number.range)
                at = number.end
                next = LatexText.skipSpace(chars, from: at)
                count = 1
            }
            while count < 2, next < chars.count, chars[next] == "[", let group = LatexText.group(chars, at: next) {
                round.append(group.range)
                count += 1
                at = group.end
                next = LatexText.skipSpace(chars, from: at)
            }
            guard next < chars.count, chars[next] == "{", let group = LatexText.group(chars, at: next) else {
                if !groups.isEmpty { at = round.first.map { _ in at } ?? at }
                break
            }
            optionals += round
            groups.append(next..<group.end)
            at = group.end
            if !multiple { break }
            let after = LatexText.skipSpace(chars, from: at)
            guard after < chars.count, chars[after] == "[" || chars[after] == "{" else { break }
        }
        guard let last = groups.last else { return nil }
        return Syntax(start: start, nameEnd: nameEnd, optionals: optionals, keyGroups: groups, end: last.upperBound)
    }

    /// Whether the text is `\texttt{<label>}`, with white space allowed around and inside.
    static func holdsLabel(_ chars: [Character], _ range: Range<Int>, only: Bool) -> Bool {
        let part = Array(chars[range])
        for command in LatexText.commands(part) where command.name == "texttt" {
            let at = LatexText.skipSpace(part, from: command.end)
            guard at < part.count, part[at] == "{", let group = LatexText.group(part, at: at) else { continue }
            // A brace that only groups does not change the printed label.
            let word = String(part[group.range].filter { $0 != "{" && $0 != "}" }).trimmingCharacters(in: .whitespacesAndNewlines)
            guard label.firstMatch(in: word, range: NSRange(word.startIndex..., in: word)) != nil else { continue }
            if !only { return true }
            let before = String(part[..<command.start]).trimmingCharacters(in: .whitespacesAndNewlines)
            let after = String(part[group.end...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return before.isEmpty && after.isEmpty
        }
        return false
    }

    // MARK: the bibliography

    struct Declared {
        var names: [(name: String, place: String)] = []
        var remote = 0
        var notes: [String] = []
    }

    /// The files the manuscript declares, each with the place it is declared.
    static func declared(_ manuscript: Audit.Manuscript) -> Declared {
        var declared = Declared()
        for source in manuscript.sources {
            let chars = source.code.chars
            for command in LatexText.commands(chars) {
                let place = "\(source.shown):\(source.line(of: source.code.offsets[command.start]))"
                var at = LatexText.skipSpace(chars, from: command.end)
                switch command.name {
                case "bibliography":
                    guard at < chars.count, chars[at] == "{", let group = LatexText.group(chars, at: at) else { continue }
                    for part in String(chars[group.range]).split(separator: ",") {
                        let name = LedgerOrder.stripped(String(part))
                        if !name.isEmpty { declared.names.append((name.hasSuffix(".bib") ? name : name + ".bib", place)) }
                    }
                case "addbibresource", "bibresource", "addglobalbib", "addsectionbib":
                    var options = ""
                    if at < chars.count, chars[at] == "[", let group = LatexText.group(chars, at: at) {
                        options = String(chars[group.range])
                        at = LatexText.skipSpace(chars, from: group.end)
                    }
                    guard at < chars.count, chars[at] == "{", let group = LatexText.group(chars, at: at) else { continue }
                    let name = LedgerOrder.stripped(String(chars[group.range]))
                    let flat = String(options.filter { !$0.isWhitespace && $0 != "{" && $0 != "}" })
                    if flat.split(separator: ",").contains("location=remote") {
                        declared.remote += 1
                        declared.notes.append("[warn] remote bibliography \(CiteOrder.visible(name)) at \(CiteOrder.visible(place)) is not read")
                    } else if !name.isEmpty {
                        declared.names.append((name, place))
                    }
                default:
                    continue
                }
            }
        }
        return declared
    }

    /// The end of a BibTeX record that opens at `start` with `{` or `(`: braces nest, and a `"` at
    /// the record's own level opens a value in which only braces count.
    static func record(_ text: [Character], at start: Int) -> (range: Range<Int>, end: Int)? {
        let close: Character = text[start] == "{" ? "}" : ")"
        var braces = 0
        var quoted = false
        var index = start + 1
        while index < text.count {
            let ch = text[index]
            if ch == "{" { braces += 1 }
            else if ch == "}" {
                if braces == 0, close == "}" { return ((start + 1)..<index, index + 1) }
                braces = max(0, braces - 1)
            } else if ch == "\"", braces == 0 { quoted.toggle() }
            else if ch == ")", close == ")", braces == 0, !quoted { return ((start + 1)..<index, index + 1) }
            index += 1
        }
        return nil
    }

    /// The entries of a BibTeX file: each `@type{key, …}` or `@type(key, …)` read as a whole, so
    /// that an entry written inside `@comment{…}` or a field is not one. A key is followed by a
    /// comma or by the end of the record. Text between records is ignored. The offset is the `@`'s.
    static func entries(in text: [Character]) -> [(key: String, offset: Int)] {
        var found: [(String, Int)] = []
        var index = 0
        while index < text.count {
            guard text[index] == "@" else { index += 1; continue }
            var at = LatexText.skipSpace(text, from: index + 1)
            let typeStart = at
            while at < text.count, text[at].isLetter || text[at].isNumber || "_-:.".contains(text[at]) { at += 1 }
            let type = String(text[typeStart..<at]).lowercased()
            let open = LatexText.skipSpace(text, from: at)
            guard !type.isEmpty, open < text.count, text[open] == "{" || text[open] == "(",
                  let body = record(text, at: open)
            else { index += 1; continue }
            if !directives.contains(type) {
                let keyStart = LatexText.skipSpace(text, from: open + 1)
                var keyEnd = keyStart
                while keyEnd < body.range.upperBound, text[keyEnd] != ",", !text[keyEnd].isWhitespace { keyEnd += 1 }
                let after = LatexText.skipSpace(text, from: keyEnd)
                if keyEnd > keyStart, after >= body.range.upperBound || text[after] == "," {
                    found.append((String(text[keyStart..<keyEnd]), index))
                }
            }
            index = body.end
        }
        return found
    }

    /// The bibliography the declarations name. Their warnings are the caller's to print, before
    /// a file that cannot be read stops the audit.
    static func bibliography(_ manuscript: Audit.Manuscript, declared: Declared) throws -> Bibliography {
        var bibliography = Bibliography()
        var urls: [(url: URL, place: String?)] = declared.names.map { item in
            let url = item.name.hasPrefix("/") ? URL(fileURLWithPath: item.name)
                : manuscript.mainDirectory.appendingPathComponent(item.name)
            return (url.standardizedFileURL, item.place)
        }
        if declared.names.isEmpty && declared.remote == 0 {
            let fallback = manuscript.root.appendingPathComponent("refs.bib")
            if FileManager.default.fileExists(atPath: fallback.path) { urls = [(fallback.standardizedFileURL, nil)] }
        }
        var seen = Set<String>()
        for item in urls where seen.insert(item.url.resolvingSymlinksInPath().path).inserted {
            let shown = Audit.shown(item.url, root: manuscript.root, rootShown: manuscript.rootShown)
            guard let content = Audit.text(of: item.url) else {
                let declaredAt = item.place.map { ", declared at \(CiteOrder.visible($0))" } ?? ""
                throw Audit.Failure(message: "cannot read the bibliography file \(CiteOrder.visible(shown))\(declaredAt)")
            }
            bibliography.files.append(shown)
            let text = Array(LatexLine.splitLines(content).joined(separator: "\n"))
            var starts = [0]
            for (offset, ch) in text.enumerated() where ch == "\n" { starts.append(offset + 1) }
            for entry in entries(in: text) {
                let line = starts.lastIndex { $0 <= entry.offset }.map { $0 + 1 } ?? 1
                bibliography.entries.append(Entry(key: entry.key, file: shown, line: line))
                bibliography.keys.insert(scalars(entry.key))
            }
        }
        return bibliography
    }

    // MARK: the citations

    struct Citation {
        let name: String
        let keys: [String]
        let source: Int
        let offset: Int
        let position: [Int]

        var place: (position: [Int], offset: Int) { (position, offset) }
    }

    static func findings(_ manuscript: Audit.Manuscript, bibliography: Bibliography) -> [Audit.Finding] {
        var leaks: [(place: (position: [Int], offset: Int), finding: Audit.Finding)] = []
        var citations: [Citation] = []
        for (sourceIndex, source) in manuscript.sources.enumerated() {
            let chars = source.code.chars
            for command in LatexText.commands(chars) where isCitation(command.name) {
                guard let syntax = syntax(chars, start: command.start, name: command.name, end: command.end) else { continue }
                let offset = source.code.offsets[command.start]
                let line = source.line(of: offset)
                // A key with `#` is a macro's parameter, in a definition, not a key.
                let keys = syntax.keyGroups.flatMap { group in
                    String(chars[(group.lowerBound + 1)..<(group.upperBound - 1)]).split(separator: ",")
                        .map { LedgerOrder.stripped(String($0)) }.filter { !$0.isEmpty && !$0.contains("#") }
                }
                let position = manuscript.position(source: sourceIndex, offset: offset)
                citations.append(Citation(name: command.name, keys: keys, source: sourceIndex, offset: offset, position: position))
                var leaked = syntax.optionals.contains { holdsLabel(chars, $0, only: false) }
                var end = syntax.end
                let next = LatexText.skipSpace(chars, from: syntax.end)
                if next < chars.count, chars[next] == "(", let group = LatexText.group(chars, at: next),
                   holdsLabel(chars, group.range, only: true) {
                    leaked = true
                    end = group.end
                }
                if leaked {
                    leaks.append(((position, offset), Audit.Finding(
                        rule: "R2", severity: "likely", file: source.shown, line: line,
                        match: String(chars[command.start..<end]), context: Audit.context(source.lines, line: line),
                        proposedFix: "替換 snake_case label 為 content-based 描述,e.g. `Theorem on $\\eta = f(s)$ case`")))
                }
            }
        }
        // The first citation of a key is the first in reading order, whichever file it is in.
        var first: [[UInt32]: (key: String, citation: Citation)] = [:]
        var everything = false
        for citation in citations.sorted(by: { Audit.Manuscript.precedes($0.place, $1.place) }) {
            for key in citation.keys {
                if key == "*" && citation.name == "nocite" { everything = true; continue }
                if first[scalars(key)] == nil { first[scalars(key)] = (key, citation) }
            }
        }
        let bibNames = bibliography.files.isEmpty ? "the bibliography (none was read)" : bibliography.files.joined(separator: ", ")
        var findings = leaks.sorted { Audit.Manuscript.precedes($0.place, $1.place) }.map(\.finding)
        for key in sortedKeys(first.values.map(\.key)) where !bibliography.keys.contains(scalars(key)) {
            let citation = first[scalars(key)]!.citation
            let source = manuscript.sources[citation.source]
            let shown = CiteOrder.visible(key)
            findings.append(Audit.Finding(
                rule: "R2-bis", severity: "definite", file: source.shown, line: source.line(of: citation.offset), match: key,
                context: "\\cite*{\(shown)} but \(shown) not in \(bibNames)",
                proposedFix: "加 \(shown) 條目到 bibliography,或修正 cite key typo"))
        }
        if !everything {
            let orphans = bibliography.entries.filter { first[scalars($0.key)] == nil }
            for entry in orphans.sorted(by: { scalars($0.key).lexicographicallyPrecedes(scalars($1.key)) }) {
                let shown = CiteOrder.visible(entry.key)
                findings.append(Audit.Finding(
                    rule: "R2-bis", severity: "FYI", file: entry.file, line: entry.line, match: entry.key,
                    context: "@type{\(shown), ...} in \(entry.file) but never cited",
                    proposedFix: "考慮刪除 \(shown) 條目,或確認是否預期但漏 cite"))
            }
        }
        return findings
    }
}
