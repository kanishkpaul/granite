import Foundation
import KBCore

/// Bibliographic data from public scholarly APIs, merged.
public struct PaperRecord: Sendable, Equatable {
    public var title: String?
    public var authors: [String] = []
    public var year: Int?
    public var venue: String?
    public var doi: String?
    public var abstract: String?
    /// Semantic Scholar's one-sentence summary.
    public var tldr: String?
    public var openAlexID: String?
    public var citedBy: Int?
    public var referenceCount: Int?
    /// OpenAlex work ids this paper cites (for literature-graph expansion).
    public var references: [String] = []

    public init() {}
}

public enum EnrichmentError: Error, Equatable, CustomStringConvertible {
    case noIdentifier
    case notFound
    case http(Int)

    public var description: String {
        switch self {
        case .noIdentifier: "the note has no DOI or title to look up"
        case .notFound: "no scholarly record found"
        case .http(let status): "the lookup failed (HTTP \(status))"
        }
    }
}

/// Crossref, OpenAlex and Semantic Scholar lookups, on request only (master plan §8 phase 3).
/// One request per service per paper. No account, no key, and no email address is sent.
public struct ScholarlyClient: Sendable {
    public static let userAgent = "granite/0.1 (personal knowledge base; macOS)"
    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    func json(_ url: URL) async throws -> [String: Any]? {
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 404 { return nil }
        guard (200..<300).contains(status) else { throw EnrichmentError.http(status) }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func escape(_ text: String) -> String {
        text.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "?&#"))) ?? text
    }

    public func crossref(doi: String) async throws -> PaperRecord? {
        guard let url = URL(string: "https://api.crossref.org/works/\(Self.escape(doi))"),
              let message = try await json(url)?["message"] as? [String: Any] else { return nil }
        var record = PaperRecord()
        record.doi = (message["DOI"] as? String)?.lowercased()
        record.title = (message["title"] as? [String])?.first
        record.authors = (message["author"] as? [[String: Any]] ?? []).compactMap { author in
            let name = [author["given"] as? String, author["family"] as? String].compactMap { $0 }.joined(separator: " ")
            return name.isEmpty ? author["name"] as? String : name
        }
        let parts = ((message["issued"] as? [String: Any])?["date-parts"] as? [[Int]])?.first
        record.year = parts?.first
        record.venue = (message["container-title"] as? [String])?.first
        record.abstract = (message["abstract"] as? String).map(Self.stripJATS)
        record.referenceCount = message["reference-count"] as? Int
        record.citedBy = message["is-referenced-by-count"] as? Int
        return record
    }

    public func openAlex(doi: String) async throws -> PaperRecord? {
        guard let url = URL(string: "https://api.openalex.org/works/https://doi.org/\(Self.escape(doi))") else { return nil }
        return try await json(url).map(Self.openAlexRecord)
    }

    public func openAlex(title: String) async throws -> PaperRecord? {
        var components = URLComponents(string: "https://api.openalex.org/works")
        components?.queryItems = [URLQueryItem(name: "search", value: title), URLQueryItem(name: "per-page", value: "1")]
        guard let url = components?.url, let first = (try await json(url)?["results"] as? [[String: Any]])?.first else { return nil }
        return Self.openAlexRecord(first)
    }

    /// Works citing an OpenAlex work, most cited first.
    public func openAlexCitedBy(_ id: String, limit: Int = 25) async throws -> [PaperRecord] {
        var components = URLComponents(string: "https://api.openalex.org/works")
        components?.queryItems = [URLQueryItem(name: "filter", value: "cites:\(Self.shortID(id))"),
                                  URLQueryItem(name: "sort", value: "cited_by_count:desc"),
                                  URLQueryItem(name: "per-page", value: String(limit))]
        guard let url = components?.url else { return [] }
        return (try await json(url)?["results"] as? [[String: Any]] ?? []).map(Self.openAlexRecord)
    }

    /// Several OpenAlex works by id, in one request.
    public func openAlexWorks(_ ids: [String]) async throws -> [PaperRecord] {
        guard !ids.isEmpty else { return [] }
        var components = URLComponents(string: "https://api.openalex.org/works")
        components?.queryItems = [URLQueryItem(name: "filter", value: "openalex:" + ids.prefix(50).map(Self.shortID).joined(separator: "|")),
                                  URLQueryItem(name: "per-page", value: "50")]
        guard let url = components?.url else { return [] }
        return (try await json(url)?["results"] as? [[String: Any]] ?? []).map(Self.openAlexRecord)
    }

    public func semanticScholar(doi: String) async throws -> PaperRecord? {
        guard let url = URL(string: "https://api.semanticscholar.org/graph/v1/paper/DOI:\(Self.escape(doi))?fields=title,year,citationCount,tldr"),
              let paper = try await json(url) else { return nil }
        var record = PaperRecord()
        record.title = paper["title"] as? String
        record.year = paper["year"] as? Int
        record.citedBy = paper["citationCount"] as? Int
        record.tldr = (paper["tldr"] as? [String: Any])?["text"] as? String
        return record
    }

    /// All three, by DOI when there is one, else OpenAlex by title. Failures of one service don't stop the others.
    public func lookup(doi: String?, title: String?) async throws -> PaperRecord {
        var fromOpenAlex: PaperRecord?
        var fromCrossref: PaperRecord?
        var fromS2: PaperRecord?
        if let doi, !doi.isEmpty {
            async let c = try? crossref(doi: doi)
            async let o = try? openAlex(doi: doi)
            async let s = try? semanticScholar(doi: doi)
            (fromCrossref, fromOpenAlex, fromS2) = await (c ?? nil, o ?? nil, s ?? nil)
        } else if let title, title.count > 8 {
            fromOpenAlex = try await openAlex(title: title)
        } else {
            throw EnrichmentError.noIdentifier
        }
        guard fromCrossref != nil || fromOpenAlex != nil || fromS2 != nil else { throw EnrichmentError.notFound }
        return Self.merge(crossref: fromCrossref, openAlex: fromOpenAlex, semanticScholar: fromS2)
    }

    /// Crossref for bibliography, OpenAlex for ids, references and abstracts, Semantic Scholar for the TL;DR.
    public static func merge(crossref: PaperRecord?, openAlex: PaperRecord?, semanticScholar: PaperRecord?) -> PaperRecord {
        var record = PaperRecord()
        record.title = crossref?.title ?? openAlex?.title ?? semanticScholar?.title
        record.authors = (crossref?.authors.isEmpty == false ? crossref?.authors : openAlex?.authors) ?? []
        record.year = crossref?.year ?? openAlex?.year ?? semanticScholar?.year
        record.venue = crossref?.venue ?? openAlex?.venue
        record.doi = crossref?.doi ?? openAlex?.doi
        record.abstract = openAlex?.abstract ?? crossref?.abstract
        record.tldr = semanticScholar?.tldr
        record.openAlexID = openAlex?.openAlexID
        record.citedBy = [crossref?.citedBy, openAlex?.citedBy, semanticScholar?.citedBy].compactMap { $0 }.max()
        record.referenceCount = crossref?.referenceCount ?? (openAlex.map { $0.references.count })
        record.references = openAlex?.references ?? []
        return record
    }

    static func openAlexRecord(_ work: [String: Any]) -> PaperRecord {
        var record = PaperRecord()
        record.openAlexID = (work["id"] as? String).map(shortID)
        record.title = work["title"] as? String ?? work["display_name"] as? String
        record.year = work["publication_year"] as? Int
        record.doi = (work["doi"] as? String)?.replacingOccurrences(of: "https://doi.org/", with: "").lowercased()
        record.authors = (work["authorships"] as? [[String: Any]] ?? []).compactMap { ($0["author"] as? [String: Any])?["display_name"] as? String }
        record.venue = ((work["primary_location"] as? [String: Any])?["source"] as? [String: Any])?["display_name"] as? String
        record.citedBy = work["cited_by_count"] as? Int
        record.references = (work["referenced_works"] as? [String] ?? []).map(shortID)
        record.abstract = (work["abstract_inverted_index"] as? [String: [Int]]).map(abstract(fromInvertedIndex:))
        return record
    }

    /// OpenAlex ships abstracts as word → positions.
    static func abstract(fromInvertedIndex index: [String: [Int]]) -> String {
        var words: [Int: String] = [:]
        for (word, positions) in index { for position in positions { words[position] = word } }
        return words.keys.sorted().compactMap { words[$0] }.joined(separator: " ")
    }

    static func shortID(_ id: String) -> String {
        id.replacingOccurrences(of: "https://openalex.org/", with: "")
    }

    /// Crossref abstracts are JATS XML.
    static func stripJATS(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
            .replacingOccurrences(of: #"^Abstract\s+"#, with: "", options: .regularExpression)
    }
}

