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
        /// The `cites` list, `nil` when there is none; a list with a value that is not a string is
        /// returned as it is, so that a caller can refuse it rather than drop the value.
        var cites: [JSONValue]? { members?.last(where: { $0.key == "cites" })?.value.array }
        var location: Location? { (members?.last { $0.key == "location" }?.value.string).flatMap(Location.parse) }
    }

    static func lines(_ data: Data) throws -> [Line] {
        try Revise.lines(data).enumerated().map { index, raw in
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
        Data((Revise.dumps(.object(members)) + Revise.ending(of: line.raw)).utf8)
    }

    /// How many live and retired lines hold each id.
    static func census(_ all: [Line]) -> (live: [[UInt32]: Int], retired: [[UInt32]: Int]) {
        var live: [[UInt32]: Int] = [:], retired: [[UInt32]: Int] = [:]
        for line in all {
            guard let id = line.id else { continue }
            if line.isRetired { retired[key(id), default: 0] += 1 } else { live[key(id), default: 0] += 1 }
        }
        return (live, retired)
    }

    /// Why an id does not name exactly one live proposition, or nil when it does.
    static func unresolved(_ id: String, _ census: (live: [[UInt32]: Int], retired: [[UInt32]: Int])) -> String? {
        let live = census.live[key(id)] ?? 0, retired = census.retired[key(id)] ?? 0
        if live == 1 && retired == 0 { return nil }
        if live == 0 && retired == 0 { return "is no proposition of the ledger" }
        if live == 0 { return "is retired" }
        return "is the id of several lines"
    }

    static func key(_ text: String) -> [UInt32] { text.unicodeScalars.map(\.value) }

    // MARK: retire

    struct Retirement: Equatable {
        let id: String
        let replacedBy: [Replacement]
    }

    /// Parses `<id>` or `<id>=<new id>,<new id>`; a new id written `<ledger>#<id>` names a
    /// proposition of another ledger (issue 133).
    /// The bare id is a deletion; after `=`, every id has to be written: `old=` and `old=b,,c` are refused.
    static func retirement(_ argument: String) throws -> Retirement {
        guard let equals = argument.firstIndex(of: "=") else { return Retirement(id: argument, replacedBy: []) }
        let ids = argument[argument.index(after: equals)...].split(separator: ",", omittingEmptySubsequences: false)
            .map { LedgerOrder.stripped(String($0)) }
        guard !ids.contains(where: \.isEmpty) else {
            throw Revise.Failure(message: "--retire \(CiteOrder.visible(argument)) has an empty id after `=`; write the bare id for a deletion")
        }
        return Retirement(id: String(argument[..<equals]), replacedBy: try ids.map { try replacement(argument: $0) })
    }

    static let mechanisms = ["comment_env", "line_comment", "removed"]
    static let matches = ["exact", "by_reading"]

    /// A Gregorian calendar date written `YYYY-MM-DD`, checked by arithmetic: no time zone is involved.
    static func isDate(_ text: String) -> Bool {
        let parts = text.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]), (1...12).contains(month)
        else { return false }
        let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        let length = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
        return (1...length).contains(day)
    }

    static func retire(_ data: Data, retirements: [Retirement], since: String, mechanism: String, match: String,
                       reason: String, ref: String?, others: OtherLedgers) throws -> (Data, [String]) {
        guard isDate(since) else { throw Revise.Failure(message: "--since \(CiteOrder.visible(since)) is not a YYYY-MM-DD date") }
        guard mechanisms.contains(mechanism) else { throw Revise.Failure(message: "--mechanism is one of \(mechanisms.joined(separator: ", "))") }
        guard matches.contains(match) else { throw Revise.Failure(message: "--match is one of \(matches.joined(separator: ", "))") }
        guard !LedgerOrder.stripped(reason).isEmpty else { throw Revise.Failure(message: "--reason is empty") }
        let all = try lines(data)
        let counts = census(all)
        var byID: [[UInt32]: [Line]] = [:]
        for line in all { if let id = line.id { byID[key(id), default: []].append(line) } }
        let retiring = Set(retirements.map { key($0.id) })
        // A retirement already in the ledger that names one of these as its replacement would stop
        // naming a live proposition.
        for line in all where line.isRetired {
            for item in line.retired?.members?.last(where: { $0.key == "replaced_by" })?.value.array ?? [] {
                if let named = item.string, retiring.contains(key(named)) {
                    throw Revise.Failure(message: "\(CiteOrder.visible(named)) replaces \(CiteOrder.visible(line.id ?? "?")) (line \(line.number)); retire it with that retirement changed by hand")
                }
            }
        }
        var seen = Set<[UInt32]>()
        for item in retirements {
            let name = CiteOrder.visible(item.id)
            guard seen.insert(key(item.id)).inserted else { throw Revise.Failure(message: "\(name) is named twice") }
            guard let found = byID[key(item.id)], found.count == 1 else {
                throw Revise.Failure(message: byID[key(item.id)] == nil ? "no proposition \(name)" : "\(name) is the id of several lines")
            }
            guard !found[0].isRetired else { throw Revise.Failure(message: "\(name) is already retired") }
            for replacement in item.replacedBy {
                let shown = replacement.shown
                guard case .here(let new) = replacement else {
                    if case .there(let ledger, let id) = replacement, let why = others.why(ledger, id) {
                        throw Revise.Failure(message: "\(shown), named to replace \(name), \(why)")
                    }
                    continue
                }
                guard key(new) != key(item.id) else { throw Revise.Failure(message: "\(name) cannot replace itself") }
                guard !retiring.contains(key(new)) else {
                    throw Revise.Failure(message: "\(shown), named to replace \(name), is retired by this run")
                }
                if let why = unresolved(new, counts) {
                    throw Revise.Failure(message: why == "is no proposition of the ledger"
                        ? "no proposition \(shown), named to replace \(name)" : "\(shown), named to replace \(name), \(why)")
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
            let entry = block + [JSONMember(key: "replaced_by", value: .array(item.replacedBy.map(\.json)))]
            out.append(Self.line(line, with: Revise.setting(members, "retired", to: .object(entry))))
            report.append(item.replacedBy.isEmpty ? "retire \(CiteOrder.visible(id)): deleted, no replacement"
                : "retire \(CiteOrder.visible(id)): replaced by \(item.replacedBy.map(\.shown).joined(separator: ", "))")
        }
        return (out, report)
    }

    // MARK: check

    /// What a ledger's `replaced_by` lists say: a problem for each id that does not name a live
    /// proposition, and how many retirements are replaced, deleted, or not recorded.
    static func check(_ data: Data, others: OtherLedgers) throws -> (problems: [String], replaced: Int, deleted: Int, unrecorded: Int) {
        let all = try lines(data)
        let counts = census(all)
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
                guard let replacement = replacement(item) else {
                    problems.append("line \(line.number): the replaced_by of \(name) holds a value that is neither an id nor {\"ledger\", \"id\"}")
                    good = false
                    continue
                }
                guard case .here(let new) = replacement else {
                    if case .there(let ledger, let id) = replacement, let why = others.why(ledger, id) {
                        problems.append("line \(line.number): \(name) is replaced by \(replacement.shown), which \(why)")
                        good = false
                    }
                    continue
                }
                if key(new) == key(line.id ?? "") {
                    problems.append("line \(line.number): \(name) is listed as its own replacement")
                    good = false
                } else if let why = unresolved(new, counts) {
                    problems.append("line \(line.number): \(name) is replaced by \(CiteOrder.visible(new)), which \(why)")
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
    static func redirect(_ data: Data, order: ReadingOrder, others: OtherLedgers) throws -> (Data, [String], unplaced: [String]) {
        let all = try lines(data)
        let counts = census(all)
        var replacements: [[UInt32]: [String]] = [:]
        // Replacements in another ledger: a citation cannot follow them (issue 133).
        var elsewhere: [[UInt32]: [String]] = [:]
        var retiredIDs = Set<[UInt32]>()
        var places: [[UInt32]: [Int]] = [:]
        for line in all {
            guard let id = line.id else { continue }
            if line.isRetired {
                retiredIDs.insert(key(id))
                guard let list = line.retired?.members?.last(where: { $0.key == "replaced_by" })?.value else { continue }
                // A list that is not one of ids naming one live proposition each is refused, not read as none.
                guard let items = list.array?.map(replacement), items.allSatisfy({ $0 != nil }) else {
                    throw Revise.Failure(message: "the replaced_by of \(CiteOrder.visible(id)) (line \(line.number)) is not a list of ids; run revise check")
                }
                let parsed = items.compactMap { $0 }
                let ids = parsed.compactMap { item -> String? in if case .here(let new) = item { return new }; return nil }
                for item in parsed {
                    if case .there(let ledger, let other) = item, let why = others.why(ledger, other) {
                        throw Revise.Failure(message: "\(item.shown), which replaces \(CiteOrder.visible(id)) (line \(line.number)), \(why); run revise check")
                    }
                }
                elsewhere[key(id)] = parsed.compactMap { item -> String? in if case .there = item { return item.shown }; return nil }
                for new in ids {
                    if let why = unresolved(new, counts) {
                        throw Revise.Failure(message: "\(CiteOrder.visible(new)), which replaces \(CiteOrder.visible(id)) (line \(line.number)), \(why); run revise check")
                    }
                }
                replacements[key(id)] = ids
            } else if let location = line.location, let position = order.position(file: location.file, line: location.start) {
                places[key(id)] = position
            }
        }
        var out = Data()
        var report: [String] = []
        var unplaced: [String] = []
        for line in all {
            guard let id = line.id, !line.isRetired, let cites = line.cites, let members = line.members,
                  cites.contains(where: { $0.string.map { retiredIDs.contains(key($0)) } ?? false })
            else {
                out.append(line.raw)
                continue
            }
            let name = CiteOrder.visible(id)
            guard cites.allSatisfy({ $0.string != nil }) else {
                throw Revise.Failure(message: "the cites of \(name) (line \(line.number)) holds a value that is not an id")
            }
            let ids = cites.compactMap(\.string)
            let here = places[key(id)]
            if here == nil { unplaced.append(name) }
            // The citations that stay keep their places; a replacement is not added twice.
            var taken = Set(ids.filter { !retiredIDs.contains(key($0)) }.map(key))
            var result: [String] = []
            var kept = Set<[UInt32]>()
            for cited in ids {
                let shown = CiteOrder.visible(cited)
                guard retiredIDs.contains(key(cited)) else {
                    if kept.insert(key(cited)).inserted { result.append(cited) }
                    continue
                }
                let away = elsewhere[key(cited)] ?? []
                guard let list = replacements[key(cited)], !list.isEmpty else {
                    report.append(away.isEmpty ? "drop \(name): \(shown) is retired and has no replacement"
                        : "drop \(name): \(shown) is replaced only in another ledger (\(away.joined(separator: ", "))), which a citation cannot cross")
                    continue
                }
                if !away.isEmpty {
                    report.append("note \(name): \(shown) is also replaced in another ledger (\(away.joined(separator: ", "))), which a citation cannot cross")
                }
                var added: [String] = []
                for new in list {
                    let other = CiteOrder.visible(new)
                    if key(new) == key(id) {
                        report.append("drop \(name): \(other), which replaces \(shown), is \(name) itself")
                    } else if taken.contains(key(new)) {
                        continue
                    } else if let here {
                        guard let there = places[key(new)] else {
                            report.append("drop \(name): \(other), which replaces \(shown), has no place in the reading order")
                            continue
                        }
                        guard ReadingOrder.precedes(there, here) else {
                            report.append("drop \(name): \(other), which replaces \(shown), does not come before it")
                            continue
                        }
                        added.append(new)
                    } else {
                        added.append(new)
                    }
                    if added.last.map({ key($0) == key(new) }) == true { taken.insert(key(new)) }
                }
                result += added
                if added.isEmpty {
                    report.append("drop \(name): \(shown), whose replacements are cited already or cannot be cited")
                } else {
                    report.append("redirect \(name): \(shown) -> \(added.map(CiteOrder.visible).joined(separator: ", "))")
                }
            }
            out.append(Self.line(line, with: Revise.setting(members, "cites", to: .array(result.map { .string($0) }))))
        }
        return (out, report, unplaced)
    }
}
