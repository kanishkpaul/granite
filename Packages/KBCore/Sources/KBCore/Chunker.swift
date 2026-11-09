/// A retrieval unit: consecutive blocks of one note, sized for an embedding model.
public struct Chunk: Sendable, Hashable {
    /// Indexes into `ParsedNote.blocks` (inclusive).
    public let firstBlock: Int
    public let lastBlock: Int
    public let headingPath: String
    /// "Title > Heading > Sub": prepended when embedding (cheap contextual retrieval).
    public let prefix: String
    public let text: String
    /// Approximate token count (words × 1.3).
    public let tokens: Int

    /// What the embedder sees.
    public var embeddingText: String { prefix + "\n" + text }
}

/// Heading-aware chunking (master plan §6.2): about 900 tokens per chunk, code blocks and other
/// blocks never split, a new chunk at every `#`/`##` heading, small sections merged.
public enum Chunker {
    /// Bump when chunk boundaries change: stored vectors are then re-embedded.
    public static let version = 1
    public static let targetTokens = 900

    public static func chunks(for note: ParsedNote, target: Int = targetTokens) -> [Chunk] {
        var chunks: [Chunk] = []
        var start: Int?
        var end = 0
        var tokens = 0

        func flush() {
            guard let first = start else { return }
            let blocks = note.blocks[first...end]
            let headingPath = blocks.first { $0.kind != .heading }?.headingPath ?? blocks.first?.headingPath ?? ""
            let prefix = headingPath.isEmpty ? note.title : "\(note.title) > \(headingPath)"
            chunks.append(Chunk(firstBlock: first, lastBlock: end, headingPath: headingPath, prefix: prefix,
                                text: blocks.map(\.text).joined(separator: "\n\n"), tokens: tokens))
            start = nil
            tokens = 0
        }

        for (index, block) in note.blocks.enumerated() where !block.text.isEmpty {
            let size = estimateTokens(block.text)
            if start != nil {
                let majorHeading = block.kind == .heading && (block.level ?? 6) <= 2
                let minorHeadingAfterBulk = block.kind == .heading && tokens >= target / 2
                if majorHeading || minorHeadingAfterBulk || tokens + size > target { flush() }
            }
            if start == nil { start = index }
            end = index
            tokens += size
        }
        flush()
        return chunks
    }

    public static func estimateTokens(_ text: String) -> Int {
        var words = 0
        var inWord = false
        for scalar in text.unicodeScalars {
            let isSpace = scalar.properties.isWhitespace
            if !isSpace && !inWord { words += 1 }
            inWord = !isSpace
        }
        return Int((Double(words) * 1.3).rounded(.up))
    }
}
