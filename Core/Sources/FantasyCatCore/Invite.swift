import Foundation

public enum Invite {
    /// People paste the whole link; the code is its last path component.
    /// "https://fantasycat.co/join/PineStCats" and "  pinestcats " both give "pinestcats".
    public static func code(from text: String) -> String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: t), url.scheme != nil, let last = url.pathComponents.last, last != "/" { return last.lowercased() }
        return t.lowercased()
    }
}
