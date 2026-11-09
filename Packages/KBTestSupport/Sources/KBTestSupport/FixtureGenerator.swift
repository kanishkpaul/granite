import Foundation
import KBCore

/// Deterministic, seedable RNG so fixture vaults are byte-identical across runs.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// One synthetic re-find query: words drawn from a block, and the note that holds it.
public struct FixtureQuery: Codable, Sendable, Hashable {
    public let query: String
    public let expected: String
}

public struct FixtureSummary: Sendable {
    public let notes: Int
    public let bytes: Int
    public let queries: [FixtureQuery]
}

public enum FixtureError: Error, CustomStringConvertible {
    case outputNotEmpty(String)

    public var description: String {
        switch self {
        case .outputNotEmpty(let path): "refusing to write fixtures into a non-empty folder: \(path)"
        }
    }
}

/// Generates a synthetic vault that exercises everything the parser and index handle:
/// frontmatter, typed relations, wikilinks (some unresolved), tags, headings, block IDs,
/// callouts, code blocks and lists, spread across the plan's folder layout.
public struct FixtureGenerator: Sendable {
    public let noteCount: Int
    public let seed: UInt64
    public let queryCount: Int

    public init(noteCount: Int, seed: UInt64 = 42, queryCount: Int = 200) {
        self.noteCount = noteCount
        self.seed = seed
        self.queryCount = queryCount
    }

    static let folders: [(String, Int)] = [
        ("Notes", 48), ("Daily", 14), ("Papers", 10), ("Clippings", 10), ("References", 5),
        ("Inbox", 5), ("AI/Synthesis", 3), ("Private", 2), ("Code", 2), ("Projects", 1),
    ]

    /// Writes the vault into `directory`, which must be empty or absent.
    @discardableResult
    public func write(to directory: URL) throws -> FixtureSummary {
        let manager = FileManager.default
        if let existing = try? manager.contentsOfDirectory(atPath: directory.path(percentEncoded: false)),
           !existing.filter({ $0 != ".DS_Store" }).isEmpty {
            throw FixtureError.outputNotEmpty(directory.path(percentEncoded: false))
        }
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)

        var rng = SplitMix64(seed: seed)
        let vocabulary = Vocabulary(size: 20_000, rng: &rng)
        var titles = makeTitles(vocabulary: vocabulary, rng: &rng)
        var folderOf: [String] = []
        folderOf.reserveCapacity(noteCount)
        let totalWeight = Self.folders.reduce(0) { $0 + $1.1 }
        for _ in 0..<noteCount {
            var pick = Int(rng.next(upperBound: UInt64(totalWeight)))
            var chosen = Self.folders[0].0
            for (folder, weight) in Self.folders {
                if pick < weight { chosen = folder; break }
                pick -= weight
            }
            folderOf.append(chosen)
        }
        for index in 0..<noteCount where folderOf[index] == "Daily" { titles[index] = dailyTitle(index: index) }
        for folder in Set(folderOf) {
            try manager.createDirectory(at: directory.appending(path: folder), withIntermediateDirectories: true)
        }

        var bytes = 0
        var candidates: [FixtureQuery] = []
        let baseDate = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<noteCount {
            let folder = folderOf[index]
            let title = titles[index]
            let (text, sample) = renderNote(index: index, folder: folder, titles: titles, vocabulary: vocabulary,
                                            baseDate: baseDate, rng: &rng)
            let data = Data(text.utf8)
            bytes += data.count
            let path = "\(folder)/\(title).md"
            try data.write(to: directory.appending(path: path))
            if let sample, rng.next(upperBound: UInt64(4)) == 0 {
                candidates.append(FixtureQuery(query: sample, expected: path))
            }
        }

        var queries: [FixtureQuery] = []
        if !candidates.isEmpty {
            let stride = max(1, candidates.count / max(1, queryCount))
            queries = Swift.stride(from: 0, to: candidates.count, by: stride).prefix(queryCount).map { candidates[$0] }
        }
        let evalDirectory = directory.appending(path: ".granite/eval")
        try manager.createDirectory(at: evalDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let lines = try queries.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
        try Data((lines.joined(separator: "\n") + "\n").utf8).write(to: evalDirectory.appending(path: "synthetic.jsonl"))
        return FixtureSummary(notes: noteCount, bytes: bytes, queries: queries)
    }

