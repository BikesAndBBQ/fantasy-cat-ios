import FantasyCatCore
import SwiftUI

/// Every component on one screen, for looking at. Launch with `-gallery`
/// (`make shot GALLERY=1`), and `-section Reactions` to open scrolled to a
/// section (`ARGS='-section Reactions'`), since a screenshot shows one
/// screen. The iOS counterpart of design/design-system.html in the server
/// repo: if the two disagree, that page wins.
struct GalleryView: View {
    @State private var name = "Totoro"
    @State private var password = ""
    @State private var votes = 2
    @State private var comment = "Those ears"
    @FocusState private var composing: Bool

    var body: some View {
        ScrollViewReader { scroll in
            gallery.onAppear {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-section"), i + 1 < args.endIndex {
                    scroll.scrollTo(args[i + 1], anchor: .top)
                }
            }
        }
    }

    private var gallery: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageTitle(eyebrow: "Round 3 of 8", title: "This week") { Chip("Open", tone: .live) }
                Banner(label: "Submissions close in", value: "2d 04:17", detail: "Saturday at 11:59 PM")
                Banner(label: "You earned", value: "+10", detail: "7 treats, 3 for showing up", inverted: false)
                PendingPostNotice(post: Self.pending(media: nil, failure: nil))
                PendingPostNotice(post: Self.pending(media: 1, failure: "Submissions for this round have closed."), postAgain: {})
                PictureOfferCard(picture: nil) { _ in nil }
                section("Buttons") {
                    Button("Post it") {}.buttonStyle(.fc(.primary, block: true))
                    HStack {
                        Button("Save") {}.buttonStyle(.fc(.ink))
                        Button("Cancel") {}.buttonStyle(.fc())
                        Button("Remove") {}.buttonStyle(.fc(.danger, size: .sm))
                    }
                    HStack {
                        Button("Saving") {}.buttonStyle(.fc(.ink, busy: true))
                        Button("Disabled") {}.buttonStyle(.fc()).disabled(true)
                    }
                }
                section("Chips") {
                    HStack { Chip("Top of the cat tree", tone: .selected); Chip("Sploot"); Chip("admin", tone: .done) }
                }
                section("Reactions") {
                    ReactionRow(reactions: Self.reactions, quickPicks: ["😻", "😂", "😮", "😭", "🔥", "👑"]) { _, _ in }
                    ReactionRow(reactions: Self.reactions, quickPicks: [], readOnly: true) { _, _ in }
                }
                section("Comments") {
                    CommentRow(name: "Rebecca", when: .now.addingTimeInterval(-7200), text: "What a face. The whiskers alone deserve a treat.", actions: [.remove, .report], open: true)
                    CommentRow(name: "You", when: .now.addingTimeInterval(-300), text: "He knows.", actions: [.delete])
                    Composer(text: $comment, busy: false, send: {}, focused: $composing)
                }
                section("Votes") {
                    HStack {
                        Pips(filled: 3, total: 5)
                        Spacer()
                        VoteStepper(value: votes, canAdd: votes < 5, label: "Totoro") { votes = $0 }
                    }
                }
                // The grid brings its own eyebrow.
                NotificationsGrid(rows: Self.notificationRows, set: { _, _, _ in }, openTip: Self.argument("-tip")).id("Notifications")
                section("Fields") {
                    FCField(label: "Your cat's name", text: $name, help: "You can add more cats later.")
                    FCField(label: "Password", text: $password, error: "Ten characters or more.", secure: true)
                }
                section("Faces and rosettes") {
                    HStack(spacing: 14) {
                        Avatar(kind: .person); Avatar(kind: .person, size: .md); Avatar(kind: .person, size: .lg)
                        Avatar(kind: .cat, size: .lg); Avatar(kind: .cat, size: .md); Avatar(kind: .cat)
                    }
                    HStack(alignment: .bottom, spacing: 14) {
                        Rosette(place: 1); Rosette(place: 2, height: 44); Rosette(place: 3, height: 38)
                    }
                }
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No loafs yet").type(.cardTitle).foregroundStyle(Tokens.ink)
                        Text("Be the first. A blurry loaf still counts as a loaf. You have 5 \(Tokens.votes(5)) to hand out.").type(.body).foregroundStyle(Tokens.muted)
                    }
                }
            }
            .padding(16)
        }
        .background(PageBackground())
    }

    private static let reactions: [Components.Schemas.ReactionView] = [
        .init(by: ["Dana", "Marcus", "you", "Rebecca"], count: 4, emoji: "😻", isMine: true),
        .init(by: ["Marcus"], count: 1, emoji: "😂", isMine: false),
    ]

    private static let notificationRows: [Components.Schemas.NotificationRow] = [
        .init(category: "round", channels: [.init(channel: "email", on: true)], events: ["A round opens", "Last-day reminder if you haven't posted", "Voting opens", "Results"], label: "Round events"),
        .init(category: "posts", channels: [.init(channel: "email", on: false)], events: ["A photo or video posted to your round"], label: "New posts"),
    ]

    /// The value after a launch flag (`-tip "New posts"`), or nil.
    private static func argument(_ flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.endIndex else { return nil }
        return args[i + 1]
    }

    private static func pending(media: Int64?, failure: String?) -> PendingPost {
        var p = PendingPost(league: "pine-st", categoryID: 1, categoryName: "Sploot", petID: 1, newCatName: nil, caption: "", created: .now)
        p.mediaID = media
        p.failure = failure
        return p
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { Eyebrow(title); content() }.id(title)
    }
}

/// The page: paper, and in dark mode a faint glow of the accent from above.
struct PageBackground: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ZStack(alignment: .top) {
            Tokens.paper
            EllipticalGradient(colors: [Tokens.accent.opacity(scheme == .dark ? Tokens.glowOpacity.dark : Tokens.glowOpacity.light), .clear], center: .top, endRadiusFraction: 0.9)
                .frame(height: 520)
                .offset(y: -120)
        }
        .ignoresSafeArea()
    }
}

#Preview("Light") { GalleryView() }
#Preview("Dark") { GalleryView().preferredColorScheme(.dark) }
