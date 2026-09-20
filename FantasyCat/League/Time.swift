import Foundation

/// Mirrors web/src/lib/time.ts, so both clients say the same thing.
enum TimeText {
    /// "2d 04:17", "04:17:09" under a day, "00:00:00" once passed.
    static func countdown(to: Date, now: Date) -> String {
        var s = max(0, Int(to.timeIntervalSince(now)))
        let d = s / 86400
        s -= d * 86400
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return d > 0 ? String(format: "%dd %02d:%02d", d, h, m) : String(format: "%02d:%02d:%02d", h, m, sec)
    }

    /// "Saturday at 11:59 PM" for a deadline stored as the following midnight.
    static func deadline(_ boundary: Date) -> String {
        let t = boundary.addingTimeInterval(-60)
        return "\(t.formatted(.dateTime.weekday(.wide))) at \(t.formatted(date: .omitted, time: .shortened))"
    }

    static func ago(_ when: Date, now: Date = .now) -> String {
        let s = max(0, now.timeIntervalSince(when))
        if s < 90 { return "just now" }
        if s < 3600 { return "\(Int((s / 60).rounded())) min ago" }
        if s < 86400 { return "\(Int((s / 3600).rounded())) hr ago" }
        let d = Int((s / 86400).rounded())
        return d == 1 ? "yesterday" : "\(d) days ago"
    }
}
