import Foundation

/// A JSON value read strictly, for the outline files.
///
/// Foundation's JSON reading cannot be used for them: it drops a key that is written twice in
/// one object, and it turns every number into a `Double`, so that two long numbers that differ
/// compare as equal. Here an object keeps its members as written, and a number keeps its
/// decimal value.
public indirect enum JSONValue: Sendable {
    case null
    case bool(Bool)
    case number(JSONNumber)
    case string(String)
    case array([JSONValue])
    case object([JSONMember])
}

public struct JSONMember: Sendable {
    public let key: String
    public let value: JSONValue
}

/// A number as its decimal value: `digits` × 10^`exponent`, with no zero at either end of
/// `digits`. Zero has no digits. `1`, `1.0` and `10e-1` are the same number; two numbers that
/// differ are different however long they are.
public struct JSONNumber: Hashable, Sendable {
    public let negative: Bool
    public let digits: String
    public let exponent: Int

    init(negative: Bool, integer: Substring, fraction: Substring, exponent written: Int) {
        var all = Array(integer + fraction)
        var power = written - fraction.count
        while all.last == "0" { all.removeLast(); power += 1 }
        let significant = String(all.drop { $0 == "0" })
        digits = significant
        exponent = significant.isEmpty ? 0 : power
        self.negative = significant.isEmpty ? false : negative
    }

    /// Whether `jq`, which keeps a number as a double, reads this one as infinite (`1e400`).
    public var isBeyondDouble: Bool {
        guard !digits.isEmpty else { return false }
        let order = digits.count + exponent
        if order > 309 { return true }
        if order < 308 { return false }
        return Double("0.\(digits)e\(order)")?.isInfinite ?? true
    }
}

public struct JSONError: Error, CustomStringConvertible, Sendable {
    public let description: String
}

extension JSONValue: Equatable {
    /// Two values are equal when they are the same JSON value: the order of the keys of an
    /// object does not count, and numbers compare by value. When a key is written twice in
    /// one object the later member counts, as `jq` reads it.
    public static func == (lhs: JSONValue, rhs: JSONValue) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null): return true
        case let (.bool(a), .bool(b)): return a == b
        case let (.number(a), .number(b)): return a == b
        case let (.string(a), .string(b)): return a.unicodeScalars.elementsEqual(b.unicodeScalars)
        case let (.array(a), .array(b)): return a == b
        case (.object, .object):
            let a = lhs.dictionary, b = rhs.dictionary
            return a.count == b.count && a.allSatisfy { b[$0.key] == $0.value }
        default: return false
        }
    }
}

extension JSONValue {
    /// The members of an object by key, the later of two members with one key.
    var dictionary: [JSONKey: JSONValue] {
        guard case let .object(members) = self else { return [:] }
        var result: [JSONKey: JSONValue] = [:]
        for member in members { result[JSONKey(member.key)] = member.value }
        return result
    }

    public var members: [JSONMember]? { if case let .object(m) = self { return m } else { return nil } }
    public var isObject: Bool { members != nil }
    public var string: String? { if case let .string(s) = self { return s } else { return nil } }
    public var array: [JSONValue]? { if case let .array(a) = self { return a } else { return nil } }

    /// The value of `key` in an object, the later one when the key is written twice.
    public subscript(key: String) -> JSONValue? {
        guard case let .object(members) = self else { return nil }
        return members.last { JSONKey($0.key) == JSONKey(key) }?.value
    }

    public func has(_ key: String) -> Bool { self[key] != nil }

    /// A string that is not empty, or nil.
    public var nonEmptyString: String? {
        guard let s = string, !s.unicodeScalars.isEmpty else { return nil }
        return s
    }

    /// Every value inside this one, itself included.
    func walk(_ visit: (JSONValue) -> Void) {
        visit(self)
        switch self {
        case let .array(items): items.forEach { $0.walk(visit) }
        case let .object(members): members.forEach { $0.value.walk(visit) }
        default: break
        }
    }

