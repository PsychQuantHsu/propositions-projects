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

    /// The environment git is run with: the caller's, without the variables that make git answer
    /// for another repository than the one the directory is in.
    static var environment: [String: String] {
        var all = ProcessInfo.processInfo.environment
        for name in ["GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR", "GIT_NAMESPACE", "GIT_OBJECT_DIRECTORY", "GIT_PREFIX"] {
            all[name] = nil
        }
        return all
    }

    public static let git: Git = { directory, arguments in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-c", "safe.bareRepository=explicit", "-c", "core.fsmonitor=false", "-C", directory.path] + arguments
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Whether `root` is the top directory of a git work tree, as git reports it.
    public static func isWorkTreeRoot(_ root: URL) -> Bool {
        let process = Process(), pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-c", "safe.bareRepository=explicit", "-c", "core.fsmonitor=false", "-C", root.path, "rev-parse", "--show-toplevel"]
        process.environment = environment
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice
        do { try process.run() } catch { return false }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return false }
        var top = Array(data)
        if top.last == 0x0A { top.removeLast() }
        let reported = URL(fileURLWithPath: String(decoding: top, as: UTF8.self)).resolvingSymlinksInPath().path
        return Array(reported.utf8) == Array(root.resolvingSymlinksInPath().path.utf8)
    }

    public static func findings(paragraphs: [OutlineLine], root: URL, git: Git = OutlineLocators.git) -> [String] {
        var out: [String] = []
        let rootPath = root.resolvingSymlinksInPath().path
        var texts: [JSONKey: [UInt8]?] = [:]
        for line in paragraphs {
            guard let record = line.value, record.isObject else {
                out.append("line \(line.number): not a JSON object")
                continue
            }
            let owner = record["id"]?.string.map(JSONValue.quoted) ?? "line \(line.number)"
            var locators: [JSONValue] = []
            for key in ["from", "replaces"] where record.has(key) {
                if let list = record[key]?.array, !list.isEmpty { locators += list } else {
                    out.append("\(owner): \(key) is not a list of one or more locators")
                }
            }
            for point in record["points"]?.array ?? [] where point.isObject && point.has("basis") {
                if let list = point["basis"]?.array, !list.isEmpty {
                    locators += list.filter { !$0.has("outline") }
                } else {
                    out.append("\(owner): basis is not a list of one or more locators or references to another outline")
                }
            }
            for locator in locators {
                if let problem = OutlineCheck.locatorProblem(locator) {
                    out.append("\(owner): \(problem)")
                    continue
                }
                guard let file = locator["file"]?.string else { continue }
                let key = JSONKey(file)
                if texts[key] == nil { texts[key] = .some(readable(file, rootPath: rootPath, git: git)) }
                guard let stored = texts[key], let text = stored else {
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
        // Paths are compared byte by byte: Swift's own comparison takes two spellings of one
        // accented letter for the same text, and a file system can hold both.
        let rootBytes = Array((rootPath + "/").utf8), pathBytes = Array(path.utf8)
        guard pathBytes.count > rootBytes.count, Array(pathBytes[..<rootBytes.count]) == rootBytes else { return nil }
        let inside = "/" + String(decoding: pathBytes[rootBytes.count...], as: UTF8.self).lowercased() + "/"
        guard !inside.contains("/.git/") else { return nil }
        let type = (try? FileManager.default.attributesOfItem(atPath: path))?[.type] as? FileAttributeType
        guard type == .typeRegular else { return nil }
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
