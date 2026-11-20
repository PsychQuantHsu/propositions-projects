import Foundation

/// Puts a ledger's lines into reading order: the Swift port of `reorder-ledger.py`.
///
/// Lines are moved, never edited: each keeps its bytes. A proposition that is not retired is an
/// anchor; every other line (a retired proposition, a comment, an empty line, a JSON value that
/// is not an object) stays behind the anchor it followed. Anchors are sorted by where their
/// `location` starts; anchors at the same place keep their order and are reported, because only
/// a reader can tell whether that order is right.
///
/// Without an input tree the key is the first line of the location, and a location that names
/// another file is refused, as the Python tool has it. With one, the key is the position of that
/// line in the manuscript's reading order, so a manuscript of several files can be ordered.
public enum LedgerOrder {
    public struct Failure: Error, Equatable {
        public let message: String
    }

    public struct Plan: Equatable, Sendable {
        /// The ledger's lines in reading order, each with its line ending.
        public let lines: [Data]
        /// How many line positions hold another line than before.
        public let moved: Int
        /// The places that hold more than one proposition, in order, as they are printed.
        public let ties: [String]

        public var content: Data { lines.reduce(into: Data()) { $0.append($1) } }
    }

    /// The characters Python's `str.strip()` removes.
    static func isPythonSpace(_ scalar: Unicode.Scalar) -> Bool {
        switch scalar.value {
        case 0x09...0x0D, 0x1C...0x20, 0x85, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000:
            return true
        default:
            return false
        }
    }

    static func stripped(_ text: String) -> String {
        var scalars = Substring.UnicodeScalarView(text.unicodeScalars)
        while let first = scalars.first, isPythonSpace(first) { scalars.removeFirst() }
        while let last = scalars.last, isPythonSpace(last) { scalars.removeLast() }
        return String(scalars)
    }

    /// Splits at each line feed and keeps it with its line. A last line without one is given one.
    static func rawLines(_ data: Data) -> [Data] {
        var lines: [Data] = []
        var start = data.startIndex
        for index in data.indices where data[index] == 0x0A {
            lines.append(data[start...index])
            start = data.index(after: index)
        }
        if start < data.endIndex { lines.append(data[start...] + Data([0x0A])) }
        return lines.map { Data($0) }
    }

    /// `order` nil is the single-file reading the Python tool has.
    public static func plan(_ data: Data, order: ReadingOrder?) throws -> Plan {
        struct Block {
            let key: [Int]
            let place: String
            var lines: [Data]
        }
        let raw = rawLines(data)
        var head: [Data] = []
        var blocks: [Block] = []
        for (index, line) in raw.enumerated() {
            guard let text = String(data: line, encoding: .utf8) else {
                throw Failure(message: "line \(index + 1) of the ledger is not UTF-8")
            }
            let body = stripped(text)
            var anchor: (key: [Int], place: String)?
            // Two slashes as code points, as Python's startswith has it: a combining mark after
            // them does not make the line something else.
            if !body.isEmpty, !body.unicodeScalars.starts(with: "//".unicodeScalars) {
                let value: JSONValue
                do {
                    value = try JSONValue.parse(body)
                } catch {
                    throw Failure(message: "invalid JSON on line \(index + 1) of the ledger")
                }
                if let members = value.members, !members.contains(where: { $0.key == "retired" }) {
                    anchor = try key(of: members, order: order)
                }
            }
            if let anchor {
                blocks.append(Block(key: anchor.key, place: anchor.place, lines: [line]))
            } else if blocks.isEmpty {
                head.append(line)
            } else {
                blocks[blocks.count - 1].lines.append(line)
            }
        }
        // A stable sort: blocks at the same place keep their order.
        let sorted = blocks.enumerated().sorted { a, b in
            if a.element.key == b.element.key { return a.offset < b.offset }
            return ReadingOrder.precedes(a.element.key, b.element.key)
        }.map(\.element)
        var counts: [[Int]: (count: Int, place: String)] = [:]
        for block in blocks { counts[block.key, default: (0, block.place)].count += 1 }
        let ties = counts.filter { $0.value.count > 1 }
            .sorted { ReadingOrder.precedes($0.key, $1.key) }
            .map(\.value.place)
        let result = head + sorted.flatMap(\.lines)
        let moved = zip(raw, result).filter { $0 != $1 }.count
        return Plan(lines: result, moved: moved, ties: ties)
    }

