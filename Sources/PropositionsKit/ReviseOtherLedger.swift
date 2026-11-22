import Foundation

/// A `replaced_by` item that names a proposition of another ledger (issue 133, schema v1.9): the
/// passage moved to another document, whose ledger holds the propositions that replace it.
extension ReviseLedger {
    /// One item of a `replaced_by` list: an id of this ledger, written as a string, or a
    /// proposition of another ledger, written `{"ledger": <path>, "id": <id>}` with the path
    /// relative to the directory of the ledger that holds the retirement.
    enum Replacement: Equatable {
        case here(String)
        case there(ledger: String, id: String)

        /// `<id>`, or `<path>#<id>` as `revise retire` takes it.
        var shown: String {
            switch self {
            case .here(let id): return CiteOrder.visible(id)
            case .there(let ledger, let id): return CiteOrder.visible(ledger + "#" + id)
            }
        }

        var json: JSONValue {
            switch self {
            case .here(let id): return .string(id)
            case .there(let ledger, let id):
                return .object([JSONMember(key: "ledger", value: .string(ledger)), JSONMember(key: "id", value: .string(id))])
            }
        }
    }

    /// The item read, or `nil` when it is neither a string nor an object with exactly the keys
    /// `ledger` and `id`, each once, both non-empty strings, the path not absolute.
    static func replacement(_ value: JSONValue) -> Replacement? {
        if let id = value.string { return .here(id) }
        guard case .object(let members) = value, members.count == 2,
              Set(members.map { key($0.key) }) == [key("ledger"), key("id")],
              let ledger = members.first(where: { $0.key == "ledger" })?.value.string,
              let id = members.first(where: { $0.key == "id" })?.value.string,
              !LedgerOrder.stripped(ledger).isEmpty, !ledger.hasPrefix("/"), !LedgerOrder.stripped(id).isEmpty
        else { return nil }
        return .there(ledger: ledger, id: id)
    }

    /// Parses one replacement of `--retire`: `<id>`, or `<path>#<id>` for another ledger (the
    /// last `#` splits them).
    static func replacement(argument: String) throws -> Replacement {
        guard let hash = argument.lastIndex(of: "#") else { return .here(argument) }
        let ledger = String(argument[..<hash]), id = String(argument[argument.index(after: hash)...])
        guard !LedgerOrder.stripped(ledger).isEmpty, !LedgerOrder.stripped(id).isEmpty else {
            throw Revise.Failure(message: "\(CiteOrder.visible(argument)) is not <ledger>#<id>")
        }
        guard !ledger.hasPrefix("/") else {
            throw Revise.Failure(message: "\(CiteOrder.visible(argument)): the ledger is written relative to this ledger's directory")
        }
        return .there(ledger: ledger, id: id)
    }

    /// The other ledgers a ledger's retirements name, each read once.
    final class OtherLedgers {
        /// The directory the paths are relative to: that of the ledger, or the one given for a copy.
        let directory: URL
        /// The places that are this ledger itself, by path and by file (device and inode, so that a
        /// hard link counts too).
        let itself: Set<String>
        let itselfFiles: Set<[UInt64]>
        private var read: [String: (live: [[UInt32]: Int], retired: [[UInt32]: Int])?] = [:]

        init(directory: URL, itself: [URL]) {
            self.directory = directory
            self.itself = Set(itself.map(OtherLedgers.place))
            self.itselfFiles = Set(itself.compactMap(OtherLedgers.file))
        }

        static func place(_ url: URL) -> String { url.resolvingSymlinksInPath().standardizedFileURL.path }

        static func file(_ url: URL) -> [UInt64]? {
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let device = (attributes[.systemNumber] as? NSNumber)?.uint64Value,
                  let inode = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value else { return nil }
            return [device, inode]
        }

        /// Why `id` does not name exactly one live proposition of the ledger at `path`, or `nil`.
        func why(_ path: String, _ id: String) -> String? {
            let url = directory.appendingPathComponent(path)
            let place = Self.place(url)
            if itself.contains(place) || Self.file(url).map(itselfFiles.contains) == true { return "names this ledger: write the id alone" }
            if read.index(forKey: place) == nil {
                // updateValue keeps a ledger that cannot be read as a nil entry; a subscript would drop it.
                read.updateValue(LedgerOrder.read(url).flatMap { try? ReviseLedger.lines($0.data) }.map(census), forKey: place)
            }
            guard let counts = read[place] ?? nil else { return "is in a ledger that cannot be read" }
            let reason = ReviseLedger.unresolved(id, counts)
            return reason == "is no proposition of the ledger" ? "is no proposition of that ledger" : reason
        }
    }
}
