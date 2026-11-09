import Foundation

/// What a `granite://` URL asks for.
public enum GraniteAction: Sendable, Hashable {
    /// `granite://capture?text=…`: save immediately.
    case capture(CaptureRequest)
    /// `granite://capture` without text: show the capture panel.
    case showCapturePanel
    /// `granite://open?path=…` or `?id=…`.
    case open(path: String?, id: String?)
    /// `granite://pdf?path=Papers/pdf/x.pdf&page=3&block=p3-ab12cd`: the PDF view at a page,
    /// with that highlight marked.
    case pdf(path: String, page: Int, block: String?)
    /// `granite://clip?url=https://…[&why=…]`: clip that page into Clippings/ (works as a bookmarklet).
    case clip(url: URL, why: String?)
}

public enum GraniteURLError: Error, Equatable, CustomStringConvertible {
    case wrongScheme
    case unknownAction(String)
    case invalid(String)

    public var description: String {
        switch self {
        case .wrongScheme: "not a granite:// URL"
        case .unknownAction(let action): "unknown granite:// action \(action)"
        case .invalid(let reason): "invalid granite:// URL: \(reason)"
        }
    }
}

/// Parses `granite://` URLs. They can come from any app or web page, so everything is validated:
/// capture only ever creates a new Inbox note, and open only accepts vault-relative paths.
public enum GraniteURL {
    public static let scheme = "granite"
    static let maxText = 100_000
    static let maxWhy = 1_000
    static let maxTitle = 300

    public static func parse(_ url: URL) throws -> GraniteAction {
        guard url.scheme?.lowercased() == scheme,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw GraniteURLError.wrongScheme
        }
        let action = (components.host ?? components.path.split(separator: "/").first.map(String.init) ?? "").lowercased()
        var query: [String: String] = [:]
        for item in components.queryItems ?? [] where query[item.name] == nil {
            query[item.name] = item.value ?? ""
        }

        switch action {
        case "capture":
            let text = query["text"] ?? ""
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .showCapturePanel }
            guard text.count <= maxText else { throw GraniteURLError.invalid("text longer than \(maxText) characters") }
            var link: URL?
            if let raw = query["url"], !raw.isEmpty {
                guard let parsed = URL(string: raw), ["http", "https"].contains(parsed.scheme?.lowercased() ?? "") else {
                    throw GraniteURLError.invalid("url must be http or https")
                }
                link = parsed
            }
            let why = query["why"].map { String($0.prefix(maxWhy)) }
            let title = query["title"].map { String($0.prefix(maxTitle)) }
            return .capture(CaptureRequest(text: text, url: link, title: title, why: why))
        case "open":
            if let id = query["id"], !id.isEmpty { return .open(path: nil, id: id) }
            guard let path = query["path"], !path.isEmpty else { throw GraniteURLError.invalid("open needs path or id") }
            let parts = path.split(separator: "/")
            guard !path.hasPrefix("/"), !parts.contains(".."), !parts.contains(where: { $0.hasPrefix(".") }) else {
                throw GraniteURLError.invalid("path must be inside the vault")
            }
            return .open(path: path, id: nil)
        case "clip":
            guard let raw = query["url"], let page = URL(string: raw), ["http", "https"].contains(page.scheme?.lowercased() ?? "") else {
                throw GraniteURLError.invalid("clip needs an http or https url")
            }
            return .clip(url: page, why: query["why"].map { String($0.prefix(maxWhy)) })
        case "pdf":
            guard let path = query["path"], path.lowercased().hasSuffix(".pdf") else { throw GraniteURLError.invalid("pdf needs a .pdf path") }
            let parts = path.split(separator: "/")
            guard !path.hasPrefix("/"), !parts.contains(".."), !parts.contains(where: { $0.hasPrefix(".") }) else {
                throw GraniteURLError.invalid("path must be inside the vault")
            }
            let page = max(1, Int(query["page"] ?? "") ?? 1)
            let block = query["block"].flatMap { $0.range(of: #"^[A-Za-z0-9-]{1,64}$"#, options: .regularExpression) != nil ? $0 : nil }
            return .pdf(path: path, page: page, block: block)
        default:
            throw GraniteURLError.unknownAction(action)
        }
    }
}
