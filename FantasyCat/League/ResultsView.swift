import SwiftUI

struct ResultsView: View {
    let store: LeagueStore
    let header: LeagueHeader
    @State private var picked: Int64?
    @State private var open: Submission?

    private var number: Int64? { picked ?? store.finalRounds.first?.number }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let number, let league = store.league {
                    if store.finalRounds.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(store.finalRounds, id: \.number) { r in
                                    Button { picked = r.number } label: { Chip("Round \(r.number)", tone: r.number == number ? .selected : .default) }.buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.horizontal, -16)
                    }
                    PageTitle(eyebrow: "Round \(number) of \(league.seasonRounds)", title: "Results") { Chip("Final", tone: .done) }
                    if let r = store.results[number] { round(r) } else { ProgressView().frame(maxWidth: .infinity).padding(.top, 60) }
                } else if store.league != nil {
                    PageTitle("Results", eyebrow: "Season")
                    EmptyState("No results yet", "They post when a round's voting closes, at midnight on Monday.")
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                }
            }
            .padding(16)
        }
        .background(PageBackground())
        .refreshable { await store.refresh(); if let number { await store.loadResults(number) } }
        .task(id: number) { if let number { await store.loadResults(number) } }
        .sheet(item: $open) { s in SubmissionSheet(submission: s, canDelete: false, store: store) }
    }

    @ViewBuilder private func round(_ r: Components.Schemas.ResultsOutputBody) -> some View {
        if let me = r.scores?.first(where: \.isMe) {
            let detail = "\(me.votePoints) \(Tokens.votes(Int(me.votePoints))), \(me.participationPoints) for showing up" + (me.winPoints > 0 ? ", \(me.winPoints) for winning" : "")
            Banner(label: "You earned", value: "+\(me.total)", detail: detail, inverted: false)
        }
        ForEach(r.categories ?? [], id: \.categoryId) { c in
            let entries = c.entries ?? []
            let winners = entries.filter { $0.place == 1 }
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(c.category)
                if winners.isEmpty {
                    EmptyState("No winner", entries.isEmpty ? "Nobody posted in this one." : "Nobody spent any \(Tokens.votes(2)) here.")
                } else {
                    Text(winners.count == 1 ? "\(winners[0].submission.petName) takes \(c.category.lowercased())"
                                            : "\(winners.map(\.submission.petName).joined(separator: " and ")) share \(c.category.lowercased())")
                        .type(TypeStyle(face: .display, size: 24, weight: 800, relativeTo: .title2, tracking: -0.025)).foregroundStyle(Tokens.ink)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: winners.count > 1 ? 2 : 1), spacing: 10) {
                        ForEach(winners, id: \.submission.id) { w in winner(w) }
                    }
                }
                ForEach(entries.filter { $0.place != 1 }, id: \.submission.id) { e in
                    Button { open = e.submission } label: {
                        HStack(spacing: 10) {
                            Group { if e.place == 2 || e.place == 3 { Rosette(place: Int(e.place), height: 38) } else { Color.clear } }.frame(width: 30, height: 38)
                            MediaTile(media: e.submission.media, square: true, radius: Tokens.Radius.field).frame(width: 52)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(e.submission.petName).type(.bodyStrong).foregroundStyle(Tokens.ink).lineLimit(1)
                                Text(e.submission.manager.displayName).type(.small).foregroundStyle(Tokens.muted)
                            }
                            Spacer()
                            Text("\(e.votes)").type(.scoreSmall).foregroundStyle(Tokens.ink).monospacedDigit()
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(e.submission.petName) by \(e.submission.manager.displayName), \(e.votes) \(Tokens.votes(Int(e.votes)))")
                }
            }
            .padding(.top, 8)
        }
    }

    private func winner(_ w: Components.Schemas.ResultEntry) -> some View {
        Button { open = w.submission } label: {
            MediaTile(media: w.submission.media, large: true, square: true)
                .overlay(alignment: .bottom) {
                    HStack(alignment: .bottom) {
                        Text("\(w.submission.petName), by \(w.submission.manager.displayName)").font(Font(TypeStyle.smallStrong.uiFont())).lineLimit(2)
                        Spacer()
                        Text("\(w.votes)").font(Font(TypeStyle.scoreSmall.uiFont())).monospacedDigit()
                    }
                    .foregroundStyle(.white).padding(.horizontal, 12).padding(.bottom, 10).padding(.top, 40)
                    .background(LinearGradient(colors: [.black.opacity(0.75), .clear], startPoint: .bottom, endPoint: .top))
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: Tokens.Radius.card, bottomTrailingRadius: Tokens.Radius.card, style: .continuous))
                }
                .overlay(alignment: .topTrailing) { Rosette(place: 1).shadow(color: .black.opacity(0.35), radius: 4, y: 3).offset(x: -10, y: -8) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(w.submission.petName) by \(w.submission.manager.displayName), first place, \(w.votes) \(Tokens.votes(Int(w.votes)))")
    }
}
