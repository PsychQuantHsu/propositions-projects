import Foundation

/// Whether every locator of a paragraph file names exactly one place.
///
/// A locator's file is a regular file inside the repository, outside every `.git` directory,
/// that git lists: git tracks it, or does not track it and does not ignore it. Two
/// repositories are asked, the one that holds the file (asked in the file's directory) and the
/// repository at the root (asked whether it ignores the path). The file is then read, and the
/// label and the opening words are counted with every run of spaces, tabs and line breaks as
/// one space, from every position, so that two occurrences that overlap count as two.
public enum OutlineLocators {
    /// Runs git and gives its exit status, or nil when git could not be started.
    public typealias Git = @Sendable (_ directory: URL, _ arguments: [String]) -> Int32?

    public static let git: Git = { directory, arguments in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-c", "safe.bareRepository=explicit", "-c", "core.fsmonitor=false", "-C", directory.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        return process.terminationStatus
    }

    public static func findings(paragraphs: [OutlineLine], root: URL, git: Git = OutlineLocators.git) -> [String] {
        var out: [String] = []
        let rootPath = root.resolvingSymlinksInPath().path
        var texts: [String: [UInt8]?] = [:]
        for line in paragraphs {
            guard let record = line.value, record.isObject else { continue }
            let owner = record["id"]?.string.map(JSONValue.quoted) ?? "line \(line.number)"
            var locators: [JSONValue] = []
            for key in ["from", "replaces"] { locators += record[key]?.array ?? [] }
            for point in record["points"]?.array ?? [] where point.isObject {
                locators += (point["basis"]?.array ?? []).filter { !$0.has("outline") }
            }
            for locator in locators {
                if let problem = OutlineCheck.locatorProblem(locator) {
                    out.append("\(owner): \(problem)")
                    continue
                }
                guard let file = locator["file"]?.string else { continue }
                if texts[file] == nil { texts[file] = .some(readable(file, rootPath: rootPath, git: git)) }
                guard let stored = texts[file], let text = stored else {
                    out.append("\(owner): \(JSONValue.quoted(file)) is not a file of the repository that git lists")
                    continue
                }
                if let starts = locator["starts"]?.string {
                    let wanted = squeezed(Array(starts.utf8), trim: true)
                    let count = wanted.isEmpty ? 0 : occurrences(of: wanted, in: text)
                    if count != 1 { out.append("\(owner): starts occurs \(count) times, not once") }
                }
                if let label = locator["label"]?.string {
                    let wanted = Array("\\label{".utf8) + squeezed(Array(label.utf8), trim: false) + Array("}".utf8)
                    let count = occurrences(of: wanted, in: text)
                    if count != 1 {
                        out.append("\(owner): the label \(JSONValue.quoted(label)) occurs \(count) times as \\label{…}, not once")
                    }
                }
            }
        }
        return out
    }

    /// The text of a locator's file with every run of white space as one space, or nil when
    /// the file is not one a locator can name.
    static func readable(_ file: String, rootPath: String, git: Git) -> [UInt8]? {
        guard !file.hasPrefix("/") else { return nil }
        let real = URL(fileURLWithPath: rootPath).appendingPathComponent(file).resolvingSymlinksInPath()
        let path = real.path
        guard path.hasPrefix(rootPath + "/") else { return nil }
        let inside = path.dropFirst(rootPath.count).lowercased()
        guard !(inside + "/").contains("/.git/") else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { return nil }
        let directory = real.deletingLastPathComponent()
        guard git(directory, ["--literal-pathspecs", "ls-files", "--cached", "--others", "--exclude-standard", "--error-unmatch", "--", path]) == 0 else {
            return nil
        }
        // The repository at the root: when it ignores the path, the file is not read whatever
        // the first answer was. Any other answer, an error included, leaves the first to stand.
        if git(URL(fileURLWithPath: rootPath), ["check-ignore", "-q", "--", path]) == 0 { return nil }
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        return squeezed(Array(data), trim: false)
    }

    /// Every run of spaces, tabs, carriage returns and line feeds as one space.
    static func squeezed(_ bytes: [UInt8], trim: Bool) -> [UInt8] {
        var out: [UInt8] = []
        out.reserveCapacity(bytes.count)
        for b in bytes {
            if b == 0x20 || b == 0x09 || b == 0x0A || b == 0x0D {
                if out.last != 0x20 { out.append(0x20) }
            } else {
                out.append(b)
            }
        }
        if trim {
            if out.first == 0x20 { out.removeFirst() }
            if out.last == 0x20 { out.removeLast() }
        }
        return out
    }

    /// How often `needle` occurs in `text`, counted from every position.
    static func occurrences(of needle: [UInt8], in text: [UInt8]) -> Int {
        guard !needle.isEmpty, needle.count <= text.count else { return 0 }
        var count = 0
        let first = needle[0]
        text.withUnsafeBufferPointer { haystack in
            needle.withUnsafeBufferPointer { wanted in
                var i = 0
                let last = haystack.count - wanted.count
                while i <= last {
                    if haystack[i] == first, memcmp(haystack.baseAddress! + i, wanted.baseAddress!, wanted.count) == 0 {
                        count += 1
                    }
                    i += 1
                }
            }
        }
        return count
    }
}
