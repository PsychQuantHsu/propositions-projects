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

    public var banned: [Banned] = []

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
