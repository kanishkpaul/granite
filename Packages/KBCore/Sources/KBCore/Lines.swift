/// One physical line of a file, without its terminator.
/// Swift treats "\r\n" as a single Character, so splitting a String on "\n" misses CRLF.
/// Splitting runs over UTF-8 bytes instead.
public struct Line: Sendable, Hashable {
    /// Text without "\n" or "\r\n".
    public let text: String
    /// Zero-based line index in the file.
    public let index: Int
    /// The terminator that followed this line: "\n", "\r\n" or "" for the last line.
    public let terminator: String
}

public enum Lines {
    public static func split(_ text: String) -> [Line] {
        var lines: [Line] = []
        let bytes = Array(text.utf8)
        var start = 0
        var index = 0
        var position = 0
        while position < bytes.count {
            if bytes[position] == 0x0A {
                var end = position
                var terminator = "\n"
                if end > start, bytes[end - 1] == 0x0D {
                    end -= 1
                    terminator = "\r\n"
                }
                lines.append(Line(text: String(decoding: bytes[start..<end], as: UTF8.self), index: index, terminator: terminator))
                index += 1
                start = position + 1
            }
            position += 1
        }
        if start < bytes.count {
            lines.append(Line(text: String(decoding: bytes[start..<bytes.count], as: UTF8.self), index: index, terminator: ""))
        }
        return lines
    }

    /// The dominant line ending in a file, used when granite inserts lines.
    public static func preferredTerminator(in lines: [Line]) -> String {
        let crlf = lines.lazy.filter { $0.terminator == "\r\n" }.count
        let lf = lines.lazy.filter { $0.terminator == "\n" }.count
        return crlf > lf ? "\r\n" : "\n"
    }
}
