import Observation
import SwiftUI

typealias League = Components.Schemas.LeagueView
typealias Submission = Components.Schemas.SubmissionView

/// Everything the league screens show, loaded through the generated client.
/// The server decides what phase a round is in and what may be seen (vote
/// tallies stay hidden until a round is final); this only fetches and holds.
@MainActor @Observable
final class LeagueStore {
    let slug: String
    private(set) var league: League?
    private(set) var rounds: [Components.Schemas.RoundSummary] = []
    private(set) var feeds: [Int64: Components.Schemas.SubmissionsOutputBody] = [:]
    private(set) var standings: Components.Schemas.StandingsOutputBody?
    private(set) var results: [Int64: Components.Schemas.ResultsOutputBody] = [:]
    private(set) var failure: String?
    /// The round in voting, with each category's `myVotesSpent`. Nil when there isn't one.
    private(set) var votingRound: Components.Schemas.RoundView?
    private(set) var ballots: [Int64: Components.Schemas.BallotView] = [:]

    init(slug: String, league: League? = nil) {
        self.slug = slug
        self.league = league
    }

    var finalRounds: [Components.Schemas.RoundSummary] { rounds.filter { $0.status == .final }.sorted { $0.number > $1.number } }

    /// League and rounds. Round phases flip at midnight, so the shell calls this
    /// on a gentle timer too (the web polls every minute for the same reason).
    func refresh() async {
        do {
            switch try await API.client.getLeague(path: .init(slug: slug)) {
            case .ok(let ok): league = try ok.body.json; failure = nil
            case .default(let status, let p): failure = Failure.from(status: status, try? p.body.applicationProblemJson).message
            }
            if case .ok(let ok) = try await API.client.listRounds(path: .init(slug: slug)) { rounds = try ok.body.json.rounds ?? [] }
            if let voting = rounds.first(where: { $0.status == .voting }) {
                if case .ok(let ok) = try await API.client.getRound(path: .init(slug: slug, number: Int32(voting.number))) { votingRound = try ok.body.json }
            } else {
                votingRound = nil
                ballots = [:]
            }
        } catch { if league == nil { failure = Failure.from(error).message } }
    }

    func loadFeed(_ categoryID: Int64) async {
        guard case .ok(let ok) = try? await API.client.listSubmissions(path: .init(id: categoryID)), let body = try? ok.body.json else { return }
        feeds[categoryID] = body
    }

    func loadStandings() async {
        guard case .ok(let ok) = try? await API.client.standings(path: .init(slug: slug)), let body = try? ok.body.json else { return }
        standings = body
    }

    func loadResults(_ number: Int64) async {
        guard case .ok(let ok) = try? await API.client.roundResults(path: .init(slug: slug, number: Int32(number))), let body = try? ok.body.json else { return }
        results[number] = body
    }

    /// Votes you still have to give somewhere: what the Vote tab's badge counts.
    var categoriesLeftToVote: Int {
        guard let league, let round = votingRound else { return 0 }
        return (round.categories ?? []).filter { $0.myVotesSpent < Int64(league.voteBudget) && $0.submissionCount > $0.mySubmissionCount }.count
    }

    func loadBallot(_ categoryID: Int64) async -> String? {
        do {
            switch try await API.client.getBallot(path: .init(id: categoryID)) {
            case .ok(let ok): ballots[categoryID] = try ok.body.json; return nil
            case .default(let status, let p): return Failure.from(status: status, try? p.body.applicationProblemJson).message
            }
        } catch { return Failure.from(error).message }
    }

    /// Save a whole category's ballot. The server checks the budget, the cap and
    /// "not your own"; on refusal the caller falls back to what the server has.
    func saveBallot(_ categoryID: Int64, points: [Int64: Int]) async -> String? {
        let allocations = points.filter { $0.value > 0 }.map { Components.Schemas.BallotAllocation(points: Int64($0.value), submissionId: $0.key) }
        do {
            switch try await API.client.putBallot(path: .init(id: categoryID), body: .json(.init(allocations: allocations))) {
            case .ok(let ok):
                ballots[categoryID] = try ok.body.json
                await refresh() // the per-category "spent" marks and the tab badge
                return nil
            case .default(let status, let p):
                _ = await loadBallot(categoryID)
                return Failure.from(status: status, try? p.body.applicationProblemJson).message
            }
        } catch {
            _ = await loadBallot(categoryID)
            return Failure.from(error).message
        }
    }

    /// Take down your own post while submissions are open. Returns what to tell the person if it failed.
    func delete(_ s: Submission) async -> String? {
        do {
            switch try await API.client.deleteSubmission(path: .init(id: s.id)) {
            case .noContent:
                await loadFeed(s.categoryId)
                await refresh() // category counts
                return nil
            case .default(let status, let p): return Failure.from(status: status, try? p.body.applicationProblemJson).message
            }
        } catch { return Failure.from(error).message }
    }
}
