import SwiftUI

/// One league: This week, Results, Standings. (Voting joins them in milestone 5.)
/// A native tab bar rather than a copy of the web's: on iOS that is the
/// platform's own navigation, and it gets the system's look for free.
struct LeagueShell: View {
    @State private var store: LeagueStore
    @State private var tab: Tab
    @State private var account = false
    let user: Components.Schemas.UserView

    enum Tab: String { case week, results, standings }

    init(slug: String, user: Components.Schemas.UserView) {
        _store = State(initialValue: LeagueStore(slug: slug))
        self.user = user
        let args = ProcessInfo.processInfo.arguments
        let asked = args.firstIndex(of: "-tab").flatMap { args.indices.contains($0 + 1) ? Tab(rawValue: args[$0 + 1]) : nil }
        _tab = State(initialValue: asked ?? .week) // `-tab results`: debug convenience, harmless in release
    }

    var body: some View {
        TabView(selection: $tab) {
            ThisWeekView(store: store, header: header).tabItem { Label("This week", systemImage: "pawprint.fill") }.tag(Tab.week)
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
        .sheet(isPresented: $account) { AccountSheet(user: user) }
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

/// Who you are, and the way out. The full account screen comes later.
struct AccountSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let user: Components.Schemas.UserView

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 14) {
                Avatar(url: user.avatarUrl.flatMap(URL.init(string:)), size: .lg)
                PageTitle(user.displayName, eyebrow: "@\(user.username)")
            }
            Text("Cats, your picture, passkeys and reminders are managed at fantasycat.co for now.").type(.small).foregroundStyle(Tokens.muted)
            HStack {
                Button("Sign out") { Task { dismiss(); await model.signOut() } }.buttonStyle(.fc(.danger, size: .sm)).accessibilityIdentifier("sign-out")
                Spacer()
                Button("Done") { dismiss() }.buttonStyle(.fc(size: .sm))
            }
            Spacer()
        }
        .padding(20)
        .background(Tokens.paper)
        .presentationDetents([.medium])
    }
}
