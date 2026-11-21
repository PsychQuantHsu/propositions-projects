import Foundation

/// The operations for a manuscript that was revised after its ledger was extracted (issue 56).
/// This file holds what they share: writing a ledger line again, and the text of the manuscript.
public enum Revise {
    public struct Failure: Error, Equatable {
        public let message: String
    }

    /// A value as Python's `json.dumps(value, ensure_ascii=False)` writes it, which is how the
    /// Python tools write a ledger line, except that a number keeps the way it was written. A key
    /// written twice keeps its first place and its last value, as a Python dict does.
    public static func dumps(_ value: JSONValue) -> String {
        switch value {
        case .null: return "null"
        case .bool(let flag): return flag ? "true" : "false"
        case .number(let number): return number.literal.isEmpty ? (number.negative ? "-" : "") + number.digits : number.literal
        case .string(let text): return quoted(text)
        case .array(let items): return "[" + items.map(dumps).joined(separator: ", ") + "]"
        case .object(let members):
            return "{" + deduplicated(members).map { quoted($0.key) + ": " + dumps($0.value) }.joined(separator: ", ") + "}"
        }
    }

    /// Members with each key once: at the place it was first written, with the value written last.
    static func deduplicated(_ members: [JSONMember]) -> [JSONMember] {
        var order: [String] = []
        var last: [[UInt32]: JSONValue] = [:]
        var name: [[UInt32]: String] = [:]
        for member in members {
            let key = member.key.unicodeScalars.map(\.value)
            if last[key] == nil { order.append(member.key); name[key] = member.key }
            last[key] = member.value
        }
        return order.map { key in
            let scalars = key.unicodeScalars.map(\.value)
            return JSONMember(key: name[scalars]!, value: last[scalars]!)
        }
    }

    /// A string as `json.dumps(…, ensure_ascii=False)` writes it.
    static func quoted(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case "\u{08}": out += "\\b"
            case "\u{0C}": out += "\\f"
            default:
                if scalar.value < 0x20 {
                    let hex = String(scalar.value, radix: 16)
                    out += "\\u" + String(repeating: "0", count: 4 - hex.count) + hex
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }

    /// The members of an object with `key` set to `value`: in its place when it is there (once,
    /// as above), at the end when it is not.
    static func setting(_ members: [JSONMember], _ key: String, to value: JSONValue) -> [JSONMember] {
        var out = deduplicated(members)
        if let index = out.firstIndex(where: { $0.key.unicodeScalars.elementsEqual(key.unicodeScalars) }) {
            out[index] = JSONMember(key: key, value: value)
        } else {
            out.append(JSONMember(key: key, value: value))
        }
        return out
    }

    /// The lines of a ledger with their bytes as they are: a line keeps its line feed, and a last
    /// line without one stays without one.
    static func lines(_ data: Data) -> [Data] {
        var lines: [Data] = []
        var start = data.startIndex
        for index in data.indices where data[index] == 0x0A {
            lines.append(Data(data[start...index]))
            start = data.index(after: index)
        }
        if start < data.endIndex { lines.append(Data(data[start...])) }
        return lines
    }

    /// The line ending a line had, for a line written again: `\r\n`, `\n`, or none.
    static func ending(of line: Data) -> String {
        let raw = String(decoding: line, as: UTF8.self)
        return raw.hasSuffix("\r\n") ? "\r\n" : raw.hasSuffix("\n") ? "\n" : ""
    }

    /// One file of the manuscript as Unicode scalars, compared as they are written (`é` and `e`
    /// with a combining accent are different), its lines joined with line feeds, where each line
    /// starts, and which scalars are inside a `%` comment.
    struct ManuscriptFile {
        /// The name a `location` gives it: `main.tex` for the main file.
        let name: String
        let text: [Unicode.Scalar]
        let lineStarts: [Int]
        let commented: [Bool]

        init(name: String, content: String) {
            self.name = name
            text = Array(LatexLine.splitLines(content).joined(separator: "\n").unicodeScalars)
            var starts = [0]
            for (offset, scalar) in text.enumerated() where scalar == "\n" { starts.append(offset + 1) }
            lineStarts = starts
            var mask = [Bool](repeating: false, count: text.count)
            var backslashes = 0
            var inComment = false
            for (offset, scalar) in text.enumerated() {
                if scalar == "\n" { inComment = false; backslashes = 0; continue }
                if !inComment, scalar == "%", backslashes % 2 == 0 { inComment = true }
                mask[offset] = inComment
                backslashes = scalar == "\\" ? backslashes + 1 : 0
            }
            commented = mask
        }

        func line(of offset: Int) -> Int {
            var low = 0, high = lineStarts.count - 1
            while low < high {
                let mid = (low + high + 1) / 2
                if lineStarts[mid] <= offset { low = mid } else { high = mid - 1 }
            }
            return low + 1
        }

        /// `name:L<a>` or `name:L<a>-L<b>` for the scalars of `range`.
        func location(of range: Range<Int>) -> String {
            let start = line(of: range.lowerBound)
            let end = line(of: max(range.lowerBound, range.upperBound - 1))
            return end > start ? "\(name):L\(start)-L\(end)" : "\(name):L\(start)"
        }

        func string(_ range: Range<Int>) -> String {
            var view = String.UnicodeScalarView()
            view.append(contentsOf: text[range])
            return String(view)
        }
    }

    /// The files of the main file's input tree, the main file first.
    static func manuscript(main: URL) throws -> (files: [ManuscriptFile], notes: [String]) {
        let order: ReadingOrder
        do {
            order = try ReadingOrder(mainFile: main)
        } catch {
            throw Failure(message: CiteOrder.visible("\(error)"))
        }
        let directory = main.resolvingSymlinksInPath().standardizedFileURL.deletingLastPathComponent()
        var files: [ManuscriptFile] = []
        for (index, key) in order.files.enumerated() {
            let url = index == 0 ? main.resolvingSymlinksInPath() : directory.appendingPathComponent(key)
            guard let content = Audit.text(of: url) else { throw Failure(message: "cannot read \(CiteOrder.visible(key)) as UTF-8") }
            files.append(ManuscriptFile(name: index == 0 ? "main.tex" : key, content: content))
        }
        let notes = order.skippedImports.map {
            "[warn] non-standard import macro skipped at \(CiteOrder.visible($0)) (\\subimport/\\subfile/\\import unsupported)"
        }
        return (files, notes)
    }
}