    func makeTitles(vocabulary: Vocabulary, rng: inout SplitMix64) -> [String] {
        var seen = Set<String>()
        var titles: [String] = []
        titles.reserveCapacity(noteCount)
        for index in 0..<noteCount {
            let words = (0..<(2 + Int(rng.next(upperBound: UInt64(3))))).map { _ in vocabulary.uniform(&rng) }
            var title = words.joined(separator: " ")
            title = title.prefix(1).uppercased() + title.dropFirst()
            if !seen.insert(title.lowercased()).inserted { title += " \(index)" ; seen.insert(title.lowercased()) }
            titles.append(title)
        }
        return titles
    }

    func dailyTitle(index: Int) -> String {
        let date = Date(timeIntervalSince1970: 1_500_000_000 + Double(index) * 86_400)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    /// Returns the note text and, sometimes, a query sampled from one of its paragraphs.
    func renderNote(index: Int, folder: String, titles: [String], vocabulary: Vocabulary, baseDate: Date,
                    rng: inout SplitMix64) -> (String, String?) {
        let created = baseDate.addingTimeInterval(Double(index) * 3_600)
        let id = ULID(date: created, using: &rng)
        let day = ISO8601DateFormatter.string(from: created, timeZone: TimeZone(identifier: "UTC") ?? .gmt,
                                             formatOptions: [.withFullDate])
        let type: String = switch folder {
        case "Daily": "daily"
        case "Papers": "source"
        case "Clippings": "clipping"
        case "AI/Synthesis": "synthesis"
        case "Projects": "project"
        case "Code": "decision"
        default: rng.next(upperBound: UInt64(5)) == 0 ? "claim" : "note"
        }
        let origin: String = switch folder {
        case "Papers", "Clippings": "source"
        case "AI/Synthesis": "ai"
        default: "human"
        }

        func randomTitle(_ rng: inout SplitMix64) -> String {
            // One link in ten points at a note that doesn't exist yet.
            if rng.next(upperBound: UInt64(10)) == 0 { return "Missing " + vocabulary.uniform(&rng) }
            return titles[Int(rng.next(upperBound: UInt64(titles.count)))]
        }

        var lines: [String] = ["---", "id: \(id.string)", "type: \(type)", "origin: \(origin)", "created: \(day)"]
        let tagCount = Int(rng.next(upperBound: UInt64(4)))
        if tagCount > 0 {
            let tags = (0..<tagCount).map { _ in "topic/" + vocabulary.zipf(&rng) }
            lines.append("tags: [\(tags.joined(separator: ", "))]")
        }
        if type == "claim" {
            lines.append("status: held")
            lines.append("confidence: 0.\(1 + Int(rng.next(upperBound: UInt64(9))))")
            lines.append("supports: [\"[[\(randomTitle(&rng))]]\"]")
        }
        if type == "source" { lines.append("citekey: \(vocabulary.uniform(&rng))\(2000 + index % 26)") }
        if folder == "Clippings" { lines.append("trust: untrusted") }
        lines.append("---")

        var sample: String?
        let sections = 1 + Int(rng.next(upperBound: UInt64(4)))
        for section in 0..<sections {
            if section > 0 || rng.next(upperBound: UInt64(2)) == 0 {
                lines.append("")
                lines.append("## " + vocabulary.sentence(words: 2 + Int(rng.next(upperBound: UInt64(3))), &rng))
            }
            let paragraphs = 1 + Int(rng.next(upperBound: UInt64(3)))
            for _ in 0..<paragraphs {
                lines.append("")
                let wordCount = 20 + Int(rng.next(upperBound: UInt64(90)))
                var words = (0..<wordCount).map { _ in vocabulary.zipf(&rng) }
                if sample == nil, wordCount > 30 {
                    // Mid-frequency words make realistic, discriminative queries.
                    let picks = words.filter { vocabulary.rank(of: $0) > 200 }.prefix(3)
                    if picks.count == 3 { sample = picks.joined(separator: " ") }
                }
                let linkCount = Int(rng.next(upperBound: UInt64(3)))
                for _ in 0..<linkCount {
                    let position = Int(rng.next(upperBound: UInt64(words.count)))
                    words.insert("[[\(randomTitle(&rng))]]", at: position)
                }
                if rng.next(upperBound: UInt64(8)) == 0 {
                    words.insert("#" + vocabulary.zipf(&rng), at: Int(rng.next(upperBound: UInt64(words.count))))
                }
                var paragraph = words.joined(separator: " ")
                paragraph = paragraph.prefix(1).uppercased() + paragraph.dropFirst() + "."
                if rng.next(upperBound: UInt64(10)) == 0 { paragraph += " ^b\(index)x\(section)" }
                lines.append(paragraph)
            }
            switch rng.next(upperBound: UInt64(10)) {
            case 0:
                lines.append("")
                lines.append("```swift")
                lines.append("let \(vocabulary.uniform(&rng)) = \"[[not a link]]\"")
                lines.append("```")
            case 1:
                lines.append("")
                lines.append("> [!note] " + vocabulary.sentence(words: 3, &rng))
                lines.append("> " + vocabulary.sentence(words: 12, &rng))
            case 2, 3:
                lines.append("")
                for _ in 0..<(2 + Int(rng.next(upperBound: UInt64(4)))) {
                    lines.append("- " + vocabulary.sentence(words: 6, &rng))
                }
            default:
                break
            }
        }
        return (lines.joined(separator: "\n") + "\n", sample)
    }
}

/// Pronounceable pseudo-words with a Zipf-like frequency distribution, like real prose.
struct Vocabulary: Sendable {
    let words: [String]
    private let cumulative: [Double]
    private let ranks: [String: Int]

