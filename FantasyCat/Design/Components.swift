import FantasyCatCore
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

// MARK: Reactions

/// A post's reactions as chips (server designs/20261017-reactions.md §4),
/// the iOS twin of the web's `ReactionRow`: each emoji with how many people
/// put it there, mine in the selected tone, then the league's quick picks
/// not yet on the post, and a "+" that opens the phone's emoji keyboard.
/// Under the row, who reacted with what. `readOnly` is your own post:
/// counts and names, nothing to tap. VoiceOver gets the emoji's Unicode name.
struct ReactionRow: View {
    typealias Reaction = Components.Schemas.ReactionView
    let reactions: [Reaction]
    let quickPicks: [String]
    var readOnly = false
    var busy = false
    let onToggle: (String, Bool) -> Void
    @State private var picking = false

    var body: some View {
        let on = Set(reactions.map(\.emoji))
        let picks = readOnly ? [] : quickPicks.filter { !on.contains($0) }
        let named = reactions.filter { !($0.by ?? []).isEmpty }
        VStack(alignment: .leading, spacing: 8) {
            ChipFlow(spacing: 8) {
                ForEach(reactions, id: \.emoji) { r in
                    if readOnly {
                        Chip("\(r.emoji) \(r.count)").monospacedDigit().accessibilityLabel(Self.label(r))
                    } else {
                        chip("\(r.emoji) \(r.count)", tone: r.isMine ? .selected : .default, says: Self.label(r)) { onToggle(r.emoji, !r.isMine) }
                            .accessibilityAddTraits(r.isMine ? .isSelected : [])
                    }
                }
                ForEach(picks, id: \.self) { e in
                    chip(e, tone: .done, says: "React with \(Emoji.name(e))") { onToggle(e, true) }
                }
                if !readOnly {
                    chip("+", tone: .done, says: "React with another emoji") { picking = true }
                        .background { EmojiField(active: $picking) { onToggle($0, true) } }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(readOnly ? "Reactions" : "React to this post")
            if !named.isEmpty {
                Text(named.map { "\($0.emoji) \(Names.list($0.by ?? []))" }.joined(separator: " · "))
                    .type(.small).foregroundStyle(Tokens.muted)
                    .accessibilityLabel(named.map { "\(Emoji.name($0.emoji)): \(Names.list($0.by ?? []))" }.joined(separator: ". "))
            }
        }
    }

    private func chip(_ text: String, tone: Chip.Tone, says: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Chip(text, tone: tone).monospacedDigit() }
            .buttonStyle(PopButtonStyle())
            .disabled(busy)
            .accessibilityLabel(says)
    }

    /// "Smiling cat face with heart-shaped eyes, 4 people, you reacted".
    static func label(_ r: Reaction) -> String {
        "\(Emoji.name(r.emoji)), \(r.count) \(r.count == 1 ? "person" : "people")\(r.isMine ? ", you reacted" : "")"
    }
}

/// The one small pop a tapped chip gives, as the vote stepper's does.
private struct PopButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.28, bounce: 0.5), value: configuration.isPressed)
            .sensoryFeedback(.selection, trigger: configuration.isPressed) { !$0 && $1 }
    }
}

/// Chips in rows, wrapping to the next when a row is full.
struct ChipFlow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        place(in: proposal.width ?? .infinity, subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (i, p) in place(in: bounds.width, subviews).points.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + p.x, y: bounds.minY + p.y), proposal: .unspecified)
        }
    }

    private func place(in width: CGFloat, _ subviews: Subviews) -> (points: [CGPoint], size: CGSize) {
        var points: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (points, CGSize(width: widest, height: y + rowHeight))
    }
}

/// A text field nobody sees. When `active` turns on it opens the phone's
/// emoji keyboard (the only way to ask for it: a field whose input mode is
/// the emoji one), hands back what was typed, and closes.
private struct EmojiField: UIViewRepresentable {
    @Binding var active: Bool
    let onPick: (String) -> Void

