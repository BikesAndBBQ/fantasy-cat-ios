import CoreText
import SwiftUI
import UIKit

/// The design system's three typefaces. iOS ships none of them, so they're
/// bundled (FantasyCat/Fonts, all under the SIL Open Font License) and
/// registered when the app starts. Registering in code rather than through
/// Info.plist keeps the generated Info.plist generated.
enum Typefaces {
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        assert(urls.count >= 5, "fonts missing from the bundle: found \(urls.count)")
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

/// Which face, at what size and weight, scaling with which system text style.
/// Sizes are the web's pixel sizes; on iOS a point is that pixel.
struct TypeStyle {
    enum Face { case display, body, score }
    var face: Face
    var size: CGFloat
    var weight: CGFloat // 400...800, the variable fonts' wght axis
    var relativeTo: UIFont.TextStyle = .body
    var tracking: CGFloat = 0 // in em, like CSS letter-spacing

    static let wordmark = TypeStyle(face: .display, size: 19, weight: 800, relativeTo: .headline, tracking: -0.02)
    static let hero = TypeStyle(face: .display, size: 34, weight: 800, relativeTo: .largeTitle, tracking: -0.03)
    static let pageTitle = TypeStyle(face: .display, size: 28, weight: 800, relativeTo: .title1, tracking: -0.025)
    static let cardTitle = TypeStyle(face: .display, size: 17, weight: 700, relativeTo: .headline)
    static let body = TypeStyle(face: .body, size: 15, weight: 400)
    static let bodyStrong = TypeStyle(face: .body, size: 15, weight: 600)
    static let small = TypeStyle(face: .body, size: 13, weight: 400, relativeTo: .footnote)
    static let smallStrong = TypeStyle(face: .body, size: 13, weight: 600, relativeTo: .footnote)
    static let button = TypeStyle(face: .body, size: 15, weight: 600, relativeTo: .callout)
    static let buttonSmall = TypeStyle(face: .body, size: 13.5, weight: 600, relativeTo: .footnote)
    static let eyebrow = TypeStyle(face: .body, size: 11.5, weight: 600, relativeTo: .caption1, tracking: 0.12)
    static let score = TypeStyle(face: .score, size: 34, weight: 700, relativeTo: .largeTitle, tracking: 0.02)
    static let scoreSmall = TypeStyle(face: .score, size: 22, weight: 700, relativeTo: .title2, tracking: 0.02)

    func uiFont(scaledFor traits: UITraitCollection? = nil) -> UIFont {
        let base: UIFont
        switch face {
        case .score:
            // Static files: pick the closest of the three weights we bundle.
            let name = weight >= 700 ? "BarlowCondensed-Bold" : weight >= 600 ? "BarlowCondensed-SemiBold" : "BarlowCondensed-Medium"
            base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: .bold)
        case .display, .body:
            let family = face == .display ? Tokens.FontFamily.display : Tokens.FontFamily.body
            let wght = 0x7767_6874 // 'wght'
            let descriptor = UIFontDescriptor(fontAttributes: [
                .family: family,
                UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [wght: weight],
            ])
            let font = UIFont(descriptor: descriptor, size: size)
            // An unknown family silently becomes Helvetica; fall back on purpose instead.
            base = font.familyName == family ? font : .systemFont(ofSize: size, weight: weight >= 600 ? .bold : .regular)
        }
        return UIFontMetrics(forTextStyle: relativeTo).scaledFont(for: base, compatibleWith: traits)
    }
}

private struct Typed: ViewModifier {
    let style: TypeStyle
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize // re-evaluate when the person changes text size

    func body(content: Content) -> some View {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(dynamicTypeSize))
        let font = style.uiFont(scaledFor: traits)
        content.font(Font(font)).tracking(style.tracking * font.pointSize)
    }
}

extension View {
    /// Set type from the design system. Scales with Dynamic Type.
    func type(_ style: TypeStyle) -> some View { modifier(Typed(style: style)) }
}

private extension UIContentSizeCategory {
    init(_ size: DynamicTypeSize) {
        switch size {
        case .xSmall: self = .extraSmall
        case .small: self = .small
        case .medium: self = .medium
        case .large: self = .large
        case .xLarge: self = .extraLarge
        case .xxLarge: self = .extraExtraLarge
        case .xxxLarge: self = .extraExtraExtraLarge
        case .accessibility1: self = .accessibilityMedium
        case .accessibility2: self = .accessibilityLarge
        case .accessibility3: self = .accessibilityExtraLarge
        case .accessibility4: self = .accessibilityExtraExtraLarge
        case .accessibility5: self = .accessibilityExtraExtraExtraLarge
        @unknown default: self = .large
        }
    }
}
