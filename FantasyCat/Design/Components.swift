import SwiftUI

// The component kit, mirroring web/src/components/ui.tsx in the server repo.
// Everything visual comes from Tokens and TypeStyle: no raw colors, fonts or
// radii in here or in any screen.

// MARK: Button

struct FCButtonStyle: ButtonStyle {
    enum Variant { case primary, ink, quiet, danger }
    enum Size { case md, sm }
    var variant: Variant = .quiet
    var size: Size = .md
    var block = false
    var busy = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            if busy { ProgressView().controlSize(.small).tint(foreground) }
            configuration.label
        }
        .type(size == .md ? .button : .buttonSmall)
        .foregroundStyle(foreground)
        .padding(.horizontal, size == .md ? 20 : 14)
        .padding(.vertical, size == .md ? 11 : 7)
        .frame(maxWidth: block ? .infinity : nil)
        .frame(minHeight: size == .md ? 44 : 32) // a finger, not a cursor
        .background(background, in: Capsule())
        .overlay { if let ring { Capsule().strokeBorder(ring, lineWidth: 1.5) } }
        .contentShape(Capsule())
        .opacity(isEnabled && !busy ? 1 : 0.45)
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch variant {
        case .primary: Tokens.onAccent
        case .ink: Tokens.paper
        case .quiet: Tokens.ink
        case .danger: Tokens.danger
        }
    }
    private var background: Color {
        switch variant {
        case .primary: Tokens.accent
        case .ink: Tokens.ink
        case .quiet, .danger: .clear
        }
    }
    private var ring: Color? {
        switch variant {
        case .quiet: Tokens.line
        case .danger: Tokens.danger
        default: nil
        }
    }
}

extension ButtonStyle where Self == FCButtonStyle {
    /// One `.primary` per screen: the single thing that matters right now.
    static func fc(_ variant: FCButtonStyle.Variant = .quiet, size: FCButtonStyle.Size = .md, block: Bool = false, busy: Bool = false) -> FCButtonStyle {
        FCButtonStyle(variant: variant, size: size, block: block, busy: busy)
    }
}

// MARK: Text bits

/// The small uppercase line above a title or a group.
struct Eyebrow: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text.uppercased()).type(.eyebrow).foregroundStyle(Tokens.muted)
    }
}

struct PageTitle<Aside: View>: View {
    var eyebrow: String?
    let title: String
    @ViewBuilder var aside: Aside

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let eyebrow { Eyebrow(eyebrow) }
                Spacer()
                aside
            }
            Text(title).type(.pageTitle).foregroundStyle(Tokens.ink).accessibilityAddTraits(.isHeader)
        }
    }
}

extension PageTitle where Aside == EmptyView {
    init(_ title: String, eyebrow: String? = nil) {
        self.init(eyebrow: eyebrow, title: title) { EmptyView() }
    }
}

// MARK: Chip

struct Chip: View {
    enum Tone { case `default`, selected, live, done }
    let text: String
    var tone: Tone = .default
    init(_ text: String, tone: Tone = .default) {
        self.text = text
        self.tone = tone
    }

    var body: some View {
        HStack(spacing: 6) {
            if tone == .live { Circle().frame(width: 7, height: 7) }
            Text(text).lineLimit(1)
        }
        .type(.smallStrong)
        .foregroundStyle(foreground)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(background, in: Capsule())
        .overlay { if tone == .done { Capsule().strokeBorder(Tokens.line, lineWidth: 1.5) } }
    }

    private var foreground: Color {
        switch tone {
        case .default: Tokens.ink
        case .selected: Tokens.paper
        case .live: Tokens.accentInk
        case .done: Tokens.muted
        }
    }
    private var background: Color {
        switch tone {
        case .default: Tokens.sunken
        case .selected: Tokens.ink
        case .live: Tokens.accentWash
        case .done: .clear
        }
    }
}

// MARK: Card and banner

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).strokeBorder(Tokens.line, lineWidth: 1) }
    }
}

/// A label that leads straight into its number ("Submissions close in" /
/// "2d 04:17"), with the supporting line below and quieter.
struct Banner: View {
    let label: String
    let value: String
    var detail: String?
    /// Inverted (ink on the page) is the countdown; the quiet one reports something that already happened.
    var inverted = true

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous)
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased()).type(.eyebrow).opacity(0.7)
            Text(value).type(.score).foregroundStyle(inverted ? Tokens.accent : Tokens.accentInk).monospacedDigit()
            if let detail { Text(detail).type(.small).opacity(0.72).padding(.top, 4) }
        }
        .foregroundStyle(inverted ? Tokens.paper : Tokens.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(inverted ? Tokens.ink : Tokens.surface, in: shape)
        .overlay { if !inverted { shape.strokeBorder(Tokens.line, lineWidth: 1) } }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Field

struct FCField: View {
    let label: String
    @Binding var text: String
    var help: String?
    var error: String?
    var secure = false
    var contentType: UITextContentType?
    var keyboard: UIKeyboardType = .default
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).type(.smallStrong).foregroundStyle(Tokens.ink)
            Group {
                if secure { SecureField("", text: $text) } else { TextField("", text: $text) }
            }
            .textContentType(contentType)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focused)
            .type(TypeStyle(face: .body, size: 16, weight: 400))
            .foregroundStyle(Tokens.ink)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous)
                    .strokeBorder(error != nil ? Tokens.danger : focused ? Tokens.accentInk : Tokens.line, lineWidth: 1.5)
            }
            .accessibilityLabel(label)
            if let note = error ?? help {
                Text(note).type(.small).foregroundStyle(error != nil ? Tokens.danger : Tokens.muted)
            }
        }
    }
}

