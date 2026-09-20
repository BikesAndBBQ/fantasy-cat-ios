import SwiftUI

/// Signed in. A holding screen until milestone 3 builds the league: it proves
/// the session round-trips and gives a way back out.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    let user: Components.Schemas.UserView
    let leagues: [Components.Schemas.LeagueSummary]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 14) {
                    Avatar(url: user.avatarUrl.flatMap(URL.init(string:)), size: .lg)
                    PageTitle(user.displayName, eyebrow: "@\(user.username)")
                }
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow(leagues.isEmpty ? "No leagues yet" : "Your leagues")
                    ForEach(leagues, id: \.slug) { league in
                        Card {
                            HStack {
                                Text(league.name).type(.bodyStrong).foregroundStyle(Tokens.ink)
                                Spacer()
                                Text("\(league.memberCount) managers").type(.small).foregroundStyle(Tokens.muted)
                            }
                        }
                    }
                }
                Button("Sign out") { Task { await model.signOut() } }
                    .buttonStyle(.fc(size: .sm))
                    .accessibilityIdentifier("sign-out")
            }
            .padding(16)
        }
        .background(PageBackground())
    }
}
