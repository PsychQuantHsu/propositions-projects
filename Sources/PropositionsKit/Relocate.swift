import Foundation

/// `propositions revise relocate`: find each proposition's text in the revised manuscript.
///
/// For each proposition that is not retired, the text is looked for as it is written, in every file
/// of the main file's input tree. Where that fails, it is looked for with every run of white space
/// read as one space: a sentence whose lines were broken again. Each proposition comes out in one
/// of five kinds:
///
/// - in place: its text stands where its `location` says;
/// - moved: its text stands elsewhere, and the new `location` is written;
/// - rewrapped: only its white space differs; the new `text`, as the manuscript has it, and the new
///   `location` are written;
/// - ambiguous: its text stands in several places, none of them in the file its `location` names;
/// - missing: its text is not in the manuscript. These are what `revise retire` is for. A text the
///   ledger validator matches only after its normalisation (math, macros) is missing here too.
public enum Relocate {
    public enum Kind: String, Sendable {
        case inPlace = "in place", moved, rewrapped, ambiguous, missing
    }

    public struct Result: Equatable, Sendable {
        public let id: String
        public let kind: Kind
        public let old: String
        /// The new location for a moved or rewrapped proposition; for an ambiguous one, the places.
        public let new: [String]
        /// The new text for a rewrapped proposition.
        public let text: String?
        /// The ledger line, from 1.
        public let line: Int
    }

    struct Occurrence {
        let file: Int
        let range: Range<Int>
    }

