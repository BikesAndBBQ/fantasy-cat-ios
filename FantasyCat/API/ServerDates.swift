import FantasyCatCore
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
        if let d = ServerDate.parse(string) { return d }
        throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Not an RFC 3339 timestamp: \(string)"))
    }

}
