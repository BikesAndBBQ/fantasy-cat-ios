import SwiftUI

/// Signed in. A holding screen until milestone 3 builds the league: it proves
/// the session round-trips and gives a way back out.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    let user: Components.Schemas.UserView
    let leagues: [Components.Schemas.LeagueSummary]
    @State private var posting: Components.Schemas.LeagueView?
    @State private var opening: String?
    @State private var failure: String?
    @State private var autopost: URL?

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
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(league.name).type(.bodyStrong).foregroundStyle(Tokens.ink)
                                    Text("\(league.memberCount) managers").type(.small).foregroundStyle(Tokens.muted)
                                }
                                Spacer()
                                Button("Post") { Task { await open(league.slug) } }
                                    .buttonStyle(.fc(.primary, size: .sm, busy: opening == league.slug))
                                    .accessibilityIdentifier("post-\(league.slug)")
                            }
                        }
                    }
                }
                if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
                Button("Sign out") { Task { await model.signOut() } }
                    .buttonStyle(.fc(size: .sm))
                    .accessibilityIdentifier("sign-out")
            }
            .padding(16)
        }
        .background(PageBackground())
        .sheet(item: $posting) { league in PostView(league: league, autopost: autopost) }
        #if DEBUG
        .task {
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "-autopost"), args.indices.contains(i + 1), let first = leagues.first else { return }
            autopost = URL(fileURLWithPath: args[i + 1])
            await open(first.slug)
        }
        #endif
    }

    /// The post screen needs the league's open round and its categories.
    private func open(_ slug: String) async {
        opening = slug
        failure = nil
        defer { opening = nil }
        do {
            switch try await API.client.getLeague(path: .init(slug: slug)) {
            case .ok(let ok): posting = try ok.body.json
            case .default(let status, let problem): failure = Failure.from(status: status, try? problem.body.applicationProblemJson).message
            }
        } catch { failure = Failure.from(error).message }
    }
}

extension Components.Schemas.LeagueView: Identifiable {
    var id: String { slug }
}