/// Writes looked-up data into a literature note: frontmatter fields, and an `granite:enrich`
/// managed region (abstract, TL;DR, counts). Your take and highlights are untouched.
public enum EnrichmentWriter {
    public static let begin = "<!-- granite:enrich:begin (looked up from Crossref, OpenAlex and Semantic Scholar; replaced on refresh) -->"
    public static let end = "<!-- granite:enrich:end -->"

    public static func apply(_ record: PaperRecord, to text: String, date: String) throws -> String {
        var output = text
        if let title = record.title { output = try FrontmatterEditor.setScalar("title", to: title, in: output) }
        if !record.authors.isEmpty { output = try FrontmatterEditor.setRaw("authors", yaml: FrontmatterEditor.yamlList(record.authors), in: output) }
        if let year = record.year { output = try FrontmatterEditor.setRaw("year", yaml: String(year), in: output) }
        if let doi = record.doi { output = try FrontmatterEditor.setScalar("doi", to: doi, in: output) }
        if let venue = record.venue { output = try FrontmatterEditor.setScalar("venue", to: venue, in: output) }
        if let id = record.openAlexID { output = try FrontmatterEditor.setScalar("openalex", to: id, in: output) }
        if let citedBy = record.citedBy { output = try FrontmatterEditor.setRaw("cited_by", yaml: String(citedBy), in: output) }
        output = try FrontmatterEditor.setScalar("enriched", to: date, in: output)

        var region = [begin, "## About this paper"]
        if let tldr = record.tldr { region += ["", "TL;DR (Semantic Scholar): \(tldr)"] }
        if let abstract = record.abstract { region += ["", "> " + abstract.replacingOccurrences(of: "\n", with: " ")] }
        var facts: [String] = []
        if let venue = record.venue { facts.append(venue) }
        if let citedBy = record.citedBy { facts.append("cited by \(citedBy)") }
        if let references = record.referenceCount { facts.append("\(references) references") }
        if let doi = record.doi { facts.append("[doi:\(doi)](https://doi.org/\(doi))") }
        if let id = record.openAlexID { facts.append("[OpenAlex](https://openalex.org/\(id))") }
        if !facts.isEmpty { region += ["", facts.joined(separator: " · ")] }
        region.append(end)
        let block = region.joined(separator: "\n")
        if let start = output.range(of: begin), let finish = output.range(of: end, range: start.upperBound..<output.endIndex) {
            return output.replacingCharacters(in: start.lowerBound..<finish.upperBound, with: block)
        }
        // Before "## My take" when there is one, so the paper's facts come first.
        if let take = output.range(of: "\n## My take") {
            return output.replacingCharacters(in: take.lowerBound..<take.lowerBound, with: "\n" + block + "\n")
        }
        if !output.hasSuffix("\n") { output += "\n" }
        return output + "\n" + block + "\n"
    }
}
