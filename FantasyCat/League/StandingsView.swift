import SwiftUI

struct StandingsView: View {
    let store: LeagueStore
    let header: LeagueHeader

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let table = store.standings {
                    PageTitle(eyebrow: "Season", title: "Standings") { Chip("\(table.roundsFinal) of \(table.seasonRounds) rounds scored", tone: .done) }
                    let rows = table.standings ?? []
                    if rows.isEmpty {
                        EmptyState("No points yet", "The table fills in when the first round's results post.")
                    } else {
                        VStack(spacing: 0) {
                            HStack {
                                Eyebrow("Manager").padding(.leading, 44)
                                Spacer()
                                Eyebrow("Wins").frame(width: 44, alignment: .trailing)
                                Eyebrow("Points").frame(width: 60, alignment: .trailing)
                            }
                            .padding(.horizontal, 8).padding(.bottom, 8)
                            ForEach(rows, id: \.manager.id) { r in
                                Divider().overlay(Tokens.line)
                                HStack(spacing: 10) {
                                    Text("\(r.rank)").type(.scoreSmall).foregroundStyle(Tokens.muted).frame(width: 24, alignment: .leading)
                                    Avatar(url: r.manager.avatarUrl.flatMap(URL.init(string:)))
                                    Text(r.manager.displayName).type(.bodyStrong).foregroundStyle(Tokens.ink).lineLimit(1)
                                    if r.isMe { Chip("you") }
                                    Spacer(minLength: 4)
                                    Text("\(r.wins)").type(.body).foregroundStyle(Tokens.ink).frame(width: 44, alignment: .trailing)
                                    Text("\(r.total)").type(.scoreSmall).foregroundStyle(Tokens.ink).frame(width: 60, alignment: .trailing)
                                }
                                .monospacedDigit()
                                .padding(.horizontal, 8).padding(.vertical, 10)
                                .background(r.isMe ? Tokens.accentWash : .clear, in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("\(r.rank). \(r.manager.displayName)\(r.isMe ? ", you" : ""), \(r.total) points, \(r.wins) wins")
                            }
                        }
                    }
                    Text("One point per \(Tokens.voteWord) received, one for posting in a category, two for voting in every category, three for a category win.")
                        .type(.small).foregroundStyle(Tokens.muted)
                } else {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                }
            }
            .padding(16)
        }
        .background(PageBackground())
        .refreshable { await store.loadStandings() }
        .task { await store.loadStandings() }
    }
}
