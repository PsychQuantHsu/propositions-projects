import Foundation

/// `revise retire`, `revise check` and `revise redirect`: the retirements of a revision and the
/// citations that pointed at them (issue 56, schema v1.8 `retired.replaced_by`).
enum ReviseLedger {
    /// One line of a ledger: its bytes, and the object on it when it is one.
    struct Line {
        let number: Int
        let raw: Data
        let members: [JSONMember]?

        var id: String? { members?.last { $0.key == "id" }?.value.string }
        var retired: JSONValue? { members?.last { $0.key == "retired" }?.value }
        var isRetired: Bool { members?.contains { $0.key == "retired" } ?? false }
        var cites: [String]? {
            guard let value = members?.last(where: { $0.key == "cites" })?.value else { return nil }
            return value.array?.compactMap(\.string)
        }
        var location: Location? { (members?.last { $0.key == "location" }?.value.string).flatMap(Location.parse) }
    }

    static func lines(_ data: Data) throws -> [Line] {
        try LedgerOrder.rawLines(data).enumerated().map { index, raw in
            guard let text = String(data: raw, encoding: .utf8) else {
                throw Revise.Failure(message: "line \(index + 1) of the ledger is not UTF-8")
            }
            let body = LedgerOrder.stripped(text)
            if body.isEmpty || body.unicodeScalars.starts(with: "//".unicodeScalars) {
                return Line(number: index + 1, raw: raw, members: nil)
            }
            guard let value = try? JSONValue.parse(body) else {
                throw Revise.Failure(message: "invalid JSON on line \(index + 1) of the ledger")
            }
            return Line(number: index + 1, raw: raw, members: value.members)
        }
    }

    /// The line written again with `members`, keeping its line ending.
    static func line(_ line: Line, with members: [JSONMember]) -> Data {
        let raw = String(decoding: line.raw, as: UTF8.self)
        return Data((Revise.dumps(.object(members)) + (raw.hasSuffix("\r\n") ? "\r\n" : "\n")).utf8)
    }

    static func key(_ text: String) -> [UInt32] { text.unicodeScalars.map(\.value) }

    // MARK: retire

    struct Retirement: Equatable {
        let id: String
        let replacedBy: [String]
    }

    /// Parses `<id>` or `<id>=<new id>,<new id>`.
    static func retirement(_ argument: String) -> Retirement {
        guard let equals = argument.firstIndex(of: "=") else { return Retirement(id: argument, replacedBy: []) }
        let ids = argument[argument.index(after: equals)...].split(separator: ",").map { LedgerOrder.stripped(String($0)) }
        return Retirement(id: String(argument[..<equals]), replacedBy: ids.filter { !$0.isEmpty })
    }

    static let mechanisms = ["comment_env", "line_comment", "removed"]
    static let matches = ["exact", "by_reading"]

