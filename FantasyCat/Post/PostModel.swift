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
        do {
            var file = media.url
            if media.kind == .video {
                stage = .preparing(0)
                file = try await MediaPrep.exportClip(from: media.url, range: trim) { [weak self] p in
                    Task { @MainActor in if case .preparing = self?.stage { self?.stage = .preparing(p) } }
                }
            }
            stage = .uploading(0)
            let uploaded = try await Uploader.shared.upload(file) { [weak self] p in
                Task { @MainActor in if case .uploading = self?.stage { self?.stage = .uploading(p) } }
            }
            stage = .submitting
            var pet = petID
            if pet == nil {
                let out = try await API.client.createPet(body: .json(.init(name: newCatName.trimmingCharacters(in: .whitespaces))))
                guard case .created(let c) = out else { throw Failure(message: "Couldn't add that cat. Try again.") }
                pet = try c.body.json.id
            }
            let out = try await API.client.createSubmission(path: .init(id: categoryID), body: .json(.init(caption: caption, mediaId: uploaded.id, petId: pet!)))
            switch out {
            case .created:
                stage = .posted(category: categories.first { $0.id == categoryID }?.name ?? "the round")
            case .default(let status, let problem):
                throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch {
            failure = Failure.from(error).message
            stage = .ready
        }
    }
}