// MARK: Avatar

/// A person's or a cat's face. Always a circle, cropped to fill. No photo
/// means the placeholder for its kind, never initials. The shapes are
/// stand-ins for Rebecca's drawings and match the web's.
struct Avatar: View {
    enum Kind { case person, cat }
    enum Size: CGFloat { case sm = 26, md = 40, lg = 72 }
    var url: URL?
    var kind: Kind = .person
    var size: Size = .sm

    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
        }
        .frame(width: size.rawValue, height: size.rawValue)
        .background(Tokens.accentWash)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        Canvas { ctx, canvas in
            let s = canvas.width / 40
            var p = Path()
            switch kind {
            case .cat:
                p.move(to: .init(x: 6.5, y: 40)); p.addLine(to: .init(x: 6.5, y: 24.5)); p.addLine(to: .init(x: 9.5, y: 8.5))
                p.addLine(to: .init(x: 17.8, y: 15.4)); p.addQuadCurve(to: .init(x: 22.2, y: 15.4), control: .init(x: 20, y: 14.8))
                p.addLine(to: .init(x: 30.5, y: 8.5)); p.addLine(to: .init(x: 33.5, y: 24.5)); p.addLine(to: .init(x: 33.5, y: 40)); p.closeSubpath()
            case .person:
                p.addEllipse(in: .init(x: 13, y: 8.5, width: 14, height: 14))
                p.move(to: .init(x: 5.5, y: 40)); p.addCurve(to: .init(x: 20, y: 25.5), control1: .init(x: 5.5, y: 30.5), control2: .init(x: 11.7, y: 25.5))
                p.addCurve(to: .init(x: 34.5, y: 40), control1: .init(x: 28.3, y: 25.5), control2: .init(x: 34.5, y: 30.5)); p.closeSubpath()
            }
            ctx.fill(p.applying(.init(scaleX: s, y: s)), with: .color(Tokens.accentInk.opacity(0.62)))
        }
    }
}

// MARK: Rosette

/// A cat-show rosette: blue first, red second, yellow third. Results only.
struct Rosette: View {
    let place: Int // 1...3
    var height: CGFloat = 58

    var body: some View {
        let color = [Tokens.ribbon1, Tokens.ribbon2, Tokens.ribbon3][max(0, min(2, place - 1))]
        Canvas { ctx, canvas in
            let s = canvas.height / 58
            let t = CGAffineTransform(scaleX: s, y: s)
            var tails = Path()
            for pts in [[(13, 30), (8, 56), (17, 50), (23, 58), (27, 34)], [(33, 30), (38, 56), (29, 50), (23, 58), (19, 34)]] {
                tails.move(to: .init(x: pts[0].0, y: pts[0].1))
                pts.dropFirst().forEach { tails.addLine(to: .init(x: $0.0, y: $0.1)) }
                tails.closeSubpath()
            }
            ctx.fill(tails.applying(t), with: .color(color.opacity(0.8)))
            let center = CGPoint(x: 23, y: 21)
            let ring = Path(ellipseIn: CGRect(x: center.x - 17, y: center.y - 17, width: 34, height: 34))
            ctx.stroke(ring.applying(t), with: .color(color), style: .init(lineWidth: 8 * s, lineCap: .round, dash: [5.2 * s, 3.7 * s]))
            ctx.fill(Path(ellipseIn: CGRect(x: 8, y: 6, width: 30, height: 30)).applying(t), with: .color(color))
            ctx.stroke(Path(ellipseIn: CGRect(x: 11.5, y: 9.5, width: 23, height: 23)).applying(t), with: .color(.white.opacity(0.55)), lineWidth: 1.2 * s)
            let numeral = Text("\(place)").font(Font(TypeStyle(face: .score, size: 19 * s, weight: 700).uiFont())).foregroundStyle(place == 3 ? Tokens.onAccent : .white)
            ctx.draw(numeral, at: CGPoint(x: center.x * s, y: center.y * s))
        }
        .frame(width: height * 46 / 58, height: height)
        .accessibilityLabel(["First place", "Second place", "Third place"][max(0, min(2, place - 1))])
    }
}
