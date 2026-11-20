import Foundation

/// The format check of an outline: what can be decided from the three files alone.
///
/// It does not resolve a locator (see `OutlineLocators`) and does not judge a sentence. Every
/// finding names the file and the line.
public enum OutlineCheck {
    static let roles: Set<String> = [
        "abstract", "introduction", "background", "formal_setup", "method", "results", "proofs",
        "discussion", "conclusion", "appendix",
    ]
    static let parts: Set<String> = ["main", "appendix", "supplement"]

    public static func findings(_ outline: Outline) -> [String] {
        var out: [String] = []
        let sections = checkSections(outline.sections, into: &out)
        checkParagraphs(outline.paragraphs, sections: sections, into: &out)
        if let approvals = outline.approvals { checkApprovals(approvals, into: &out) }
        return out
    }

    // MARK: every record

    /// What holds for every record of the section file and the paragraph file. Returns the
    /// record when the line is a JSON object.
    private static func record(_ line: OutlineLine, file: String, controlCharacters: Bool, into out: inout [String])
        -> JSONValue?
    {
        func report(_ message: String) { out.append("\(file) line \(line.number): \(message)") }
        guard let value = line.value, value.isObject else {
            report("not a JSON object")
            return nil
        }
        var repeated: [String] = []
        var control = false
        var large = false
        value.walk { inner in
            switch inner {
            case let .object(members):
                var seen = Set<JSONKey>()
                for member in members {
                    if !seen.insert(JSONKey(member.key)).inserted { repeated.append(member.key) }
                    if OutlineText.hasControl(member.key) { control = true }
                }
            case let .string(text): if OutlineText.hasControl(text) { control = true }
            case let .number(number): if number.isBeyondDouble { large = true }
            default: break
            }
        }
        for key in repeated { report("the key \(JSONValue.quoted(key)) is written twice in one object") }
        if control && controlCharacters { report("a string holds a control character") }
        if large { report("a number is too large for jq to keep") }
        return value
    }

    /// `dropped` and `moved_to`, which a section record and a paragraph record share.
    private static func checkLeftOut(_ record: JSONValue, _ report: (String) -> Void) {
        if record.has("dropped"), record["dropped"]?.nonEmptyString == nil {
            report("dropped is not a non-empty string")
        }
        if record.has("moved_to"),
           record["moved_to"]?.nonEmptyString == nil || record["dropped"]?.nonEmptyString == nil {
            report("moved_to is not a non-empty string on a record that carries dropped")
        }
    }

    private static func reportRepeatedIds(_ ids: [(id: String, line: Int)], file: String, into out: inout [String]) {
        var lines: [JSONKey: [Int]] = [:]
        var order: [String] = []
        for entry in ids {
            if lines[JSONKey(entry.id)] == nil { order.append(entry.id) }
            lines[JSONKey(entry.id), default: []].append(entry.line)
        }
        for id in order {
            let where_ = lines[JSONKey(id)] ?? []
            if where_.count > 1 {
                out.append("\(file): id \(JSONValue.quoted(id)) is on lines \(where_.map(String.init).joined(separator: ", "))")
            }
        }
    }

    // MARK: sections

    struct SectionInfo {
        let index: Int
        let dropped: Bool
    }

    private static func checkSections(_ lines: [OutlineLine], into out: inout [String]) -> [JSONKey: SectionInfo] {
        let file = Outline.sectionFile
        if lines.isEmpty { out.append("\(file): the file holds no record") }
        var known: [JSONKey: SectionInfo] = [:]
        var ids: [(id: String, line: Int)] = []
        for (index, line) in lines.enumerated() {
            guard let record = record(line, file: file, controlCharacters: true, into: &out) else { continue }
            func report(_ message: String) { out.append("\(file) line \(line.number): \(message)") }
            let id = record["id"]?.nonEmptyString
            if id == nil { report("a record has no id") }
            for key in ["heading", "says"] where record[key]?.nonEmptyString == nil {
                report("\(key) is not a non-empty string")
            }
            if record.has("role"), !(record["role"]?.string.map(roles.contains) ?? false) {
                report("role is not one of the roles of the format")
            }
            if record.has("part"), !(record["part"]?.string.map(parts.contains) ?? false) {
                report("part is not one of main, appendix, supplement")
            }
            checkLeftOut(record, report)
            if record.has("parent") {
                if let parent = record["parent"]?.string, let info = known[JSONKey(parent)] {
                    if info.dropped && !record.has("dropped") {
                        report("its parent carries dropped and it does not")
                    }
                } else {
                    report("parent does not name a section record on an earlier line")
                }
            }
            if let id {
                ids.append((id, line.number))
                if known[JSONKey(id)] == nil {
                    known[JSONKey(id)] = SectionInfo(index: index, dropped: record.has("dropped"))
                }
            }
        }
        reportRepeatedIds(ids, file: file, into: &out)
        return known
    }

    // MARK: paragraphs

