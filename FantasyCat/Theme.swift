import SwiftUI

/// Milestone 0 stand-in. Milestone 1 replaces this file with one generated
/// from the server repo's `design/tokens.json`, the same source the web app's
/// theme is compiled from, so the two can't drift. Until then these are the
/// handful of values the first screen needs, copied by hand. Don't add to it.
enum Theme {
    static let accent = Color(red: 0xF0 / 255, green: 0x56 / 255, blue: 0x7E / 255) // tokens.json "accent"

    /// The page. Dark is "lamplit": warm, not black.
    static let paper = Color(light: (0xF3, 0xF4, 0xF8), dark: (0x1C, 0x18, 0x15))
    static let ink = Color(light: (0x15, 0x18, 0x2B), dark: (0xF4, 0xEE, 0xE8))
}

extension Color {
    init(light: (Int, Int, Int), dark: (Int, Int, Int)) {
        self.init(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255, blue: CGFloat(c.2) / 255, alpha: 1)
        })
    }
}
