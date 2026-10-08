import FantasyCatCore
import Observation
import SwiftUI

/// Posting one photo or video to one category: prepare, upload, submit.
@MainActor @Observable
final class PostModel {
    enum Stage: Equatable {
        case choosing
        case loading(Double) // getting the file out of Photos
        case ready
        case preparing(Double) // cutting and re-encoding the clip
        case uploading(Double)
        case submitting
        case posted(category: String)
    }

    let league: Components.Schemas.LeagueView
    private(set) var pets: [Components.Schemas.PetView] = []
    private(set) var stage: Stage = .choosing
    var failure: String?

    var media: PickedMedia? { didSet { trim = media.map { Clip.whole($0.duration) } ?? 0...0 } }
    var trim: ClosedRange<Double> = 0...0
    var categoryID: Int64?
    var petID: Int64?
    var newCatName = ""
    var caption = ""

    init(league: Components.Schemas.LeagueView) {
        self.league = league
        categoryID = league.currentRound?.categories?.first?.id
    }

    var categories: [Components.Schemas.CategoryView] { league.currentRound?.categories ?? [] }
    var isOpen: Bool { league.currentRound?.status == .submitting }
    var busy: Bool { switch stage { case .preparing, .uploading, .submitting, .loading: true; default: false } }
    var canPost: Bool {
        media != nil && categoryID != nil && !busy && (petID != nil || !newCatName.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    func loadPets() async {
        guard case .ok(let ok) = try? await API.client.listPets(.init()), let body = try? ok.body.json else { return }
        pets = body.pets ?? []
        if petID == nil { petID = pets.first?.id }
    }

    func setLoading(_ fraction: Double) { stage = .loading(fraction) }
    func picked(_ m: PickedMedia) { media = m; stage = .ready; failure = nil }
    func pickFailed(_ message: String) { stage = .choosing; failure = message }

    func post() async {
        guard let media, let categoryID, canPost else { return }
        failure = nil
        let category = categories.first { $0.id == categoryID }?.name ?? "the round"
        // Written down before the upload starts, so a relaunched app can finish
        // the post if iOS ends this one meanwhile (PostRecovery).
        var post = PendingPost(league: league.slug, categoryID: categoryID, categoryName: category, petID: petID,
                               newCatName: petID == nil ? newCatName.trimmingCharacters(in: .whitespaces) : nil, caption: caption, created: .now)
        let recovery = PostRecovery.shared
        defer { recovery.end(post.id) }
        do {
            var file = media.url
            if media.kind == .video {
                stage = .preparing(0)
                file = try await MediaPrep.exportClip(from: media.url, range: trim) { [weak self] p in
                    Task { @MainActor in if case .preparing = self?.stage { self?.stage = .preparing(p) } }
                }
            }
            stage = .uploading(0)
            recovery.begin(post)
            let uploaded = try await Uploader.shared.upload(file, post: post.id) { [weak self] p in
                Task { @MainActor in if case .uploading = self?.stage { self?.stage = .uploading(p) } }
            }
            stage = .submitting
            post.mediaID = uploaded.id
            recovery.update(post)
            try await PostSubmission.submit(post, media: uploaded.id, recovering: false) { pet in
                post.petID = pet
                post.newCatName = nil
                recovery.update(post)
            }
            stage = .posted(category: category)
        } catch {
            failure = Failure.from(error).message
            stage = .ready
        }
    }
}
