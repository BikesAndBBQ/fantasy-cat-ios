import Foundation

public enum Invite {
    /// People paste the whole link; the code is its last path component.
    /// "https://fantasycat.co/join/PineStCats" and "  pinestcats " both give "pinestcats".
    public static func code(from text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: t), url.scheme != nil, let last = url.pathComponents.last, last != "/" { return last.lowercased() }
        return t.lowercased()
    }

    /// The code in a link the app was opened with, or nil when it isn't an
    /// invite. Stricter than `code(from:)`: only fantasycat.co's /join/<code>,
    /// the path the server's apple-app-site-association claims for the app.
    public static func code(fromLink url: URL) -> String? {
        guard url.scheme == "https", let host = url.host()?.lowercased(), host == "fantasycat.co" || host == "www.fantasycat.co" else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count == 2, parts[0] == "join", !parts[1].isEmpty else { return nil }
        return parts[1].lowercased()
    }
}