    /// Whether `value` is a locator in shape: an object with a `file` that a locator can
    /// carry, `label` or `starts` as strings, and `lines` only with `commit`. Returns what is
    /// wrong, or nil.
    static func locatorProblem(_ value: JSONValue) -> String? {
        guard value.isObject else { return "a locator is not an object" }
        if value.has("outline") { return "a reference to another outline stands where only locators go" }
        guard let file = value["file"]?.nonEmptyString else { return "a locator has no file" }
        if !OutlineText.isClean(file) { return "a locator's file name holds a control character" }
        if file.hasPrefix("/") { return "a locator's file is not a path from the root" }
        if !value.has("label") && !value.has("starts") { return "a locator has neither label nor starts" }
        if value.has("label"), value["label"]?.string == nil { return "label is not a string" }
        if value.has("starts"), value["starts"]?.string == nil { return "starts is not a string" }
        if value.has("lines") {
            if !value.has("commit") { return "a locator has lines without commit" }
            let numbers = value["lines"]?.array ?? []
            let pair = numbers.compactMap { item -> Int? in
                guard case let .number(n) = item, !n.negative, !n.digits.isEmpty, n.exponent >= 0, n.digits.count + n.exponent <= 9 else { return nil }
                return Int(n.digits + String(repeating: "0", count: n.exponent))
            }
            if numbers.count != 2 || pair.count != 2 || pair[0] > pair[1] { return "lines is not a list of two line numbers, the first and the last" }
        }
        if value.has("commit"), value["commit"]?.nonEmptyString == nil { return "commit is not a non-empty string" }
        return nil
    }

    /// What is wrong with a reference to another outline, or nil.
    static func referenceProblem(_ value: JSONValue) -> String? {
        if value.has("file") || value["id"]?.nonEmptyString == nil { return "a reference to another outline is not an object with outline and id, and without file" }
        guard let outline = value["outline"]?.nonEmptyString, OutlineText.isClean(outline) else {
            return "a reference to another outline is not an object with outline and id, and without file"
        }
        return nil
    }

    /// The key two locators share when they name the same passage by the same means.
    private static func locatorKey(_ value: JSONValue) -> [JSONKey]? {
        guard locatorProblem(value) == nil, let file = value["file"]?.string else { return nil }
        if let label = value["label"]?.string { return [JSONKey(file), JSONKey("label"), JSONKey(label)] }
        if let starts = value["starts"]?.string { return [JSONKey(file), JSONKey("starts"), JSONKey(starts)] }
        return nil
    }

    private static func checkLocatorList(_ record: JSONValue, _ key: String, _ report: (String) -> Void) {
        guard record.has(key) else { return }
        guard let list = record[key]?.array, !list.isEmpty else {
            report("\(key) is not a list of one or more locators")
            return
        }
        for item in list { if let problem = locatorProblem(item) { report("\(key): \(problem)") } }
    }

    private static func checkParagraphs(_ lines: [OutlineLine], sections: [JSONKey: SectionInfo], into out: inout [String]) {
        let file = Outline.paragraphFile
        var ids: [(id: String, line: Int)] = []
        // An id of a record or of a point on an earlier line, and whether its record is dropped.
        var earlier: [JSONKey: Bool] = [:]
        var closed = Set<JSONKey>()
        var current: JSONKey? = nil
        var furthest: (index: Int, id: String)? = nil

        for line in lines {
            guard let record = record(line, file: file, controlCharacters: true, into: &out) else { continue }
            func report(_ message: String) { out.append("\(file) line \(line.number): \(message)") }
            let id = record["id"]?.nonEmptyString
            let dropped = record.has("dropped")
            var here: [String] = []
            if let id { here.append(id) } else { report("a record or a point has no id") }

            // section, and the order of the groups
            if let section = record["section"]?.string {
                if let info = sections[JSONKey(section)] {
                    if info.dropped && !dropped { report("its section carries dropped and it does not") }
                    let key = JSONKey(section)
                    if current != key {
                        if let current { closed.insert(current) }
                        if closed.contains(key) {
                            report("the records of section \(JSONValue.quoted(section)) are not on consecutive lines")
                        } else if let furthest, info.index < furthest.index {
                            report("section \(JSONValue.quoted(section)) comes before \(JSONValue.quoted(furthest.id)) in the section file and after it here")
                        }
                        current = key
                    }
                    if furthest == nil || info.index > furthest!.index { furthest = (info.index, section) }
                } else {
                    report("section names no section record")
                }
            } else {
                report("section is not a string")
            }

            // points
            if let points = record["points"]?.array, !points.isEmpty {
                for point in points {
                    guard point.isObject else { report("a point is not an object"); continue }
                    if let pointId = point["id"]?.nonEmptyString { here.append(pointId) } else { report("a record or a point has no id") }
                    if point["text"]?.nonEmptyString == nil { report("the text of a point is not a non-empty string") }
                    if point.has("pending"), point["pending"]?.nonEmptyString == nil {
                        report("pending is not a non-empty string")
                    }
                    if point.has("basis") {
                        if let basis = point["basis"]?.array, !basis.isEmpty {
                            for item in basis {
                                let problem = item.has("outline") ? referenceProblem(item) : locatorProblem(item)
                                if let problem { report("basis: \(problem)") }
                            }
                        } else {
                            report("basis is not a list of one or more locators or references to another outline")
                        }
                    }
                }
            } else {
                report("points is not a list of one or more points")
            }

            // sources
            checkLocatorList(record, "from", report)
            checkLocatorList(record, "replaces", report)
            if let from = record["from"]?.array, let replaces = record["replaces"]?.array {
                let keys = from.compactMap(locatorKey)
                if replaces.compactMap(locatorKey).contains(where: keys.contains) {
                    report("a locator is in both from and replaces")
                }
            }
            if record.has("carry") {
                if record["carry"] != .bool(true) { report("carry is not true") }
                if !record.has("from") { report("a record that carries carry has no from") }
            }
            if record.has("edits"), record["edits"]?.nonEmptyString == nil || record["carry"] != .bool(true) {
                report("edits is not a non-empty string on a record that carries carry")
            }
            checkLeftOut(record, report)
            if record.has("note"), record["note"]?.string == nil { report("note is not a string") }

            // uses
            if record.has("uses") {
                if let uses = record["uses"]?.array {
                    for entry in uses {
                        if entry.has("outline") {
                            if let problem = referenceProblem(entry) { report("uses: \(problem)") }
                        } else if let used = entry.nonEmptyString {
                            switch earlier[JSONKey(used)] {
                            case nil: report("uses names \(JSONValue.quoted(used)), which is not a record or a point on an earlier line")
                            case true?: report("uses names \(JSONValue.quoted(used)), which belongs to a record that carries dropped")
                            case false?: break
                            }
                        } else {
                            report("uses has an entry that is neither an id nor a reference to another outline")
                        }
                    }
                } else {
                    report("uses is not a list")
                }
            }

            for item in here {
                ids.append((item, line.number))
                if earlier[JSONKey(item)] == nil { earlier[JSONKey(item)] = dropped }
            }
        }
        reportRepeatedIds(ids, file: file, into: &out)
    }

