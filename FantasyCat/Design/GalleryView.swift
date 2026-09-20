import SwiftUI

/// Every component on one screen, for looking at. Launch with `-gallery`
/// (`make shot GALLERY=1`). The iOS counterpart of design/design-system.html
/// in the server repo: if the two disagree, that page wins.
struct GalleryView: View {
    @State private var name = "Totoro"
    @State private var password = ""
    @State private var votes = 2

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageTitle(eyebrow: "Round 3 of 8", title: "This week") { Chip("Open", tone: .live) }
                Banner(label: "Submissions close in", value: "2d 04:17", detail: "Saturday at 11:59 PM")
                Banner(label: "You earned", value: "+10", detail: "7 treats, 3 for showing up", inverted: false)
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
                section("Votes") {
                    HStack {
                        Pips(filled: 3, total: 5)
                        Spacer()
                        VoteStepper(value: votes, canAdd: votes < 5, label: "Totoro") { votes = $0 }
                    }
                }
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

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { Eyebrow(title); content() }
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
