import SwiftUI

struct ThisWeekView: View {
    let store: LeagueStore
    let header: LeagueHeader
    @State private var categoryID: Int64?
    @State private var open: Submission?
    @State private var posting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let league = store.league {
                    if let round = league.currentRound {
                        if round.status == .final, round.number >= league.seasonRounds {
                            seasonComplete(league)
                        } else {
                            content(league, round)
                        }
                    } else {
                        EmptyState("No round yet", "The first round opens as soon as the league is created.")
                    }
                } else if let failure = store.failure {
                    EmptyState("Couldn't load the league", failure)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                }
            }
            .padding(16)
            .padding(.bottom, 72) // room for the Post button
        }
        .background(PageBackground())
        .refreshable { await store.refresh(); if let id = activeID { await store.loadFeed(id) } }
        .overlay(alignment: .bottomTrailing) {
            if store.league?.currentRound?.status == .submitting {
                Button("Post") { posting = true }
                    .buttonStyle(.fc(.primary))
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 6)
                    .padding(16)
                    .accessibilityIdentifier("post")
            }
        }
        .sheet(item: $open) { s in SubmissionSheet(submission: s, canDelete: store.league?.currentRound?.status == .submitting, store: store) }
        .sheet(isPresented: $posting, onDismiss: { Task { await store.refresh(); if let id = activeID { await store.loadFeed(id) } } }) {
            if let league = store.league { PostView(league: league, category: activeID) }
        }
        .task(id: activeID) { if let id = activeID { await store.loadFeed(id) } }
        #if DEBUG
        // `-autopost <file>` opens the post screen as soon as the league has loaded; `-open` opens the first post.
        .task(id: store.league?.slug) {
            let args = ProcessInfo.processInfo.arguments
            guard store.league != nil else { return }
            if args.contains("-autopost") { posting = true }
            if args.contains("-open"), let id = activeID {
                await store.loadFeed(id)
                open = store.feeds[id]?.submissions?.first
            }
        }
        #endif
    }

    private var activeID: Int64? { categoryID ?? store.league?.currentRound?.categories?.first?.id }

    @ViewBuilder private func content(_ league: League, _ round: Components.Schemas.RoundView) -> some View {
        let submitting = round.status == .submitting
        PageTitle(eyebrow: "Round \(round.number) of \(league.seasonRounds)", title: "This week") {
            Chip(submitting ? "Open" : round.status == .voting ? "Voting" : "Closed", tone: submitting ? .live : .done)
        }
        if submitting {
            TimelineView(.periodic(from: .now, by: 1)) { t in
                Banner(label: "Submissions close in", value: TimeText.countdown(to: round.submitCloseAt, now: t.date), detail: TimeText.deadline(round.submitCloseAt))
            }
        } else {
            Banner(label: "This round", value: round.status == .voting ? "VOTE" : "FINAL", detail: "Submissions are closed")
        }
        if let voting = store.rounds.first(where: { $0.status == .voting }), voting.number != round.number {
            Card {
                (Text("Round \(voting.number) is in voting. ").font(Font(TypeStyle.bodyStrong.uiFont())).foregroundStyle(Tokens.ink)
                    + Text("Hand out your \(Tokens.votes(5)) on the web for now; voting in the app is next.").font(Font(TypeStyle.body.uiFont())).foregroundStyle(Tokens.muted))
            }
        }
        let cats = round.categories ?? []
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(cats, id: \.id) { c in
                    Button { categoryID = c.id } label: { Chip("\(c.name)  \(c.submissionCount)", tone: c.id == activeID ? .selected : .default) }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(c.name), \(c.submissionCount) posts")
                        .accessibilityAddTraits(c.id == activeID ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
        if let active = cats.first(where: { $0.id == activeID }) { feed(active, submitting: submitting) }
    }

    @ViewBuilder private func feed(_ category: Components.Schemas.CategoryView, submitting: Bool) -> some View {
        if let feed = store.feeds[category.id] {
            let items = feed.submissions ?? []
            if items.isEmpty {
                EmptyState(title: "No \(category.name.lowercased()) yet", message: "Be the first. A blurry one still counts.") {
                    if submitting { Button("Post the first one") { posting = true }.buttonStyle(.fc(size: .sm)) }
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 12) {
                    ForEach(items) { s in
                        Button { open = s } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                MediaTile(media: s.media)
                                (Text(s.petName).font(Font(TypeStyle.smallStrong.uiFont())).foregroundStyle(Tokens.ink)
                                    + Text(" \(s.isMine ? "you" : s.manager.displayName)").font(Font(TypeStyle.small.uiFont())).foregroundStyle(Tokens.muted))
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(s.petName), posted by \(s.isMine ? "you" : s.manager.displayName)")
                    }
                }
                if let cap = feed.cap {
                    Text("You've posted \(feed.myCount) of \(cap) in \(category.name).").type(.small).foregroundStyle(Tokens.muted).frame(maxWidth: .infinity)
                }
            }
        } else {
            ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
        }
    }

    @ViewBuilder private func seasonComplete(_ league: League) -> some View {
        let champions = (store.standings?.standings ?? []).filter { $0.rank == 1 }
        PageTitle(champions.isEmpty ? "That's a wrap" : "\(champions.map(\.manager.displayName).joined(separator: " and ")) \(champions.count > 1 ? "share" : "takes") the season", eyebrow: "\(league.seasonRounds) rounds")
        Text("Every round is scored. The final table is under Standings.").type(.body).foregroundStyle(Tokens.muted)
            .task { await store.loadStandings() }
    }
}
