import Foundation

public enum ServerDate {
    /// The server is Go, which writes RFC 3339 with as many fractional digits as
    /// the time has ("12:57:12.99077-07:00"), or none when they're zero.
    /// Foundation's parser wants exactly three or none, so normalise first.
    /// This is the bug that made the first real sign-in fail on a 200.
    public static func parse(_ string: String) -> Date? {
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