    static func isWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isAlphabetic || scalar.properties.numericType != nil || scalar == "_"
    }

    /// Every place `needle` stands in a file as a whole: not inside a `%` comment, and not part of a
    /// longer word (`A is prime` does not stand in `A is primeval`).
    static func occurrences(of needle: [Unicode.Scalar], in file: Revise.ManuscriptFile,
                            map: (Range<Int>) -> Range<Int> = { $0 }, haystack: [Unicode.Scalar]? = nil) -> [Range<Int>] {
        let text = haystack ?? file.text
        guard !needle.isEmpty, needle.count <= text.count else { return [] }
        var found: [Range<Int>] = []
        var index = 0
        while index <= text.count - needle.count {
            if text[index] == needle[0], text[index..<(index + needle.count)].elementsEqual(needle) {
                let original = map(index..<(index + needle.count))
                let before = original.lowerBound > 0 ? file.text[original.lowerBound - 1] : nil
                let after = original.upperBound < file.text.count ? file.text[original.upperBound] : nil
                let joinsBefore = before.map { isWordScalar($0) && isWordScalar(file.text[original.lowerBound]) } ?? false
                let joinsAfter = after.map { isWordScalar($0) && isWordScalar(file.text[original.upperBound - 1]) } ?? false
                let inComment = original.contains { file.commented[$0] }
                if !joinsBefore, !joinsAfter, !inComment { found.append(original) }
            }
            index += 1
        }
        return found
    }

    static func isSpace(_ scalar: Unicode.Scalar) -> Bool { scalar.properties.isWhitespace }

    /// The text with every run of white space as one space, and for each of its scalars the range
    /// of the original it stands for.
    static func collapsed(_ text: [Unicode.Scalar]) -> (scalars: [Unicode.Scalar], spans: [Range<Int>]) {
        var scalars: [Unicode.Scalar] = []
        var spans: [Range<Int>] = []
        var index = 0
        while index < text.count {
            if isSpace(text[index]) {
                let start = index
                while index < text.count, isSpace(text[index]) { index += 1 }
                scalars.append(" ")
                spans.append(start..<index)
            } else {
                scalars.append(text[index])
                spans.append(index..<(index + 1))
                index += 1
            }
        }
        return (scalars, spans)
    }

    static func trimmed(_ text: [Unicode.Scalar]) -> [Unicode.Scalar] {
        Array(text.drop(while: isSpace).reversed().drop(while: isSpace).reversed())
    }

    enum Choice {
        case none
        case one(Occurrence)
        case several
    }

    /// Of the places, the one in the file the location names nearest its line; or the only one.
    /// Two places equally near, or several outside that file, are several.
    static func choose(_ found: [Occurrence], files: [Revise.ManuscriptFile], claimed: Location?) -> Choice {
        if found.isEmpty { return .none }
        let claimedName = claimed.map { $0.file.map(ReadingOrder.normalise) ?? "main.tex" }
        let inClaimed = found.filter { files[$0.file].name == claimedName }
        if !inClaimed.isEmpty, let claimed {
            let distance = { (o: Occurrence) in abs(files[o.file].line(of: o.range.lowerBound) - claimed.start) }
            let nearest = inClaimed.map(distance).min()!
            let tied = inClaimed.filter { distance($0) == nearest }
            return tied.count == 1 ? .one(tied[0]) : .several
        }
        return found.count == 1 ? .one(found[0]) : .several
    }

    static func plan(ledger: Data, files: [Revise.ManuscriptFile]) throws -> [Result] {
        var results: [Result] = []
        let collapsedFiles = files.map { collapsed($0.text) }
        for (index, line) in Revise.lines(ledger).enumerated() {
            guard let raw = String(data: line, encoding: .utf8) else {
                throw Revise.Failure(message: "line \(index + 1) of the ledger is not UTF-8")
            }
            let body = LedgerOrder.stripped(raw)
            if body.isEmpty || body.unicodeScalars.starts(with: "//".unicodeScalars) { continue }
            guard let value = try? JSONValue.parse(body) else {
                throw Revise.Failure(message: "invalid JSON on line \(index + 1) of the ledger")
            }
            guard let members = value.members, !members.contains(where: { $0.key == "retired" }) else { continue }
            let id = members.last { $0.key == "id" }?.value.string ?? "?"
            let old = members.last { $0.key == "location" }?.value.string ?? ""
            guard let text = members.last(where: { $0.key == "text" })?.value.string,
                  !trimmed(Array(text.unicodeScalars)).isEmpty
            else {
                throw Revise.Failure(message: "the proposition \(CiteOrder.visible(id)) on line \(index + 1) has no text")
            }
            let claimed = Location.parse(old)
            let needle = Array(text.unicodeScalars)
            var found = files.indices.flatMap { file in
                occurrences(of: needle, in: files[file]).map { Occurrence(file: file, range: $0) }
            }
            var rewrapped = false
            if found.isEmpty {
                let short = collapsed(trimmed(needle)).scalars
                found = files.indices.flatMap { file -> [Occurrence] in
                    let (scalars, spans) = collapsedFiles[file]
                    return occurrences(of: short, in: files[file], map: { spans[$0.lowerBound].lowerBound..<spans[$0.upperBound - 1].upperBound },
                                       haystack: scalars).map { Occurrence(file: file, range: $0) }
                }
                rewrapped = !found.isEmpty
            }
            switch choose(found, files: files, claimed: claimed) {
            case .none:
                results.append(Result(id: id, kind: .missing, old: old, new: [], text: nil, line: index + 1))
            case .one(let place):
                let location = files[place.file].location(of: place.range)
                if rewrapped {
                    results.append(Result(id: id, kind: .rewrapped, old: old, new: [location],
                                          text: files[place.file].string(place.range), line: index + 1))
                } else if Location.parse(location).map({ sameLocation($0, claimed) }) == true {
                    results.append(Result(id: id, kind: .inPlace, old: old, new: [], text: nil, line: index + 1))
                } else {
                    results.append(Result(id: id, kind: .moved, old: old, new: [location], text: nil, line: index + 1))
                }
            case .several:
                let places = found.map { files[$0.file].location(of: $0.range) }
                results.append(Result(id: id, kind: .ambiguous, old: old, new: places, text: nil, line: index + 1))
            }
        }
        return results
    }

    /// Whether two locations name the same lines: `L5` and `main.tex:L5` do.
    static func sameLocation(_ a: Location, _ b: Location?) -> Bool {
        guard let b else { return false }
        func file(_ l: Location) -> String { l.file.map(ReadingOrder.normalise) ?? "main.tex" }
        return file(a) == file(b) && a.start == b.start && a.end == b.end
    }

    /// The ledger with the moved and rewrapped propositions written again; every other line keeps
    /// its bytes, a last line without a line feed included.
    static func rewritten(ledger: Data, results: [Result]) throws -> Data {
        let changes = Dictionary(results.filter { $0.kind == .moved || $0.kind == .rewrapped }.map { ($0.line, $0) },
                                 uniquingKeysWith: { a, _ in a })
        var out = Data()
        for (index, line) in Revise.lines(ledger).enumerated() {
            guard let change = changes[index + 1] else { out.append(line); continue }
            guard case let .object(members) = try JSONValue.parse(LedgerOrder.stripped(String(decoding: line, as: UTF8.self))) else {
                throw Revise.Failure(message: "line \(index + 1) of the ledger changed")
            }
            var updated = Revise.setting(members, "location", to: .string(change.new[0]))
            if let text = change.text { updated = Revise.setting(updated, "text", to: .string(text)) }
            out.append(Data((Revise.dumps(.object(updated)) + Revise.ending(of: line)).utf8))
        }
        return out
    }
}

