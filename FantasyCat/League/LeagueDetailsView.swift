import SwiftUI

/// The league itself: how to invite people, who's in it, and the way out.
/// The admin can also change an open round's categories (until the first post
/// lands), reset the invite link, and change the league's settings.
struct LeagueDetailsView: View {
    let store: LeagueStore
    let onLeft: () -> Void
    /// The league list shows the name, so a rename reloads it.
    var onSaved: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingLeave = false
    @State private var leaving = false
    @State private var failure: String?
    @State private var copied = false
    @State private var confirmingRotate = false
    @State private var rotating = false

    var body: some View {
        ScrollViewReader { proxy in
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
                            Text("Anyone with the link can join." + (league.isAdmin ? " You can reset it below if it gets out." : "")).type(.small).foregroundStyle(Tokens.muted)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Eyebrow((league.members ?? []).count == 1 ? "1 manager" : "\((league.members ?? []).count) managers")
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
                        if let round = league.currentRound, round.canEditCategories { CategoryEditor(store: store, round: round) }
                        SettingsEditor(store: store, league: league, onSaved: onSaved).id("settings")
                        Divider().overlay(Tokens.line)
                        VStack(alignment: .leading, spacing: 10) {
                            Eyebrow("Invite link")
                            Text("If the link has reached someone it shouldn't, reset it. The old one stops working at once.").type(.small).foregroundStyle(Tokens.muted)
                            Button("Reset invite link") { confirmingRotate = true }.buttonStyle(.fc(size: .sm, busy: rotating))
                                .confirmationDialog("Reset the invite link?", isPresented: $confirmingRotate, titleVisibility: .visible) {
                                    Button("Reset link", role: .destructive) {
                                        rotating = true
                                        Task { failure = await store.rotateInvite(); copied = false; rotating = false }
                                    }
                                } message: { Text("Anyone who hasn't joined yet will need the new one.") }
                        }
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
        #if DEBUG
        .task(id: store.league == nil) { if ProcessInfo.processInfo.arguments.contains("-leaguesettings") { proxy.scrollTo("settings", anchor: .top) } } // debug: show the settings
        #endif
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

/// The same settings as the web's league page. Fields hold text so a cleared
/// posts limit can mean unlimited; the server checks every range on save.
private struct SettingsEditor: View {
    let store: LeagueStore
    let league: League
    let onSaved: () -> Void
    @State private var name = ""
    @State private var seasonRounds = ""
    @State private var voteBudget = ""
    @State private var submissionCap = ""
    @State private var saving = false
    @State private var failure: String?
    @State private var saved = false

    private var trimmed: (name: String, rounds: Int64?, budget: Int64?, cap: String) {
        (name.trimmingCharacters(in: .whitespaces), Int64(seasonRounds.trimmingCharacters(in: .whitespaces)),
         Int64(voteBudget.trimmingCharacters(in: .whitespaces)), submissionCap.trimmingCharacters(in: .whitespaces))
    }
    private var capInvalid: Bool { !trimmed.cap.isEmpty && Int64(trimmed.cap) == nil }
    private var unchanged: Bool {
        trimmed.name == league.name && trimmed.rounds == league.seasonRounds && trimmed.budget == league.voteBudget
            && (trimmed.cap.isEmpty ? nil : Int64(trimmed.cap)) == league.submissionCap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Settings")
            if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
            FCField(label: "League name", text: $name)
            HStack(alignment: .top, spacing: 12) {
                FCField(label: "Rounds in a season", text: $seasonRounds, keyboard: .numberPad)
                FCField(label: "\(Tokens.votes(2).capitalized) per category", text: $voteBudget, keyboard: .numberPad)
            }
            FCField(label: "Posts allowed per category", text: $submissionCap,
                    help: "Per manager. Leave empty for no limit.", error: capInvalid ? "A whole number, or empty for no limit." : nil, keyboard: .numberPad)
            Button(saved ? "Saved" : "Save settings") { save() }
                .buttonStyle(.fc(.ink, size: .sm, busy: saving))
                .disabled(saving || trimmed.name.isEmpty || trimmed.rounds == nil || trimmed.budget == nil || capInvalid || unchanged)
        }
        .onChange(of: [name, seasonRounds, voteBudget, submissionCap]) { saved = false }
        .task {
            name = league.name
            seasonRounds = String(league.seasonRounds)
            voteBudget = String(league.voteBudget)
            submissionCap = league.submissionCap.map(String.init) ?? ""
            #if DEBUG
            // `-setvotebudget <n>`: change the vote budget and save, as the button would.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-setvotebudget"), args.indices.contains(i + 1), voteBudget != args[i + 1] {
                voteBudget = args[i + 1]
                save()
            }
            #endif
        }
    }

    private func save() {
        let t = trimmed
        guard let rounds = t.rounds, let budget = t.budget else { return }
        saving = true
        Task {
            // The per-post vote limit has no field here or on the web; send it back as it is.
            failure = await store.updateSettings(.init(name: t.name, seasonRounds: rounds, submissionCap: Int64(t.cap),
                                                       voteBudget: budget, voteMaxPerSubmission: league.voteMaxPerSubmission))
            saving = false
            if failure == nil { saved = true; onSaved() }
        }
    }
}

/// Yours to change until the first post lands, then they lock: the server
/// says when (`canEditCategories`) and has the last word on every save.
private struct CategoryEditor: View {
    let store: LeagueStore
    let round: Components.Schemas.RoundView
    @State private var names: [String] = []
    @State private var saving = false
    @State private var failure: String?
    @State private var saved = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Round \(round.number) categories")
            Text("Yours to change until the first post lands, then they lock.").type(.small).foregroundStyle(Tokens.muted)
            if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
            ForEach(names.indices, id: \.self) { i in
                HStack(alignment: .bottom, spacing: 8) {
                    FCField(label: "Category \(i + 1)", text: $names[i])
                    Menu {
                        ForEach(store.categoryPool.filter { !names.contains($0) }, id: \.self) { idea in Button(idea) { names[i] = idea; saved = false } }
                    } label: {
                        Image(systemName: "dice").font(.system(size: 16, weight: .semibold)).foregroundStyle(Tokens.ink)
                            .frame(width: 44, height: 44).background(Tokens.sunken, in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
                    }
                    .accessibilityLabel("Ideas for category \(i + 1)")
                }
            }
            Button(saved ? "Saved" : "Save categories") {
                saving = true
                Task {
                    failure = await store.setCategories(round: round.number, names: names.map { $0.trimmingCharacters(in: .whitespaces) })
                    saved = failure == nil
                    saving = false
                }
            }
            .buttonStyle(.fc(.ink, size: .sm, busy: saving))
            .disabled(saving || names.contains { $0.trimmingCharacters(in: .whitespaces).isEmpty } || names == (round.categories ?? []).map(\.name))
        }
        .task {
            names = (round.categories ?? []).map(\.name)
            await store.loadCategoryPool()
            #if DEBUG
            // `-setcategory <name>`: rename the first category and save, as the button would.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-setcategory"), args.indices.contains(i + 1), !names.isEmpty, names[0] != args[i + 1] {
                names[0] = args[i + 1]
                failure = await store.setCategories(round: round.number, names: names)
                saved = failure == nil
            }
            #endif
        }
    }
}