    // MARK: approvals

    private static func checkApprovals(_ lines: [OutlineLine], into out: inout [String]) {
        let file = Outline.approvalFile
        for line in lines {
            // A statement holds the author's words, line breaks included.
            guard let record = record(line, file: file, controlCharacters: false, into: &out) else { continue }
            func report(_ message: String) { out.append("\(file) line \(line.number): \(message)") }
            if !(record["approved_at"]?.string.map(isTimeWithOffset) ?? false) {
                report("approved_at is not a time with its offset from UTC")
            }
            if record["statement"]?.nonEmptyString == nil { report("statement is not a non-empty string") }
            if record.has("whole"), record["whole"] != .bool(true) { report("whole is not true") }
            guard let entries = record["sections"]?.array, !entries.isEmpty else {
                report("sections is not a list of one or more entries")
                continue
            }
            for entry in entries {
                let section = entry["section"]
                let paragraphs = entry["paragraphs"]?.array
                let sectionId = section?["id"]?.nonEmptyString
                let copiesFit = (paragraphs ?? []).allSatisfy { copy in
                    copy.isObject && copy["id"]?.nonEmptyString != nil && sectionId != nil
                        && copy["section"]?.string.map(JSONKey.init) == sectionId.map(JSONKey.init)
                }
                if !(section?.isObject ?? false) || sectionId == nil || paragraphs == nil || !copiesFit {
                    report("an entry of sections does not hold a section record and a list of paragraph records")
                }
            }
        }
    }

    /// `2026-11-13T16:30:00+08:00`, with or without a fraction of a second, or with `Z`.
    static func isTimeWithOffset(_ text: String) -> Bool {
        let s = Array(text.unicodeScalars)
        func digits(_ range: Range<Int>) -> Bool {
            range.upperBound <= s.count && s[range].allSatisfy { ("0"..."9").contains($0) }
        }
        guard s.count >= 20, digits(0..<4), s[4] == "-", digits(5..<7), s[7] == "-", digits(8..<10), s[10] == "T",
              digits(11..<13), s[13] == ":", digits(14..<16), s[16] == ":", digits(17..<19) else { return false }
        func number(_ range: Range<Int>) -> Int { Int(String(String.UnicodeScalarView(s[range]))) ?? -1 }
        guard (1...12).contains(number(5..<7)), (1...31).contains(number(8..<10)), number(11..<13) <= 23,
              number(14..<16) <= 59, number(17..<19) <= 60 else { return false }
        var i = 19
        if s[i] == "." {
            i += 1
            let start = i
            while i < s.count, ("0"..."9").contains(s[i]) { i += 1 }
            if i == start { return false }
        }
        if i == s.count - 1 { return s[i] == "Z" }
        return i + 6 == s.count && (s[i] == "+" || s[i] == "-") && digits(i + 1..<i + 3) && s[i + 3] == ":"
            && digits(i + 4..<i + 6) && number(i + 1..<i + 3) <= 23 && number(i + 4..<i + 6) <= 59
    }
}