    func makeUIView(context: Context) -> EmojiTextField {
        let f = EmojiTextField()
        f.delegate = context.coordinator
        f.autocorrectionType = .no
        f.autocapitalizationType = .none
        f.spellCheckingType = .no
        f.alpha = 0
        f.isAccessibilityElement = false
        f.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return f
    }

    func updateUIView(_ f: EmojiTextField, context: Context) {
        context.coordinator.parent = self
        if active, !f.isFirstResponder {
            DispatchQueue.main.async { f.becomeFirstResponder() }
        } else if !active, f.isFirstResponder {
            f.resignFirstResponder()
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: EmojiField
        init(_ parent: EmojiField) { self.parent = parent }

        @objc func changed(_ f: UITextField) {
            let v = (f.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            f.text = ""
            guard !v.isEmpty else { return }
            parent.onPick(v)
            f.resignFirstResponder()
        }

        func textFieldDidEndEditing(_ f: UITextField) { parent.active = false }
    }
}

final class EmojiTextField: UITextField {
    override var textInputContextIdentifier: String? { "emoji" }
    override var textInputMode: UITextInputMode? {
        UITextInputMode.activeInputModes.first { $0.primaryLanguage == "emoji" } ?? super.textInputMode
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

// MARK: Comments

/// One comment under a post (server designs/20261019-comments.md §5): the
/// face, the name and when, the text, and a "…" on the trailing edge that
/// opens a row of the kit's buttons under the comment with what the caller
/// may do, as the web's CommentItem does. Not a system `Menu`: that one
/// draws UIKit's context menu, which is not the app's look (Ryan, sc-3492).
struct CommentRow: View {
    enum Action { case delete, remove, report }
    let name: String
    var avatar: URL?
    let when: Date
    let text: String
    /// What the "…" offers: nothing hides it.
    var actions: [Action] = []
    var act: (Action) -> Void = { _ in }
    @State private var open: Bool

    init(name: String, avatar: URL? = nil, when: Date, text: String, actions: [Action] = [], open: Bool = false, act: @escaping (Action) -> Void = { _ in }) {
        self.name = name
        self.avatar = avatar
        self.when = when
        self.text = text
        self.actions = actions
        self.act = act
        _open = State(initialValue: open)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Avatar(url: avatar, kind: .person, size: .sm)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(name).type(.smallStrong).foregroundStyle(Tokens.ink).lineLimit(1)
                        Text(TimeText.ago(when)).type(.small).foregroundStyle(Tokens.muted).lineLimit(1)
                    }
                    Text(text).type(.body).foregroundStyle(Tokens.ink).fixedSize(horizontal: false, vertical: true)
                }
                // VoiceOver reads the comment as one thing: "Rebecca, 2 hr ago, what a face".
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(name), \(TimeText.ago(when)), \(text)")
                Spacer(minLength: 0)
                if !actions.isEmpty {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { open.toggle() }
                    } label: {
                        Image(systemName: "ellipsis")
                            .type(.small).foregroundStyle(open ? Tokens.ink : Tokens.muted)
                            .frame(width: 32, height: 32) // a finger
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("More, \(name)'s comment")
                    .accessibilityAddTraits(open ? .isSelected : [])
                    .accessibilityIdentifier("comment-more")
                }
            }
            if open {
                ChipFlow(spacing: 10) {
                    ForEach(actions, id: \.self) { a in
                        switch a {
                        case .delete: Button("Delete") { choose(.delete) }.buttonStyle(.fc(.danger, size: .sm)).accessibilityIdentifier("delete-comment")
                        case .remove: Button("Remove from your post") { choose(.remove) }.buttonStyle(.fc(.danger, size: .sm)).accessibilityIdentifier("remove-comment")
                        case .report: Button("Report") { choose(.report) }.buttonStyle(.fc(size: .sm)).accessibilityIdentifier("report-comment")
                        }
                    }
                    Button("Cancel") { withAnimation(.easeOut(duration: 0.15)) { open = false } }.buttonStyle(.fc(size: .sm))
                }
                .padding(.leading, 36) // under the text, past the face
                .transition(.opacity)
            }
        }
    }

    private func choose(_ a: Action) {
        open = false
        act(a)
    }
}