    /// A string written as JSON, the way a message quotes an id or a name: control characters
    /// are escaped, so that text from a file cannot break a line of output.
    public static func quoted(_ text: String) -> String {
        var out = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\t": out += "\\t"
            case "\r": out += "\\r"
            default:
                let v = scalar.value
                if v < 0x20 || (0x7F...0x9F).contains(v) || (0x2028...0x202E).contains(v) || (0x2066...0x2069).contains(v) {
                    out += "\\u" + String(v, radix: 16).leftPadded(to: 4)
                } else {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out + "\""
    }
}

/// A key compared scalar by scalar: Swift's own string comparison treats two spellings of
/// one accented letter as equal, and JSON does not.
struct JSONKey: Hashable {
    let scalars: [UInt32]
    init(_ text: String) { scalars = text.unicodeScalars.map(\.value) }
}

extension String {
    fileprivate func leftPadded(to width: Int) -> String {
        String(repeating: "0", count: max(0, width - count)) + self
    }
}

extension JSONValue {
    /// Reads one JSON value from `text`, which holds nothing else but white space.
    ///
    /// Strict: outside its strings the text holds only `true`, `false`, `null` and numbers
    /// written as JSON writes them, so `nan`, `Infinity`, `01` and `.5` are refused, and so is
    /// a byte-order mark. A byte that is not UTF-8 is read as U+FFFD.
    public static func parse(_ text: String) throws -> JSONValue {
        var parser = Parser(bytes: Array(text.utf8))
        parser.skipSpace()
        let value = try parser.value(depth: 0)
        parser.skipSpace()
        guard parser.index == parser.bytes.count else { throw JSONError(description: "text after the value") }
        return value
    }
}

private struct Parser {
    let bytes: [UInt8]
    var index = 0

    var peek: UInt8? { index < bytes.count ? bytes[index] : nil }

    mutating func skipSpace() {
        while let b = peek, b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D { index += 1 }
    }

    mutating func value(depth: Int) throws -> JSONValue {
        guard depth < 512 else { throw JSONError(description: "nested too deep") }
        guard let b = peek else { throw JSONError(description: "no value") }
        switch b {
        case UInt8(ascii: "{"): return try object(depth: depth)
        case UInt8(ascii: "["): return try array(depth: depth)
        case UInt8(ascii: "\""): return .string(try string())
        case UInt8(ascii: "t"): try word("true"); return .bool(true)
        case UInt8(ascii: "f"): try word("false"); return .bool(false)
        case UInt8(ascii: "n"): try word("null"); return .null
        default: return .number(try number())
        }
    }

    mutating func word(_ text: String) throws {
        let wanted = Array(text.utf8)
        guard index + wanted.count <= bytes.count, Array(bytes[index..<index + wanted.count]) == wanted else {
            throw JSONError(description: "a value is not written as JSON")
        }
        index += wanted.count
    }

    mutating func object(depth: Int) throws -> JSONValue {
        index += 1
        var members: [JSONMember] = []
        skipSpace()
        if peek == UInt8(ascii: "}") { index += 1; return .object(members) }
        while true {
            skipSpace()
            guard peek == UInt8(ascii: "\"") else { throw JSONError(description: "a key is not a string") }
            let key = try string()
            skipSpace()
            guard peek == UInt8(ascii: ":") else { throw JSONError(description: "no colon after a key") }
            index += 1
            skipSpace()
            members.append(JSONMember(key: key, value: try value(depth: depth + 1)))
            skipSpace()
            if peek == UInt8(ascii: ",") { index += 1; continue }
            if peek == UInt8(ascii: "}") { index += 1; return .object(members) }
            throw JSONError(description: "an object is not closed")
        }
    }

    mutating func array(depth: Int) throws -> JSONValue {
        index += 1
        var items: [JSONValue] = []
        skipSpace()
        if peek == UInt8(ascii: "]") { index += 1; return .array(items) }
        while true {
            skipSpace()
            items.append(try value(depth: depth + 1))
            skipSpace()
            if peek == UInt8(ascii: ",") { index += 1; continue }
            if peek == UInt8(ascii: "]") { index += 1; return .array(items) }
            throw JSONError(description: "a list is not closed")
        }
    }

