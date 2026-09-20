import SwiftUI

/// The league itself: how to invite people, who's in it, and the way out.
/// Admin settings and editing a round's categories still live on the web.
struct LeagueDetailsView: View {
    let store: LeagueStore
    let onLeft: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingLeave = false
    @State private var leaving = false
    @State private var failure: String?
    @State private var copied = false

    var body: some View {
        ScrollView {
            if let league = store.league {
                let link = Server.url.appending(path: "join/\(league.inviteCode)")
                VStack(alignment: .leading, spacing: 22) {
                    HStack { Spacer(); Button("Done") { dismiss() }.buttonStyle(.fc(size: .sm)) }
                    PageTitle(league.name, eyebrow: "League")
                    Card {
                        VStack(alignment: .leading, spacing: 12) {
                            Eyebrow("Invite friends")
                            Text(link.absoluteString).font(.system(size: 13, design: .monospaced)).foregroundStyle(Tokens.ink)
                                .padding(.horizontal, 12).padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                                .background(Tokens.sunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
                                .textSelection(.enabled)
                            // The share sheet is how a phone passes a link along: Messages, AirDrop, Copy.
                            ShareLink(item: link, subject: Text("Join \(league.name)"), message: Text("Come post your cat in \(league.name) on Fantasy Cat League.")) {
                                Text("Share invite link")
                            }
                            .buttonStyle(.fc(.primary, block: true))
                            Button(copied ? "Copied" : "Copy link") {
                                UIPasteboard.general.url = link
                                copied = true
                            }
                            .buttonStyle(.fc(size: .sm))
                            .sensoryFeedback(.success, trigger: copied)
                            Text("Anyone with the link can join." + (league.isAdmin ? " You can reset it at fantasycat.co if it gets out." : "")).type(.small).foregroundStyle(Tokens.muted)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow("\((league.members ?? []).count) managers")
                        ForEach(league.members ?? [], id: \.id) { m in
                            HStack(spacing: 10) {
                                Avatar(url: m.avatarUrl.flatMap(URL.init(string:)))
                                (Text(m.displayName).font(Font(TypeStyle.bodyStrong.uiFont())).foregroundStyle(Tokens.ink)
                                    + Text(" @\(m.username)").font(Font(TypeStyle.body.uiFont())).foregroundStyle(Tokens.muted)).lineLimit(1)
                                Spacer()
                                if m.isAdmin { Chip("admin", tone: .done) }
                            }
                            .padding(.vertical, 6)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Divider().overlay(Tokens.line)
                    if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
                    if league.isAdmin {
                        Text("You run this league. Its settings, and each round's categories until the first post lands, are at fantasycat.co.").type(.small).foregroundStyle(Tokens.muted)
                    } else {
                        Button("Leave league") { confirmingLeave = true }.buttonStyle(.fc(.danger, size: .sm, busy: leaving))
                            .confirmationDialog("Leave \(league.name)?", isPresented: $confirmingLeave, titleVisibility: .visible) {
                                Button("Leave league", role: .destructive) { leave() }
                            } message: { Text("Your posts and points stay. You can rejoin with an invite link.") }
                    }
                }
                .padding(20)
            }
        }
        .background(Tokens.paper)
    }

    private func leave() {
        leaving = true
        Task {
            do {
                switch try await API.client.leaveLeague(path: .init(slug: store.slug)) {
                case .noContent: dismiss(); onLeft()
                case .default(let status, let p): failure = Failure.from(status: status, try? p.body.applicationProblemJson).message
                }
            } catch { failure = Failure.from(error).message }
            leaving = false
        }
    }
}
