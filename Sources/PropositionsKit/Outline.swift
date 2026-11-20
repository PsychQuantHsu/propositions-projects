import Foundation

/// One line of an outline file that is not empty.
public struct OutlineLine: Sendable {
    /// The number of the line in the file, from 1.
    public let number: Int
    /// The JSON value of the line, or nil when the line is not written as JSON.
    public let value: JSONValue?
}

/// The three files of an outline, read line by line. Nothing here judges them.
public struct Outline: Sendable {
    public static let sectionFile = "outline-sections.jsonl"
    public static let paragraphFile = "outline-paragraphs.jsonl"
    public static let approvalFile = "outline-approvals.jsonl"

    public let sections: [OutlineLine]
    public let paragraphs: [OutlineLine]
    /// Nil when the directory has no approvals file: an outline that was never approved.
    public let approvals: [OutlineLine]?

    public enum ReadError: Error, CustomStringConvertible {
        case missing(String)
        public var description: String {
            switch self { case let .missing(name): return "cannot read \(name)" }
        }
    }

    public init(sections: String, paragraphs: String, approvals: String?) {
        self.sections = Outline.lines(of: sections)
        self.paragraphs = Outline.lines(of: paragraphs)
        self.approvals = approvals.map(Outline.lines(of:))
    }

    /// Reads the outline in `directory`. The section file and the paragraph file have to be
    /// there; the approvals file does not.
    public init(directory: URL) throws {
        func text(_ name: String) -> Data? {
            try? Data(contentsOf: directory.appendingPathComponent(name))
        }
        guard let sections = text(Outline.sectionFile) else { throw ReadError.missing(Outline.sectionFile) }
        guard let paragraphs = text(Outline.paragraphFile) else { throw ReadError.missing(Outline.paragraphFile) }
        // An approvals file that is there and cannot be read is not an outline that was never
        // approved: only a file that does not exist is.
        let approvals = text(Outline.approvalFile)
        let approvalPath = directory.appendingPathComponent(Outline.approvalFile).path
        if approvals == nil, (try? FileManager.default.attributesOfItem(atPath: approvalPath)) != nil {
            throw ReadError.missing(Outline.approvalFile)
        }
        self.sections = Outline.lines(of: sections)
        self.paragraphs = Outline.lines(of: paragraphs)
        self.approvals = approvals.map(Outline.lines(of:))
    }

    static func lines(of text: String) -> [OutlineLine] { lines(of: Data(text.utf8)) }

    /// The lines of a file that are not empty, each read as JSON. Lines end at a line feed
    /// byte, so a file with CRLF line ends reads the same (the carriage return is white space
    /// to JSON). A line that is not valid UTF-8 is not JSON.
    static func lines(of data: Data) -> [OutlineLine] {
        var result: [OutlineLine] = []
        for (offset, line) in data.split(separator: 0x0A, omittingEmptySubsequences: false).enumerated()
        where !line.isEmpty {
            let text = line.contains(0) ? nil : String(validatingUTF8: Array(line).map { CChar(bitPattern: $0) } + [0])
            result.append(OutlineLine(number: offset + 1, value: text.flatMap { try? JSONValue.parse($0) }))
        }
        return result
    }
}

/// The characters a locator's `file`, and the name of an outline directory, are not allowed to
/// hold: control characters, and the ones that break a line or turn the direction of text.
enum OutlineText {
    static func isClean(_ text: String) -> Bool {
        text.unicodeScalars.allSatisfy { scalar in
            let v = scalar.value
            return v >= 0x20 && !(0x7F...0x9F).contains(v) && !(0x2028...0x202E).contains(v)
                && !(0x2066...0x2069).contains(v)
        }
    }

    static func hasControl(_ text: String) -> Bool { text.unicodeScalars.contains { $0.value < 0x20 } }
}
