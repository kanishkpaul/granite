import Foundation

/// A 26-character Crockford base32 ULID: 48-bit millisecond timestamp + 80 random bits.
/// Stamped as `id:` in frontmatter so identity survives renames (principle 9).
public struct ULID: Sendable, Hashable, Comparable, CustomStringConvertible {
    public let string: String

    static let alphabet: [Character] = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    private static let decode: [Character: UInt8] = {
        var map: [Character: UInt8] = [:]
        for (index, char) in alphabet.enumerated() {
            map[char] = UInt8(index)
            map[Character(char.lowercased())] = UInt8(index)
        }
        return map
    }()

    public init(date: Date = Date()) {
        var rng = SystemRandomNumberGenerator()
        self.init(date: date, using: &rng)
    }

    public init<R: RandomNumberGenerator>(date: Date, using rng: inout R) {
        let millis = UInt64(max(0, (date.timeIntervalSince1970 * 1000).rounded(.down)))
        var chars: [Character] = []
        chars.reserveCapacity(26)
        // 10 chars of timestamp (50 bits; top 2 always zero for 48-bit values).
        for shift in stride(from: 45, through: 0, by: -5) {
            chars.append(Self.alphabet[Int((millis >> UInt64(shift)) & 0x1F)])
        }
        // 16 chars of randomness (80 bits).
        for _ in 0..<16 {
            chars.append(Self.alphabet[Int(rng.next(upperBound: UInt8(32)))])
        }
        self.string = String(chars)
    }

    /// Parses a canonical ULID; returns nil for anything else.
    public init?(_ string: String) {
        guard string.count == 26 else { return nil }
        var normalized = ""
        normalized.reserveCapacity(26)
        for char in string {
            guard let value = Self.decode[char] else { return nil }
            normalized.append(Self.alphabet[Int(value)])
        }
        // The first character must be <= 7 or the timestamp overflows 48 bits.
        guard let first = normalized.first, let firstValue = Self.decode[first], firstValue <= 7 else { return nil }
        self.string = normalized
    }

    /// Milliseconds since the Unix epoch encoded in the first 10 characters.
    public var timestampMillis: UInt64 {
        var value: UInt64 = 0
        for char in string.prefix(10) {
            value = (value << 5) | UInt64(Self.decode[char] ?? 0)
        }
        return value
    }

    public var date: Date { Date(timeIntervalSince1970: Double(timestampMillis) / 1000) }

    public var description: String { string }

    public static func < (lhs: ULID, rhs: ULID) -> Bool { lhs.string < rhs.string }
}
