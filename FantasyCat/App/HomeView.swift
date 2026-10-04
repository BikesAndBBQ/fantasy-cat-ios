import SwiftUI

/// Signed in. With one league (nearly everyone) this is that league; otherwise,
/// or when asked for, the place to pick, start or join one.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    let user: Components.Schemas.UserView
    let leagues: [Components.Schemas.LeagueSummary]
    @State private var chosen: String? = {
        let args = ProcessInfo.processInfo.arguments // debug: `-pickleague <slug>`
        return args.firstIndex(of: "-pickleague").flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil }
    }()
    @State private var picking = ProcessInfo.processInfo.arguments.contains("-leagues") // debug: open the chooser
    @State private var account = false
    /// An invite link the app was opened with, filled into the join field.
    @State private var invite: String?

    var body: some View {
        let slug = chosen.flatMap { c in leagues.contains { $0.slug == c } ? c : nil } ?? (leagues.count == 1 ? leagues[0].slug : nil)
        Group {
            if let slug, !picking, model.pendingInvite == nil {
                LeagueShell(slug: slug, user: user, onLeagues: { picking = true }).id(slug)
            } else {
                LeaguesView(user: user, leagues: leagues, choose: { chosen = $0; picking = false; invite = nil }, openAccount: { account = true }, link: invite)
                    .sheet(isPresented: $account) { AccountView() }
            }
        }
        // An invite link, whenever it comes: the join field, filled in, one tap
        // from joining (as the web's /join/<code> is).
        .onChange(of: model.pendingInvite, initial: true) { _, code in
            guard let code else { return }
            invite = code
            picking = true
            model.pendingInvite = nil
        }
    }
}

extension Components.Schemas.LeagueView: Identifiable {
    var id: String { slug }
}