/// The command. Exit codes: 0 every proposition is in place (or, after `--write`, every one that
/// was not is moved or rewrapped and written); 1 something would change in a dry run, or a
/// proposition is ambiguous or missing; 2 a file cannot be read, a line is not JSON, a proposition
/// has no text, or an argument is wrong.
public enum RelocateRun {
    public static func run(jsonl: String, tex: String, write: Bool, workingDirectory: URL) -> CommandResult {
        func resolve(_ path: String) -> URL {
            path.hasPrefix("/") ? URL(fileURLWithPath: path) : workingDirectory.appendingPathComponent(path)
        }
        func refuse(_ message: String, _ notes: [String] = []) -> CommandResult {
            CommandResult(stderr: notes + ["error: \(message)"], exitCode: 2)
        }
        let ledgerURL = resolve(jsonl)
        guard let snapshot = LedgerOrder.read(ledgerURL) else {
            return refuse("ledger not found, or not a regular file that can be read: \(CiteOrder.visible(jsonl))")
        }
        let mainURL = resolve(tex)
        guard Audit.text(of: mainURL) != nil else { return refuse("cannot read the main file \(CiteOrder.visible(tex))") }
        let files: [Revise.ManuscriptFile]
        let notes: [String]
        let results: [Relocate.Result]
        do {
            (files, notes) = try Revise.manuscript(main: mainURL)
            results = try Relocate.plan(ledger: snapshot.data, files: files)
        } catch let failure as Revise.Failure {
            return refuse(failure.message)
        } catch {
            return refuse("the ledger could not be read")
        }
        var out: [String] = []
        for result in results {
            let id = CiteOrder.visible(result.id)
            let old = CiteOrder.visible(result.old)
            switch result.kind {
            case .inPlace: continue
            case .moved, .rewrapped:
                out.append("\(result.kind.rawValue) \(id): \(old) -> \(CiteOrder.visible(result.new[0]))")
            case .ambiguous:
                out.append("ambiguous \(id): \(old); its text stands at \(result.new.map(CiteOrder.visible).joined(separator: ", "))")
            case .missing:
                out.append("missing \(id): \(old)")
            }
        }
        func count(_ kind: Relocate.Kind) -> Int { results.filter { $0.kind == kind }.count }
        out.append("\(count(.inPlace)) in place, \(count(.moved)) moved, \(count(.rewrapped)) rewrapped, "
                   + "\(count(.ambiguous)) ambiguous, \(count(.missing)) missing")
        let changes = count(.moved) + count(.rewrapped)
        let unresolved = count(.ambiguous) + count(.missing)
        guard write, changes > 0 else {
            return CommandResult(stdout: out, stderr: notes, exitCode: changes + unresolved == 0 ? 0 : 1)
        }
        do {
            let content = try Relocate.rewritten(ledger: snapshot.data, results: results)
            if !(try LedgerOrder.write(content, to: ledgerURL, replacing: snapshot)) {
                return CommandResult(stdout: out, stderr: notes + ["[warn] the ledger was replaced, but its directory could not be synced"],
                                     exitCode: unresolved == 0 ? 0 : 1)
            }
        } catch let failure as LedgerOrder.Failure {
            return CommandResult(stdout: out, stderr: notes + ["error: \(failure.message)"], exitCode: 2)
        } catch let failure as Revise.Failure {
            return CommandResult(stdout: out, stderr: notes + ["error: \(failure.message)"], exitCode: 2)
        } catch {
            return CommandResult(stdout: out, stderr: notes + ["error: the ledger could not be written"], exitCode: 2)
        }
        return CommandResult(stdout: out + ["written: \(CiteOrder.visible(jsonl))"], stderr: notes, exitCode: unresolved == 0 ? 0 : 1)
    }
}