    mutating func string() throws -> String {
        index += 1
        var out: [UInt8] = []
        while true {
            guard let b = peek else { throw JSONError(description: "a string is not closed") }
            index += 1
            if b == UInt8(ascii: "\"") { return String(decoding: out, as: UTF8.self) }
            if b < 0x20 { throw JSONError(description: "a control character inside a string is not escaped") }
            if b != UInt8(ascii: "\\") { out.append(b); continue }
            guard let e = peek else { throw JSONError(description: "a string is not closed") }
            index += 1
            switch e {
            case UInt8(ascii: "\""), UInt8(ascii: "\\"), UInt8(ascii: "/"): out.append(e)
            case UInt8(ascii: "b"): out.append(0x08)
            case UInt8(ascii: "f"): out.append(0x0C)
            case UInt8(ascii: "n"): out.append(0x0A)
            case UInt8(ascii: "r"): out.append(0x0D)
            case UInt8(ascii: "t"): out.append(0x09)
            case UInt8(ascii: "u"):
                var unit = try hex4()
                var scalar: Unicode.Scalar? = nil
                if (0xD800...0xDBFF).contains(unit) {
                    // A high surrogate counts only with the low one that follows it.
                    let saved = index
                    if peek == UInt8(ascii: "\\"), index + 1 < bytes.count, bytes[index + 1] == UInt8(ascii: "u") {
                        index += 2
                        let low = try hex4()
                        if (0xDC00...0xDFFF).contains(low) {
                            unit = 0x10000 + ((unit - 0xD800) << 10) + (low - 0xDC00)
                            scalar = Unicode.Scalar(unit)
                        } else {
                            index = saved
                        }
                    }
                } else {
                    scalar = Unicode.Scalar(unit)
                }
                out.append(contentsOf: Array(String(Character(scalar ?? "\u{FFFD}")).utf8))
            default: throw JSONError(description: "an escape inside a string is not one JSON has")
            }
        }
    }

    mutating func hex4() throws -> UInt32 {
        guard index + 4 <= bytes.count,
              let unit = UInt32(String(decoding: bytes[index..<index + 4], as: UTF8.self), radix: 16),
              bytes[index..<index + 4].allSatisfy({ $0 != UInt8(ascii: "+") && $0 != UInt8(ascii: "-") }) else {
            throw JSONError(description: "an escape inside a string is not one JSON has")
        }
        index += 4
        return unit
    }

    mutating func digits() -> Substring {
        let start = index
        while let b = peek, b >= UInt8(ascii: "0"), b <= UInt8(ascii: "9") { index += 1 }
        return Substring(String(decoding: bytes[start..<index], as: UTF8.self))
    }

    mutating func number() throws -> JSONNumber {
        let failure = JSONError(description: "a value is not written as JSON")
        var negative = false
        if peek == UInt8(ascii: "-") { negative = true; index += 1 }
        let integer = digits()
        guard !integer.isEmpty, integer == "0" || integer.first != "0" else { throw failure }
        var fraction: Substring = ""
        if peek == UInt8(ascii: ".") {
            index += 1
            fraction = digits()
            guard !fraction.isEmpty else { throw failure }
        }
        var exponent = 0
        if peek == UInt8(ascii: "e") || peek == UInt8(ascii: "E") {
            index += 1
            var sign = 1
            if peek == UInt8(ascii: "+") { index += 1 } else if peek == UInt8(ascii: "-") { sign = -1; index += 1 }
            let written = digits()
            guard !written.isEmpty else { throw failure }
            // The exponent is kept exactly, so that two numbers that differ stay different.
            // One too long to keep is refused: no outline needs it.
            guard written.count <= 15, let size = Int(written) else {
                throw JSONError(description: "a number has an exponent too long to keep")
            }
            exponent = sign * size
        }
        return JSONNumber(negative: negative, integer: integer, fraction: fraction, exponent: exponent)
    }
}
