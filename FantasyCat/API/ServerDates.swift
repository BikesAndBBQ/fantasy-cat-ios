import Foundation
import OpenAPIRuntime

/// The server is Go, which writes RFC 3339 with as many fractional digits as
/// the time has: "12:57:12.99077-07:00", or none at all when they're zero. The
/// generated client's default parser accepts only the second form, so without
/// this every response carrying a timestamp failed to decode (found by signing
/// in against the dev server, which answered 200 to an app that showed an error).
struct ServerDateTranscoder: DateTranscoder {
    func encode(_ date: Date) throws -> String {
        date.formatted(.iso8601.year().month().day().timeZone(separator: .omitted).time(includingFractionalSeconds: true).timeSeparator(.colon))
    }

    func decode(_ string: String) throws -> Date {
        if let d = Self.parse(string) { return d }
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Not an RFC 3339 timestamp: \(string)"))
    }

    static func parse(_ string: String) -> Date? {
        // Foundation's parser wants exactly three fractional digits or none.
        // Trim or pad whatever Go sent down to milliseconds.
        var s = string
        if let dot = s.firstIndex(of: "."), let end = s[dot...].dropFirst().firstIndex(where: { !$0.isNumber }) {
            let digits = s[s.index(after: dot)..<end]
            let millis = String(digits.prefix(3)).padding(toLength: 3, withPad: "0", startingAt: 0)
            s.replaceSubrange(dot..<end, with: "." + millis)
            return try? Date(s, strategy: .iso8601.year().month().day().timeZone(separator: .colon).time(includingFractionalSeconds: true).timeSeparator(.colon))
        }
        return try? Date(s, strategy: .iso8601.year().month().day().timeZone(separator: .colon).time(includingFractionalSeconds: false).timeSeparator(.colon))
    }
}