    private static func key(of members: [JSONMember], order: ReadingOrder?) throws -> (key: [Int], place: String) {
        // A key written twice: the last one counts, as Python's json has it.
        let id = members.last { $0.key == "id" }?.value.string ?? "?"
        let name = CiteOrder.visible(id)
        guard let rawLocation = members.last(where: { $0.key == "location" })?.value.string,
              let location = Location.parse(rawLocation)
        else {
            throw Failure(message: "cannot parse the location of \(name)")
        }
        let shown = CiteOrder.visible(rawLocation)
        guard let order else {
            // The Python tool reads a prefix of exactly `main.tex` as the main file, and no other.
            guard location.file == nil || location.file == "main.tex" else {
                throw Failure(message:
                    "location \(shown) names another file; pass --tex with the manuscript's main file to order a manuscript of several files")
            }
            return ([location.start], String(location.start))
        }
        guard let position = order.position(file: location.file, line: location.start) else {
            throw Failure(message: "location \(shown) of \(name) names a file that is not in the input tree of \(CiteOrder.visible(order.mainName))")
        }
        let file = location.file.map(ReadingOrder.normalise) ?? "main.tex"
        return (position, "\(CiteOrder.visible(file)):\(location.start)")
    }

    /// A ledger as it was read: its bytes, and the file they came from.
    public struct Snapshot: Equatable, Sendable {
        public let data: Data
        let device: dev_t
        let inode: ino_t
        let mode: mode_t
    }

    /// Reads an open file to its end, and says which file it is. `nil` when it is not a regular file.
    private static func snapshot(of descriptor: Int32) -> Snapshot? {
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & S_IFMT == S_IFREG else { return nil }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1 << 16)
        while true {
            let count = Foundation.read(descriptor, &buffer, buffer.count)
            if count < 0 { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return Snapshot(data: data, device: info.st_dev, inode: info.st_ino, mode: info.st_mode & 0o7777)
    }

    /// The ledger at a path, read through one open file, so that the bytes and the identity are
    /// of the same file. A link is followed here: a dry run of a linked ledger is answered.
    /// O_NONBLOCK keeps a pipe at that path from holding the command; it is then refused.
    public static func read(_ url: URL) -> Snapshot? {
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK)
        guard descriptor >= 0 else { return nil }
        defer { close(descriptor) }
        return snapshot(of: descriptor)
    }

    /// Replaces the ledger through a temporary file beside it, with the ledger's permission bits.
    ///
    /// The ledger is replaced only if, at the last look, the path is not a link and names the same
    /// file as `read`, with the same permission bits and the same bytes, all three taken from one
    /// open file. A save or a change of permissions made in between is so not undone; the moment
    /// between that look and the rename is the one that remains.
    ///
    /// Returns whether the directory was synced after the rename.
    public static func write(_ content: Data, to url: URL, replacing read: Snapshot) throws -> Bool {
        var template = Array((url.path + ".XXXXXX").utf8CString)
        let descriptor = mkstemp(&template)
        guard descriptor >= 0 else { throw Failure(message: "cannot write beside the ledger; nothing was written") }
        let temporary = String(cString: template)
        var done = false
        defer {
            close(descriptor)
            if !done { unlink(temporary) }
        }
        let written = content.withUnsafeBytes { buffer -> Bool in
            var offset = 0
            while offset < buffer.count {
                let count = Foundation.write(descriptor, buffer.baseAddress! + offset, buffer.count - offset)
                if count <= 0 { return false }
                offset += count
            }
            return true
        }
        guard written, fchmod(descriptor, read.mode) == 0, fsync(descriptor) == 0 else {
            throw Failure(message: "cannot write the new ledger; nothing was changed")
        }
        // The system can drop a bit it was asked to set (set-group-id, for one).
        var made = stat()
        guard fstat(descriptor, &made) == 0, made.st_mode & 0o7777 == read.mode else {
            throw Failure(message: "the new ledger cannot be given the permissions of the ledger; nothing was changed")
        }
        let directory = open(url.deletingLastPathComponent().path, O_RDONLY)
        defer { if directory >= 0 { close(directory) } }
        // The last look: one open file, not reached through a link, gives identity, mode and bytes.
        let current = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK)
        guard current >= 0 else {
            throw Failure(message: errno == ELOOP
                ? "the ledger is named through a link; nothing was written. Name the file itself"
                : "the ledger can no longer be read; nothing was written")
        }
        var before = stat(), after = stat(), named = stat()
        let lookedBefore = fstat(current, &before) == 0
        let now = snapshot(of: current)
        let lookedAfter = fstat(current, &after) == 0
        close(current)
        // The file was not written to while it was reread, and the path still names it and no link.
        let steady = lookedBefore && lookedAfter && before.st_size == after.st_size
            && before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec
            && before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec
            && lstat(url.path, &named) == 0 && named.st_mode & S_IFMT == S_IFREG
            && named.st_dev == read.device && named.st_ino == read.inode
        guard now == read, steady else {
            throw Failure(message: "the ledger changed while it was being ordered; nothing was written. Run the command again")
        }
        guard rename(temporary, url.path) == 0 else { throw Failure(message: "cannot put the new ledger in place; nothing was changed") }
        done = true
        // So that the rename itself survives a crash.
        return directory >= 0 && fsync(directory) == 0
    }
}

