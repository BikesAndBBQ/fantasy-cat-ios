import Foundation

/// The forced-update comparison (I13). The server says the oldest build that
/// may still run; the app compares its own CFBundleVersion.
public enum UpdateCheck {
    /// True only when both numbers are known and this build is older than the
    /// minimum. Anything unreadable lets the person in: a check that can't
    /// tell must never lock someone out of a working app.
    public static func mustUpdate(build: String?, minBuild: Int64?) -> Bool {
        guard let minBuild, minBuild > 0,
              let build = build?.trimmingCharacters(in: .whitespaces), let mine = Int64(build) else { return false }
        return mine < minBuild
    }
}
