import SwiftUI

/// One league: This week, Vote, Results, Standings, in the web's order.
/// A native tab bar rather than a copy of the web's: on iOS that is the
/// platform's own navigation, and it gets the system's look for free.
struct LeagueShell: View {
    @State private var store: LeagueStore
    @State private var tab: Tab
    @State private var account = false
    let user: Components.Schemas.UserView
    var onLeagues: (() -> Void)?

    enum Tab: String { case week, vote, results, standings }

    init(slug: String, user: Components.Schemas.UserView, onLeagues: (() -> Void)? = nil) {
        self.onLeagues = onLeagues
        _store = State(initialValue: LeagueStore(slug: slug))
        self.user = user
        let args = ProcessInfo.processInfo.arguments
        let asked = args.firstIndex(of: "-tab").flatMap { args.indices.contains($0 + 1) ? Tab(rawValue: args[$0 + 1]) : nil }
        _tab = State(initialValue: asked ?? .week) // `-tab results`: debug convenience, harmless in release
        _account = State(initialValue: args.contains("-account"))
    }

    var body: some View {
        TabView(selection: $tab) {
            ThisWeekView(store: store, header: header) { tab = .vote }.tabItem { Label("This week", systemImage: "pawprint.fill") }.tag(Tab.week)
            VoteView(store: store, header: header).tabItem { Label("Vote", systemImage: "heart.fill") }.tag(Tab.vote)
                .badge(store.categoriesLeftToVote)
            ResultsView(store: store, header: header).tabItem { Label("Results", systemImage: "rosette") }.tag(Tab.results)
            StandingsView(store: store, header: header).tabItem { Label("Standings", systemImage: "list.number") }.tag(Tab.standings)
        }
        .tint(Tokens.accentInk)
        .task {
            // Round phases flip at midnight; keep an open app honest, as the web does.
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .sheet(isPresented: $account) { AccountView(onLeagues: onLeagues) }
    }

    private var header: LeagueHeader { LeagueHeader(name: store.league?.name ?? "", avatar: user.avatarUrl.flatMap(URL.init(string:))) { account = true } }
}

/// League name on the left, your face on the right: the top row of every league
/// screen, as on the web. It lives in the page, not the navigation bar, where
/// iOS would wrap each item in its own glass capsule and truncate the name.
struct LeagueHeader: View {
    let name: String
    let avatar: URL?
    let openAccount: () -> Void

    var body: some View {
        HStack {
            Eyebrow(name).lineLimit(1)
            Spacer()
            Button(action: openAccount) { Avatar(url: avatar, size: .sm).frame(width: 30, height: 30).scaleEffect(30 / 26) }
                .frame(width: 44, height: 44, alignment: .trailing).contentShape(Rectangle())
                .accessibilityLabel("Your account")
        }
        .padding(.bottom, -4)
    }
}

