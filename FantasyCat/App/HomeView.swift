import SwiftUI

/// Signed in. With one league (nearly everyone) this is that league; with
/// several, a list to choose from; with none, where to go to get one.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    let user: Components.Schemas.UserView
    let leagues: [Components.Schemas.LeagueSummary]
    @State private var chosen: String?

    var body: some View {
        if let slug = chosen ?? (leagues.count == 1 ? leagues[0].slug : nil) {
            LeagueShell(slug: slug, user: user).id(slug)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 14) {
                        Avatar(url: user.avatarUrl.flatMap(URL.init(string:)), size: .lg)
                        PageTitle(user.displayName, eyebrow: "@\(user.username)")
                    }
                    if leagues.isEmpty {
                        EmptyState("No league yet", "Start one, or join with a friend's invite link, at fantasycat.co. It will show up here.")
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow("Your leagues")
                            ForEach(leagues, id: \.slug) { league in
                                Button { chosen = league.slug } label: {
                                    Card {
                                        HStack {
                                            Text(league.name).type(.bodyStrong).foregroundStyle(Tokens.ink)
                                            Spacer()
                                            Text("\(league.memberCount) managers").type(.small).foregroundStyle(Tokens.muted)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button("Sign out") { Task { await model.signOut() } }.buttonStyle(.fc(size: .sm)).accessibilityIdentifier("sign-out")
                }
                .padding(16)
            }
            .background(PageBackground())
        }
    }
}

extension Components.Schemas.LeagueView: Identifiable {
    var id: String { slug }
}
