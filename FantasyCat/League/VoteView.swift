import FantasyCatCore
import SwiftUI

struct VoteView: View {
    let store: LeagueStore
    let header: LeagueHeader
    @State private var index = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header.id("top")
                    if let league = store.league {
                        if let round = store.votingRound, let cats = round.categories, !cats.isEmpty {
                            let i = min(index, cats.count - 1)
                            voting(league, round, cats, i) { withAnimation { index = i + 1; proxy.scrollTo("top", anchor: .top) } }
                        } else {
                            nothingYet(league)
                        }
                    } else {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                    }
                }
                .padding(16)
            }
        }
        .background(PageBackground())
        .refreshable { await store.refresh() }
    }

    @ViewBuilder private func voting(_ league: League, _ round: Components.Schemas.RoundView, _ cats: [Components.Schemas.CategoryView], _ i: Int, next: @escaping () -> Void) -> some View {
        PageTitle(eyebrow: "Round \(round.number), category \(i + 1) of \(cats.count)", title: cats[i].name) {
            TimelineView(.periodic(from: .now, by: 1)) { t in Chip(TimeText.countdown(to: round.voteCloseAt, now: t.date), tone: .live).monospacedDigit() }
        }
        HStack(alignment: .top, spacing: 6) {
            ForEach(Array(cats.enumerated()), id: \.element.id) { n, c in
                Button { index = n } label: {
                    VStack(spacing: 4) {
                        Capsule().fill(n == i ? Tokens.ink : c.myVotesSpent > 0 ? Tokens.nose : Tokens.line).frame(height: 6)
                        Text(c.name).type(.caption).foregroundStyle(n == i ? Tokens.ink : Tokens.muted).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(c.name)\(c.myVotesSpent > 0 ? ", voted" : "")")
                .accessibilityAddTraits(n == i ? .isSelected : [])
            }
        }
        BallotPanel(store: store, categoryID: cats[i].id, nextName: i < cats.count - 1 ? cats[i + 1].name : nil, next: next)
            .id(cats[i].id)
    }

    @ViewBuilder private func nothingYet(_ league: League) -> some View {
        PageTitle("Nothing to vote on yet", eyebrow: "Voting")
        if let open = league.currentRound, open.status == .submitting {
            TimelineView(.periodic(from: .now, by: 1)) { t in
                Banner(label: "Voting opens in", value: TimeText.countdown(to: open.submitCloseAt, now: t.date),
                       detail: "When round \(open.number) stops taking posts, \(TimeText.deadline(open.submitCloseAt))")
            }
        } else {
            EmptyState("Between rounds", "Check back when the next round closes.")
        }
        Text("Everyone gets \(league.voteBudget) \(Tokens.votes(Int(league.voteBudget))) per category, to split however they like. You can't vote for your own posts.")
            .type(.body).foregroundStyle(Tokens.muted)
    }
}

/// One category's ballot. Local allocations are the truth while voting, so every
/// tap is instant; they're saved a moment after the last one.
private struct BallotPanel: View {
    let store: LeagueStore
    let categoryID: Int64
    let nextName: String?
    let next: () -> Void

    @State private var points: [Int64: Int]?
    @State private var saveTask: Task<Void, Never>?
    @State private var status = ""
    @State private var failure: String?
    @State private var open: Submission?

    var body: some View {
        Group {
            if let ballot = store.ballots[categoryID], let points {
                let entries = ballot.entries ?? []
                if entries.isEmpty {
                    EmptyState("Nothing to vote on here", "Only your own posts are in this category, and those are off limits.")
                    nextButton
                } else {
                    let spent = points.values.reduce(0, +)
                    let budget = Int(ballot.budget)
                    let left = budget - spent
                    budgetBar(left: left, spent: spent, budget: budget)
                    if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
                    ForEach(entries, id: \.submission.id) { e in
                        row(e.submission, mine: points[e.submission.id] ?? 0, left: left, cap: ballot.maxPerSubmission.map(Int.init) ?? budget)
                    }
                    if nextName != nil { nextButton } else {
                        Text("That's every category. Change your mind any time before voting closes.").type(.small).foregroundStyle(Tokens.muted).frame(maxWidth: .infinity)
                    }
                }
            } else if let failure {
                EmptyState("Couldn't load your ballot", failure)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            }
        }
        .task {
            failure = await store.loadBallot(categoryID)
            if let b = store.ballots[categoryID] { points = Dictionary(uniqueKeysWithValues: (b.entries ?? []).map { ($0.submission.id, Int($0.points)) }) }
            #if DEBUG
            // `-autovote`: give the first entry two and the second one, as taps would.
            if ProcessInfo.processInfo.arguments.contains("-autovote"), let ids = store.ballots[categoryID]?.entries?.map(\.submission.id), ids.count >= 2, (points?.values.reduce(0, +) ?? 0) == 0 {
                change(ids[0], 1); try? await Task.sleep(for: .milliseconds(150)); change(ids[0], 2); change(ids[1], 1)
            }
            #endif
        }
        .onDisappear { flush() }
        .sheet(item: $open) { s in SubmissionSheet(submission: s, canDelete: false, store: store) }
    }

    private func budgetBar(left: Int, spent: Int, budget: Int) -> some View {
        HStack {
            (Text("\(left)").font(Font(TypeStyle.scoreSmall.uiFont())).foregroundStyle(Tokens.ink) + Text(" \(Tokens.votes(left)) left").font(Font(TypeStyle.body.uiFont())).foregroundStyle(Tokens.ink))
                .monospacedDigit().contentTransition(.numericText(value: Double(left)))
            Spacer()
            Text(status).type(.small).foregroundStyle(Tokens.muted)
            Pips(filled: spent, total: budget)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).strokeBorder(Tokens.line, lineWidth: 1) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(left) \(Tokens.votes(left)) left of \(budget)")
    }

    private func row(_ s: Submission, mine: Int, left: Int, cap: Int) -> some View {
        HStack(spacing: 12) {
            Button { open = s } label: { MediaTile(media: s.media, square: true, radius: Tokens.Radius.field).frame(width: 92) }
                .buttonStyle(.plain).accessibilityLabel("Look at \(s.petName)")
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(s.petName).type(.bodyStrong).foregroundStyle(Tokens.ink).lineLimit(1)
                    Text(s.manager.displayName).type(.small).foregroundStyle(Tokens.muted)
                }
                HStack {
                    Pips(filled: mine, popLast: true)
                    Spacer(minLength: 4)
                    VoteStepper(value: mine, canAdd: left > 0 && mine < cap, label: s.petName) { change(s.id, $0) }
                }
            }
        }
        .padding(8)
        .background(Tokens.surface, in: RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).strokeBorder(Tokens.line, lineWidth: 1) }
    }

    @ViewBuilder private var nextButton: some View {
        if let nextName { Button("Next: \(nextName)") { flush(); next() }.buttonStyle(.fc(.ink, block: true)) }
    }

    private func change(_ id: Int64, _ n: Int) {
        points?[id] = n
        failure = nil
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(600))
            if !Task.isCancelled { await save() }
        }
    }

    /// Leaving the category with a save still waiting: send it now.
    private func flush() {
        guard saveTask != nil, let points else { return } // nil once a save has gone out
        saveTask?.cancel()
        saveTask = nil
        let snapshot = points
        Task { _ = await store.saveBallot(categoryID, points: snapshot) }
    }

    private func save() async {
        guard let snapshot = points else { return }
        status = "Saving…"
        if let problem = await store.saveBallot(categoryID, points: snapshot) {
            failure = problem
            status = ""
            // Fall back to what the server has.
            if let b = store.ballots[categoryID] { points = Dictionary(uniqueKeysWithValues: (b.entries ?? []).map { ($0.submission.id, Int($0.points)) }) }
        } else if points == snapshot {
            status = "Saved"
        }
        saveTask = nil
    }
}
