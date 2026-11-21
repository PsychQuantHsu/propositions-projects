import Foundation

/// `article.json`: what is true of the whole article, kept beside the ledger or in the outline
/// directory. Every key is optional, and a key this type does not know is left alone.
public struct Article: Equatable, Sendable {
    public static let fileName = "article.json"

    /// A phrasing that is not to appear in the article, and why (issue 118).
    public struct Banned: Equatable, Sendable {
        public let phrase: String
        public let reason: String
    }

    public struct Failure: Error, Equatable {
        public let message: String
    }

    /// The limit on the article's length, in words, and the parts it counts (issue 119).
    public struct Length: Equatable, Sendable {
        public let limit: Int
        public let parts: [String]
    }

    /// The document a part of the article is written into (issue 120): its main file and its
    /// ledger, as paths from the directory of `article.json`.
    public struct Destination: Equatable, Sendable {
        public let tex: String
        public let jsonl: String
    }

    public var banned: [Banned] = []
    public var length: Length?
    /// By part; nil when the file has no `destinations`.
    public var destinations: [String: Destination]?

    /// The parts whose destination is the main file `tex` with the ledger `jsonl`, in the order
    /// main, appendix, supplement. Paths are compared after links are resolved.
    func parts(tex: URL, jsonl: URL, directory: URL) -> [String] {
        ["main", "appendix", "supplement"].filter { part in
            guard let destination = destinations?[part] else { return false }
            return Article.real(Article.resolve(destination.tex, directory)) == Article.real(tex)
                && Article.real(Article.resolve(destination.jsonl, directory)) == Article.real(jsonl)
        }
    }

    /// The path is not tidied: `link/../x` is left for the file system, which follows the link first.
    static func resolve(_ path: String, _ directory: URL) -> URL { URL(fileURLWithPath: directory.path + "/" + path) }

    /// The name the file system gives the file (links followed in the order of the path); the
    /// tidied path when the file is not there.
    static func real(_ url: URL) -> String {
        guard let pointer = realpath(url.path, nil) else { return WriteParagraph.canonical(url) }
        defer { free(pointer) }
        return String(cString: pointer)
    }

    /// Reads the file's bytes; throws with what is wrong, named from `article.json`.
    public static func parse(_ data: Data) throws -> Article {
        func fail(_ message: String) -> Failure { Failure(message: "\(fileName): \(message)") }
        guard let text = String(data: data, encoding: .utf8), let value = try? JSONValue.parse(text), value.isObject else {
            throw fail("not a JSON object")
        }
        var article = Article()
        if let banned = value["banned"] {
            guard let items = banned.array else { throw fail("banned is not a list") }
            for (index, item) in items.enumerated() {
                guard item.isObject, let phrase = item["phrase"]?.nonEmptyString, let reason = item["reason"]?.nonEmptyString else {
                    throw fail("banned entry \(index + 1) is not an object with a phrase and a reason that are non-empty strings")
                }
                guard !Phrasing.fold(phrase).isEmpty, !OutlineText.hasControl(phrase) else {
                    throw fail("the phrase of banned entry \(index + 1) is only white space, or holds a control character")
                }
                article.banned.append(Banned(phrase: phrase, reason: reason))
            }
        }
        if let destinations = value["destinations"] {
            guard destinations.isObject else { throw fail("destinations is not an object") }
            var table: [String: Destination] = [:]
            for member in destinations.members ?? [] {
                let key = member.key, item = member.value
                func path(_ name: String) -> String? {
                    guard let text = item[name]?.nonEmptyString, !text.hasPrefix("/"), OutlineText.isClean(text) else { return nil }
                    return text
                }
                guard OutlineCheck.parts.contains(key), table[key] == nil, item.isObject, let tex = path("tex"), let jsonl = path("jsonl") else {
                    throw fail("destinations is not an object whose keys are main, appendix or supplement, each once and with a tex and a jsonl that are paths from the directory of \(fileName)")
                }
                table[key] = Destination(tex: tex, jsonl: jsonl)
            }
            guard !table.isEmpty else { throw fail("destinations names no part") }
            article.destinations = table
        }
        if let length = value["length"] {
            guard length.isObject, let limit = OutlineLength.count(length["limit"]) else {
                throw fail("length is not an object with a limit that is a whole number from 1 to 999999999")
            }
            var parts = ["main"]
            if length.has("parts") {
                guard let list = length["parts"]?.array, !list.isEmpty, let names = Optional(list.compactMap(\.string)), names.count == list.count,
                      names.allSatisfy(OutlineCheck.parts.contains), Set(names).count == names.count else {
                    throw fail("the parts of length is not a list of one or more of main, appendix, supplement, each once")
                }
                parts = names
            }
            article.length = Length(limit: limit, parts: parts)
        }
        return article
    }

    /// The article file of `directory`: nil when nothing is there; throws when it is not a
    /// regular file that can be read, or is not in the format.
    static func read(in directory: URL) throws -> (article: Article, data: Data, url: URL)? {
        let url = directory.appendingPathComponent(fileName)
        if try WriteFromOutline.absent(url) { return nil }
        let data = try WriteFromOutline.regular(url).data
        do { return (try parse(data), data, url) } catch let failure as Failure { throw WriteParagraph.Failure(message: failure.message) }
    }
}