    init(size: Int, rng: inout SplitMix64) {
        let onsets = ["b", "c", "d", "f", "g", "h", "k", "l", "m", "n", "p", "r", "s", "t", "v", "z",
                      "br", "cl", "dr", "fl", "gr", "pl", "pr", "st", "tr", "sh", "ch", "th"]
        let vowels = ["a", "e", "i", "o", "u", "ai", "ea", "ou", "io"]
        let codas = ["", "", "n", "r", "s", "l", "m", "t", "nd", "st", "rk"]
        var seen = Set<String>()
        var words: [String] = []
        while words.count < size {
            let syllables = 1 + Int(rng.next(upperBound: UInt64(3)))
            var word = ""
            for _ in 0..<syllables {
                word += onsets[Int(rng.next(upperBound: UInt64(onsets.count)))]
                word += vowels[Int(rng.next(upperBound: UInt64(vowels.count)))]
            }
            word += codas[Int(rng.next(upperBound: UInt64(codas.count)))]
            if word.count >= 3, seen.insert(word).inserted { words.append(word) }
        }
        self.words = words
        var total = 0.0
        var cumulative: [Double] = []
        cumulative.reserveCapacity(size)
        for rank in 1...size {
            total += 1.0 / pow(Double(rank), 1.07)
            cumulative.append(total)
        }
        self.cumulative = cumulative.map { $0 / total }
        self.ranks = Dictionary(uniqueKeysWithValues: words.enumerated().map { ($1, $0) })
    }

    func zipf(_ rng: inout SplitMix64) -> String {
        let target = Double(rng.next() >> 11) / Double(1 << 53)
        var low = 0
        var high = cumulative.count - 1
        while low < high {
            let mid = (low + high) / 2
            if cumulative[mid] < target { low = mid + 1 } else { high = mid }
        }
        return words[low]
    }

    func uniform(_ rng: inout SplitMix64) -> String {
        words[Int(rng.next(upperBound: UInt64(words.count)))]
    }

    func rank(of word: String) -> Int { ranks[word] ?? Int.max }

    func sentence(words count: Int, _ rng: inout SplitMix64) -> String {
        (0..<count).map { _ in zipf(&rng) }.joined(separator: " ")
    }
}
