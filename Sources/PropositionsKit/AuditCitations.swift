import Foundation

/// Rules R2 and R2-bis: a label of another document leaked into a citation, and the keys the
/// manuscript cites against the entries of its bibliography.
///
/// The Swift successor of `audit-citations.py`. It reads every file of the input tree and the
/// bibliography files the manuscript declares (`\bibliography`, `\addbibresource` and the like);
/// only when it declares none does it read `refs.bib` in the manuscript root, as the Python tool did.
enum AuditCitations {
    struct Bibliography {
        /// Each file read, as a report names it.
        var files: [String] = []
        /// Each key, with the file and line of its entry.
        var entries: [String: (file: String, line: Int)] = [:]
    }

    /// A label written in `\texttt{}`: a word with at least one underscore, escaped or not.
    static let leakedLabel = try! NSRegularExpression(pattern: #"\\texttt\{[a-zA-Z][a-zA-Z0-9]*(?:\\?_[a-zA-Z0-9]+)+\}"#)
    static let leakedAfter = try! NSRegularExpression(
        pattern: #"\A\s*\(\s*\\texttt\{[a-zA-Z][a-zA-Z0-9]*(?:\\?_[a-zA-Z0-9]+)+\}\s*\)"#)
    /// An entry: `@type{key,` or `@type(key,`.
    static let entry = try! NSRegularExpression(pattern: #"@\s*([A-Za-z]+)\s*[{(]\s*([^,\s{}()]+)\s*[,})]"#)
    static let directives: Set<String> = ["string", "comment", "preamble"]
    /// Commands that have "cite" in their name and cite nothing.
    static let notCiting: Set<String> = ["citestyle", "citeindextrue", "citeindexfalse", "citeindextype", "citesetup"]

    static func scalars(_ text: String) -> [UInt32] { text.unicodeScalars.map(\.value) }

    static func sortedKeys(_ keys: some Sequence<String>) -> [String] {
        keys.sorted { scalars($0).lexicographicallyPrecedes(scalars($1)) }
    }

    // MARK: the bibliography

    /// The files the manuscript declares, each with the place it is declared.
    static func declared(_ manuscript: Audit.Manuscript) -> (names: [(name: String, place: String)], notes: [String]) {
        var names: [(String, String)] = []
        var notes: [String] = []
        for source in manuscript.sources {
            for (index, code) in source.code.enumerated() {
                let chars = Array(code)
                for command in LatexText.commands(chars) {
                    let place = "\(source.shown):\(index + 1)"
                    var at = LatexText.skipSpace(chars, from: command.end)
                    switch command.name {
                    case "bibliography":
                        guard let group = LatexText.group(chars, at: at), chars[at] == "{" else { continue }
                        for part in group.content.split(separator: ",") {
                            let name = LedgerOrder.stripped(String(part))
                            if !name.isEmpty { names.append((name.hasSuffix(".bib") ? name : name + ".bib", place)) }
                        }
                    case "addbibresource", "bibresource", "addglobalbib", "addsectionbib":
                        var options = ""
                        if at < chars.count, chars[at] == "[", let group = LatexText.group(chars, at: at) {
                            options = group.content
                            at = LatexText.skipSpace(chars, from: group.end)
                        }
                        guard let group = LatexText.group(chars, at: at), chars[at] == "{" else { continue }
                        let name = LedgerOrder.stripped(group.content)
                        if options.replacingOccurrences(of: " ", with: "").contains("location=remote") {
                            notes.append("[warn] remote bibliography \(CiteOrder.visible(name)) at \(CiteOrder.visible(place)) is not read")
                        } else if !name.isEmpty {
                            names.append((name, place))
                        }
                    default:
                        continue
                    }
                }
            }
        }
        return (names, notes)
    }

    static func bibliography(_ manuscript: Audit.Manuscript) throws -> (Bibliography, [String]) {
        var bibliography = Bibliography()
        let (names, notes) = declared(manuscript)
        var urls: [(url: URL, place: String?)] = names.map { item in
            let url = item.name.hasPrefix("/") ? URL(fileURLWithPath: item.name)
                : manuscript.mainDirectory.appendingPathComponent(item.name)
            return (url.standardizedFileURL, item.place)
        }
        if names.isEmpty {
            let fallback = manuscript.root.appendingPathComponent("refs.bib")
            if FileManager.default.fileExists(atPath: fallback.path) { urls = [(fallback.standardizedFileURL, nil)] }
        }
        var seen = Set<String>()
        for item in urls where seen.insert(item.url.path).inserted {
            let shown = Audit.shown(item.url, root: manuscript.root, rootShown: manuscript.rootShown)
            guard let text = Audit.text(of: item.url) else {
                let declaredAt = item.place.map { ", declared at \(CiteOrder.visible($0))" } ?? ""
                throw Audit.Failure(message: "cannot read the bibliography file \(CiteOrder.visible(shown))\(declaredAt)")
            }
            bibliography.files.append(shown)
            let lineStarts = starts(of: text)
            let range = NSRange(text.startIndex..., in: text)
            for match in entry.matches(in: text, range: range) {
                guard let type = Range(match.range(at: 1), in: text), let key = Range(match.range(at: 2), in: text),
                      !directives.contains(text[type].lowercased())
                else { continue }
                let line = lineNumber(of: text.distance(from: text.startIndex, to: key.lowerBound), lineStarts: lineStarts)
                let name = String(text[key])
                if bibliography.entries[name] == nil { bibliography.entries[name] = (shown, line) }
            }
        }
        return (bibliography, notes)
    }

    static func starts(of text: String) -> [Int] {
        var starts = [0]
        for (offset, ch) in text.enumerated() where ch == "\n" { starts.append(offset + 1) }
        return starts
    }

    static func lineNumber(of offset: Int, lineStarts: [Int]) -> Int {
        var low = 0, high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= offset { low = mid } else { high = mid - 1 }
        }
        return low + 1
    }

    // MARK: the citations

    struct Citation {
        let keys: [String]
        let file: Int
        let line: Int
    }

    /// Reads every citation command of the text. A command may have two optional arguments before
    /// its keys; a command whose name ends in `s` (`\cites`, `\parencites` …) may have several
    /// groups of them, and one or two `(…)` notes before the first.
    static func citations(in chars: [Character], file: Int, source: Audit.Source, lineStarts: [Int],
                          leaks: inout [Audit.Finding]) -> [Citation] {
        var found: [Citation] = []
        var consumed = 0
        for command in LatexText.commands(chars) where command.start >= consumed {
            let name = command.name
            guard name.lowercased().contains("cite"), !notCiting.contains(name) else { continue }
            let multiple = name.hasSuffix("s")
            var at = command.end
            if at < chars.count, chars[at] == "*" { at += 1 }
            var keys: [String] = []
            var leaked = false
            if multiple {
                for _ in 0..<2 {
                    let next = LatexText.skipSpace(chars, from: at)
                    guard next < chars.count, chars[next] == "(", let group = LatexText.group(chars, at: next) else { break }
                    at = group.end
                }
            }
            var groups = 0
            while true {
                var next = LatexText.skipSpace(chars, from: at)
                var optionals = 0
                while optionals < 2, next < chars.count, chars[next] == "[", let group = LatexText.group(chars, at: next) {
                    if leakedLabel.firstMatch(in: group.content, range: NSRange(group.content.startIndex..., in: group.content)) != nil {
                        leaked = true
                    }
                    optionals += 1
                    at = group.end
                    next = LatexText.skipSpace(chars, from: at)
                }
                guard next < chars.count, chars[next] == "{", let group = LatexText.group(chars, at: next) else { break }
                keys += group.content.split(separator: ",").map { LedgerOrder.stripped(String($0)) }.filter { !$0.isEmpty }
                at = group.end
                groups += 1
                if !multiple { break }
                let after = LatexText.skipSpace(chars, from: at)
                guard after < chars.count, chars[after] == "[" || chars[after] == "{" else { break }
            }
            guard groups > 0 else { continue }
            consumed = at
            let line = lineNumber(of: command.start, lineStarts: lineStarts)
            var end = at
            let rest = String(chars[at...])
            if let paren = leakedAfter.firstMatch(in: rest, range: NSRange(rest.startIndex..., in: rest)) {
                leaked = true
                end = at + paren.range.length
                consumed = end
            }
            if leaked {
                let text = String(chars[command.start..<min(end, chars.count)])
                leaks.append(Audit.Finding(
                    rule: "R2", severity: "likely", file: source.shown, line: line, match: text,
                    context: Audit.context(source.lines, line: line),
                    proposedFix: "替換 snake_case label 為 content-based 描述,e.g. `Theorem on $\\eta = f(s)$ case`"))
            }
            found.append(Citation(keys: keys, file: file, line: line))
        }
        return found
    }

    static func findings(_ manuscript: Audit.Manuscript, bibliography: Bibliography) -> [Audit.Finding] {
        var leaks: [Audit.Finding] = []
        var citations: [Citation] = []
        for (index, source) in manuscript.sources.enumerated() {
            let text = source.code.joined(separator: "\n")
            let chars = Array(text)
            var starts = [0]
            for (offset, ch) in chars.enumerated() where ch == "\n" { starts.append(offset + 1) }
            citations += AuditCitations.citations(in: chars, file: index, source: source, lineStarts: starts, leaks: &leaks)
        }
        var first: [String: Citation] = [:]
        var everything = false
        for citation in citations {
            for key in citation.keys {
                if key == "*" { everything = true; continue }
                if first[key] == nil { first[key] = citation }
            }
        }
        let bibNames = bibliography.files.isEmpty ? "the bibliography (none was read)" : bibliography.files.joined(separator: ", ")
        var findings = leaks
        for key in sortedKeys(first.keys) where bibliography.entries[key] == nil {
            let citation = first[key]!
            let source = manuscript.sources[citation.file]
            findings.append(Audit.Finding(
                rule: "R2-bis", severity: "definite", file: source.shown, line: citation.line, match: key,
                context: "\\cite*{\(key)} but \(key) not in \(bibNames)",
                proposedFix: "加 \(key) 條目到 bibliography,或修正 cite key typo"))
        }
        if !everything {
            for key in sortedKeys(bibliography.entries.keys) where first[key] == nil {
                let place = bibliography.entries[key]!
                findings.append(Audit.Finding(
                    rule: "R2-bis", severity: "FYI", file: place.file, line: place.line, match: key,
                    context: "@type{\(key), ...} in \(place.file) but never cited",
                    proposedFix: "考慮刪除 \(key) 條目,或確認是否預期但漏 cite"))
            }
        }
        return findings
    }
}