/// `propositions ledger-order`.
///
/// Exit codes, as the Python tool has them: 0 the ledger is in reading order, or was written;
/// 1 a dry run in which lines would move; 2 the ledger or the main file cannot be read, a line
/// is not JSON, a location cannot be used, or an argument is wrong.
public enum LedgerOrderRun {
    public static func run(jsonl: String, tex: String?, write: Bool, workingDirectory: URL) -> CommandResult {
        func resolve(_ path: String) -> URL {
            path.hasPrefix("/") ? URL(fileURLWithPath: path) : workingDirectory.appendingPathComponent(path)
        }
        func refuse(_ message: String) -> CommandResult {
            CommandResult(stderr: ["error: \(message)"], exitCode: 2)
        }
        let ledgerURL = resolve(jsonl)
        guard let snapshot = LedgerOrder.read(ledgerURL) else {
            return refuse("ledger not found, or not a regular file that can be read: \(CiteOrder.visible(jsonl))")
        }
        let data = snapshot.data
        var order: ReadingOrder?
        var notes: [String] = []
        if let tex {
            let mainURL = resolve(tex)
            var info = stat()
            guard stat(mainURL.path, &info) == 0, info.st_mode & S_IFMT == S_IFREG else {
                return refuse("cannot read the main file \(CiteOrder.visible(tex))")
            }
            do {
                let tree = try ReadingOrder(mainFile: mainURL)
                notes = tree.skippedImports.map {
                    "[warn] non-standard import macro skipped at \(CiteOrder.visible($0)) (\\subimport/\\subfile/\\import unsupported)"
                }
                order = tree
            } catch {
                return refuse(CiteOrder.visible("\(error)"))
            }
        }
        let plan: LedgerOrder.Plan
        do {
            plan = try LedgerOrder.plan(data, order: order)
        } catch let failure as LedgerOrder.Failure {
            return CommandResult(stderr: notes + ["error: \(failure.message)"], exitCode: 2)
        } catch {
            return CommandResult(stderr: notes + ["error: the ledger could not be read"], exitCode: 2)
        }
        var out: [String] = []
        if !plan.ties.isEmpty {
            let shown = plan.ties.prefix(20)
            // Without an input tree the places are TeX lines, printed as the Python tool prints them.
            let list = order == nil ? "[\(shown.joined(separator: ", "))]" : shown.joined(separator: ", ")
            let what = order == nil ? "TeX line(s) hold" : "place(s) hold"
            out.append("\(plan.ties.count) \(what) several propositions on the same line, check their order: \(list)")
        }
        if plan.moved == 0 {
            return CommandResult(stdout: out + ["already in reading order"], stderr: notes, exitCode: 0)
        }
        out.append("\(plan.moved) line(s) move")
        guard write else { return CommandResult(stdout: out, stderr: notes, exitCode: 1) }
        let synced: Bool
        do {
            synced = try LedgerOrder.write(plan.content, to: ledgerURL, replacing: snapshot)
        } catch let failure as LedgerOrder.Failure {
            return CommandResult(stdout: out, stderr: notes + ["error: \(failure.message)"], exitCode: 2)
        } catch {
            return CommandResult(stdout: out, stderr: notes + ["error: the ledger could not be written"], exitCode: 2)
        }
        if !synced {
            notes.append("[warn] the ledger was replaced, but its directory could not be synced: after a crash the old ledger may be back")
        }
        return CommandResult(stdout: out + ["written: \(CiteOrder.visible(jsonl))"], stderr: notes, exitCode: 0)
    }
}
