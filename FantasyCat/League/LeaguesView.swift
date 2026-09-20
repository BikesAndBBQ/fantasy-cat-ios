import SwiftUI

/// Pick a league, start one, or join one with an invite. Shown when you have
/// none or several, and from the account screen.
struct LeaguesView: View {
    @Environment(AppModel.self) private var model
    let user: Components.Schemas.UserView
    let leagues: [Components.Schemas.LeagueSummary]
    let choose: (String) -> Void
    var openAccount: () -> Void = {}

    @State private var name = ""
    @State private var invite = ""
    @State private var starting = false
    @State private var joining = false
    @State private var failure: String?
    @State private var preview: Components.Schemas.InviteOutputBody?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LeagueHeader(name: "Fantasy Cat League", avatar: user.avatarUrl.flatMap(URL.init(string:)), openAccount: openAccount)
                PageTitle(leagues.isEmpty ? "Find your league" : "Your leagues", eyebrow: leagues.isEmpty ? "Welcome, \(user.displayName)" : nil)
                if leagues.isEmpty {
                    Text("Start one and invite your friends, or join theirs.").type(.body).foregroundStyle(Tokens.muted)
                }
                ForEach(leagues, id: \.slug) { league in
                    Button { choose(league.slug) } label: {
                        Card {
                            HStack {
                                Text(league.name).type(.bodyStrong).foregroundStyle(Tokens.ink)
                                if league.isAdmin { Chip("admin", tone: .done) }
                                Spacer()
                                Text("\(league.memberCount) managers").type(.small).foregroundStyle(Tokens.muted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }

                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow("Join with an invite")
                    FCField(label: "Invite link or code", text: $invite, help: preview.map { "\($0.leagueName), run by \($0.adminName). \($0.memberCount) in so far." })
                        .onChange(of: invite) { _, _ in Task { await lookUp() } }
                    Button(preview.map { "Join \($0.leagueName)" } ?? "Join") { join() }
                        .buttonStyle(.fc(.ink, block: true, busy: joining)).disabled(code.isEmpty || joining)
                        .accessibilityIdentifier("join-league")
                }
                Divider().overlay(Tokens.line)
                VStack(alignment: .leading, spacing: 12) {
                    Eyebrow("Start a league")
                    FCField(label: "League name", text: $name, help: "Round deadlines will follow your time zone (\(TimeZone.current.identifier)).")
                    Button("Start the league") { start() }
                        .buttonStyle(.fc(.primary, block: true, busy: starting)).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || starting)
                        .accessibilityIdentifier("start-league")
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PageBackground())
        #if DEBUG
        .task {
            // `-startleague <name>` / `-joinleague <code>`: the buttons, from the command line.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-startleague"), args.indices.contains(i + 1) { name = args[i + 1]; start() }
            if let i = args.firstIndex(of: "-joinleague"), args.indices.contains(i + 1) { invite = args[i + 1]; await lookUp(); if !args.contains("-nojoin") { join() } }
        }
        #endif
    }

    /// People paste the whole link; the code is its last path component.
    private var code: String {
        let t = invite.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: t), url.scheme != nil, let last = url.pathComponents.last, last != "/" { return last.lowercased() }
        return t.lowercased()
    }

    private func lookUp() async {
        let c = code
        guard c.count >= 4 else { preview = nil; return }
        if case .ok(let ok) = try? await API.client.previewInvite(path: .init(code: c)), let body = try? ok.body.json, c == code { preview = body } else if c == code { preview = nil }
    }

    private func join() {
        joining = true
        failure = nil
        Task {
            do {
                switch try await API.client.joinLeague(body: .json(.init(inviteCode: code))) {
                case .ok(let ok):
                    let league = try ok.body.json
                    await model.reload()
                    choose(league.slug)
                case .default(let status, let p): failure = Failure.from(status: status, try? p.body.applicationProblemJson).message
                }
            } catch { failure = Failure.from(error).message }
            joining = false
        }
    }

    private func start() {
        starting = true
        failure = nil
        Task {
            do {
                switch try await API.client.createLeague(body: .json(.init(name: name.trimmingCharacters(in: .whitespaces), timezone: TimeZone.current.identifier))) {
                case .created(let c):
                    let league = try c.body.json
                    await model.reload()
                    choose(league.slug)
                case .default(let status, let p): failure = Failure.from(status: status, try? p.body.applicationProblemJson).message
                }
            } catch { failure = Failure.from(error).message }
            starting = false
        }
    }
}