    static func isDate(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) })
        else { return false }
        var components = DateComponents()
        (components.year, components.month, components.day) = (year, month, day)
        let calendar = Calendar(identifier: .gregorian)
        guard let date = calendar.date(from: components) else { return false }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        return back.year == year && back.month == month && back.day == day
    }

    static func retire(_ data: Data, retirements: [Retirement], since: String, mechanism: String, match: String,
                       reason: String, ref: String?) throws -> (Data, [String]) {
        guard isDate(since) else { throw Revise.Failure(message: "--since \(CiteOrder.visible(since)) is not a YYYY-MM-DD date") }
        guard mechanisms.contains(mechanism) else { throw Revise.Failure(message: "--mechanism is one of \(mechanisms.joined(separator: ", "))") }
        guard matches.contains(match) else { throw Revise.Failure(message: "--match is one of \(matches.joined(separator: ", "))") }
        guard !LedgerOrder.stripped(reason).isEmpty else { throw Revise.Failure(message: "--reason is empty") }
        let all = try lines(data)
        var byID: [[UInt32]: [Line]] = [:]
        for line in all { if let id = line.id { byID[key(id), default: []].append(line) } }
        var seen = Set<[UInt32]>()
        for item in retirements {
            let name = CiteOrder.visible(item.id)
            guard seen.insert(key(item.id)).inserted else { throw Revise.Failure(message: "\(name) is named twice") }
            guard let found = byID[key(item.id)], found.count == 1 else {
                throw Revise.Failure(message: byID[key(item.id)] == nil ? "no proposition \(name)" : "\(name) is the id of several lines")
            }
            guard !found[0].isRetired else { throw Revise.Failure(message: "\(name) is already retired") }
            for new in item.replacedBy {
                let shown = CiteOrder.visible(new)
                guard key(new) != key(item.id) else { throw Revise.Failure(message: "\(name) cannot replace itself") }
                guard let target = byID[key(new)] else { throw Revise.Failure(message: "no proposition \(shown), named to replace \(name)") }
                guard !target.contains(where: \.isRetired) else { throw Revise.Failure(message: "\(shown), named to replace \(name), is retired") }
                guard !retirements.contains(where: { key($0.id) == key(new) }) else {
                    throw Revise.Failure(message: "\(shown), named to replace \(name), is retired by this run")
                }
            }
        }
        var block: [JSONMember] = [
            JSONMember(key: "since", value: .string(since)), JSONMember(key: "mechanism", value: .string(mechanism)),
            JSONMember(key: "match", value: .string(match)), JSONMember(key: "reason", value: .string(reason)),
        ]
        if let ref { block.append(JSONMember(key: "ref", value: .string(ref))) }
        var out = Data()
        var report: [String] = []
        for line in all {
            guard let id = line.id, let item = retirements.first(where: { key($0.id) == key(id) }), let members = line.members else {
                out.append(line.raw)
                continue
            }
            let entry = block + [JSONMember(key: "replaced_by", value: .array(item.replacedBy.map { .string($0) }))]
            out.append(Self.line(line, with: Revise.setting(members, "retired", to: .object(entry))))
            report.append(item.replacedBy.isEmpty ? "retire \(CiteOrder.visible(id)): deleted, no replacement"
                : "retire \(CiteOrder.visible(id)): replaced by \(item.replacedBy.map(CiteOrder.visible).joined(separator: ", "))")
        }
        return (out, report)
    }

    // MARK: check

    /// What a ledger's `replaced_by` lists say: a problem for each id that does not name a live
    /// proposition, and how many retirements are replaced, deleted, or not recorded.
    static func check(_ data: Data) throws -> (problems: [String], replaced: Int, deleted: Int, unrecorded: Int) {
        let all = try lines(data)
        var live = Set<[UInt32]>()
        var retiredIDs = Set<[UInt32]>()
        for line in all { if let id = line.id { if line.isRetired { retiredIDs.insert(key(id)) } else { live.insert(key(id)) } } }
        var problems: [String] = []
        var replaced = 0, deleted = 0, unrecorded = 0
        for line in all where line.isRetired {
            let name = CiteOrder.visible(line.id ?? "?")
            guard let block = line.retired?.members, let list = block.last(where: { $0.key == "replaced_by" })?.value else {
                unrecorded += 1
                continue
            }
            guard let items = list.array else {
                problems.append("line \(line.number): the replaced_by of \(name) is not a list")
                continue
            }
            if items.isEmpty { deleted += 1; continue }
            var good = true
            for item in items {
                guard let new = item.string else {
                    problems.append("line \(line.number): the replaced_by of \(name) holds a value that is not an id")
                    good = false
                    continue
                }
                let shown = CiteOrder.visible(new)
                if key(new) == key(line.id ?? "") {
                    problems.append("line \(line.number): \(name) is listed as its own replacement")
                    good = false
                } else if retiredIDs.contains(key(new)) && !live.contains(key(new)) {
                    problems.append("line \(line.number): \(name) is replaced by \(shown), which is retired")
                    good = false
                } else if !live.contains(key(new)) {
                    problems.append("line \(line.number): \(name) is replaced by \(shown), which is no proposition of the ledger")
                    good = false
                }
            }
            if good { replaced += 1 }
        }
        return (problems, replaced, deleted, unrecorded)
    }

    // MARK: redirect

    /// Each citation of a retired proposition by a live one is replaced by the propositions that
    /// replace it, in their order, those already cited and those that come later in reading order
    /// left out; a citation of a retired proposition without a replacement is dropped. Other
    /// citations are left as they are.
    static func redirect(_ data: Data, order: ReadingOrder) throws -> (Data, [String], unplaced: [String]) {
        let all = try lines(data)
        var replacements: [[UInt32]: [String]?] = [:]
        var places: [[UInt32]: [Int]] = [:]
        for line in all {
            guard let id = line.id else { continue }
            if line.isRetired {
                let list = line.retired?.members?.last(where: { $0.key == "replaced_by" })?.value.array?.compactMap(\.string)
                replacements[key(id)] = .some(list)
            } else if let location = line.location, let position = order.position(file: location.file, line: location.start) {
                places[key(id)] = position
            }
        }
        var out = Data()
        var report: [String] = []
        var unplaced: [String] = []
        for line in all {
            guard let id = line.id, !line.isRetired, let cites = line.cites, let members = line.members,
                  cites.contains(where: { replacements[key($0)] != nil })
            else {
                out.append(line.raw)
                continue
            }
            let name = CiteOrder.visible(id)
            let here = places[key(id)]
            if here == nil { unplaced.append(name) }
            var result: [String] = []
            for cited in cites {
                guard let entry = replacements[key(cited)] else {
                    if !result.contains(where: { key($0) == key(cited) }) { result.append(cited) }
                    continue
                }
                let shown = CiteOrder.visible(cited)
                guard let list = entry, !list.isEmpty else {
                    report.append("drop \(name): \(shown) is retired and has no replacement")
                    continue
                }
                var taken: [String] = []
                for new in list where !result.contains(where: { key($0) == key(new) }) {
                    if let here, let there = places[key(new)], !ReadingOrder.precedes(there, here) {
                        report.append("drop \(name): \(CiteOrder.visible(new)), which replaces \(shown), does not come before it")
                        continue
                    }
                    taken.append(new)
                }
                result += taken
                if !taken.isEmpty { report.append("redirect \(name): \(shown) -> \(taken.map(CiteOrder.visible).joined(separator: ", "))") }
            }
            out.append(Self.line(line, with: Revise.setting(members, "cites", to: .array(result.map { .string($0) }))))
        }
        return (out, report, unplaced)
    }
}