/// Where a comment is written: a field that grows with the text, and Send,
/// which is busy while the comment is on its way and off while there is
/// nothing to send. The web's Composer.
struct Composer: View {
    @Binding var text: String
    var busy = false
    var send: () -> Void
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Say something…", text: $text, axis: .vertical)
                .lineLimit(1...6)
                .focused(focused)
                .type(TypeStyle(face: .body, size: 16, weight: 400))
                .foregroundStyle(Tokens.ink)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous)
                        .strokeBorder(focused.wrappedValue ? Tokens.accentInk : Tokens.line, lineWidth: 1.5)
                }
                .accessibilityLabel("Comment")
                .accessibilityIdentifier("comment-body")
            Button("Send", action: send)
                .buttonStyle(.fc(.ink, size: .sm, busy: busy))
                .disabled(busy || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("send-comment")
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

// MARK: Info tip and the notifications grid

/// A circled-i button that opens a compact popover listing a few lines: what
/// a switch covers, without a help line under every row (server
/// designs/20261019-notification-settings.md §5). VoiceOver hears
/// "What's in <title>".
struct InfoTip: View {
    let title: String
    let lines: [String]
    @State private var open: Bool

    /// `open` starts the popover shown: the gallery's way to screenshot it
    /// (`ARGS='-section Notifications -tip "New posts"'`), nothing else's.
    init(title: String, lines: [String], open: Bool = false) {
        self.title = title
        self.lines = lines
        _open = State(initialValue: open)
    }

    var body: some View {
        Button { open.toggle() } label: {
            Image(systemName: "info.circle").type(.body).foregroundStyle(Tokens.muted)
                .frame(minWidth: 32, minHeight: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("What's in \(title)")
        .popover(isPresented: $open, arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).type(.bodyStrong).foregroundStyle(Tokens.ink)
                ForEach(lines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("·").type(.body).foregroundStyle(Tokens.muted)
                        Text(line).type(.body).foregroundStyle(Tokens.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(16)
            // A fixed width, not a maximum: a compact popover sizes to its
            // content's ideal width, which for a long line is the whole line,
            // so at a larger text size the line was clipped to "...yo…"
            // (Ryan, sc-3129). At 280 points it wraps and the popover grows down.
            .frame(width: 280, alignment: .leading)
            .presentationBackground(Tokens.surface)
            .presentationCompactAdaptation(.popover)
        }
    }
}

/// The notification settings: a row per category with its label and info
/// button, then a switch per channel. With one channel it reads as a list of
/// switches; a second channel is a column, not a screen. Everything shown
/// comes from the server's rows; the app holds no list of its own.
struct NotificationsGrid: View {
    let rows: [Components.Schemas.NotificationRow]
    /// Called with the category, the channel and the new value.
    let set: (String, String, Bool) async -> Void
    /// The label of the row whose info tip starts open; the gallery's only.
    var openTip: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Notifications")
            if rows.isEmpty {
                Text("Loading your settings…").type(.small).foregroundStyle(Tokens.muted)
            }
            ForEach(rows, id: \.category) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 2) {
                        Text(row.label).type(.bodyStrong).foregroundStyle(Tokens.ink)
                        if let events = row.events, !events.isEmpty { InfoTip(title: row.label, lines: events, open: openTip == row.label) }
                    }
                    ForEach(row.channels ?? [], id: \.channel) { cell in
                        Toggle(isOn: Binding(get: { cell.on }, set: { on in Task { await set(row.category, cell.channel, on) } })) {
                            Text(Self.channelLabel(cell.channel)).type(.body).foregroundStyle(Tokens.ink)
                        }
                        .tint(Tokens.ink)
                        .accessibilityLabel("\(row.label) by \(Self.channelLabel(cell.channel).lowercased())")
                    }
                }
            }
        }
    }

    /// The channel's word. The server sends the key; the words are few and
    /// the app's, as the web's are.
    static func channelLabel(_ channel: String) -> String {
        switch channel {
        case "email": "Email"
        case "push": "Push"
        case "web": "In the app"
        default: channel.capitalized
        }
    }
}
