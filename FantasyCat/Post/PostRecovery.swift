import FantasyCatCore
import Observation
import OpenAPIRuntime
import UIKit

/// Posts that outlive the run of the app that started them. Every post is
/// written down as a `PendingPost` before its upload starts and removed once
/// it is submitted. In between, iOS may end the app: the background session
/// still finishes the upload and relaunches the app, and this submits the post
/// the person asked for. What's still going, or what went wrong, is shown on
/// This week (`PendingPostNotice`).
@MainActor @Observable
final class PostRecovery {
    static let shared = PostRecovery()

    private let store = PendingPosts(directory: URL.applicationSupportDirectory.appending(path: "pending-posts"))
    private(set) var posts: [PendingPost] = []
    /// Being submitted by this process right now, by `PostModel` or by this.
    private var claimed: Set<String> = []

    private init() { posts = store.all(now: .now) }

    private func reload() { posts = store.all(now: .now) }

    // MARK: Used by PostModel, while the person watches

    func begin(_ post: PendingPost) {
        claimed.insert(post.id)
        try? store.save(post)
        reload()
    }

    func update(_ post: PendingPost) {
        try? store.save(post)
        reload()
    }

    func end(_ id: String) {
        claimed.remove(id)
        store.remove(id)
        reload()
    }

    // MARK: Recovering

    /// At launch: posts whose upload finished but whose submission never did
    /// (the app was ended between the two).
    func sweep() {
        reload()
        for p in posts where p.stage == .submitting { finish(p.id) }
    }

    /// The session reports an upload a previous run started.
    func uploadEnded(_ id: String, _ result: Result<Int64, any Error>) {
        guard var p = store.load(id) else { return }
        switch result {
        case .success(let media):
            p.mediaID = media
            p.failure = nil // check() may have given up on it a moment before the session delivered it
            update(p)
            finish(id)
        case .failure(let error):
            p.failure = Failure.from(error).message
            update(p)
        }
    }

    /// On This week: retry a submission that couldn't reach the server, and
    /// give up on an upload the session no longer has. (A launch delivers the
    /// session's finished uploads within moments, well before anyone looks.)
    func check() async {
        let live = await Uploader.shared.uploadsInFlight()
        for var p in store.all(now: .now) where p.stage == .uploading && !claimed.contains(p.id) && !live.contains(p.id)
            && Date.now.timeIntervalSince(p.created) > 60 {
            p.failure = "The upload didn't finish. Post it again."
            try? store.save(p)
        }
        sweep()
    }

    func dismiss(_ id: String) { store.remove(id); reload() }

    private func finish(_ id: String) {
        guard !claimed.contains(id), let p = store.load(id), let media = p.mediaID, p.failure == nil else { return }
        claimed.insert(id)
        // The app may be in the background, woken by the upload session: ask
        // for the time to send the post.
        let background = UIApplication.shared.beginBackgroundTask(withName: "post")
        Task {
            defer { claimed.remove(id); UIApplication.shared.endBackgroundTask(background) }
            do {
                try await PostSubmission.submit(p, media: media, recovering: true) { pet in
                    var q = p
                    q.petID = pet
                    q.newCatName = nil
                    self.update(q)
                }
                end(id)
            } catch {
                // Couldn't reach the server: left as it is, it's tried again at
                // the next launch or the next look at This week. Anything else is the answer.
                let offline = error is URLError || (error as? ClientError)?.underlyingError is URLError
                guard !offline, var q = store.load(id) else { return }
                q.failure = Failure.from(error).message
                update(q)
            }
        }
    }
}

/// Pet, then submission: the end of posting, shared by the screen and by recovery.
enum PostSubmission {
    /// `recovering`: the submission may have been sent by a run that ended
    /// before it heard the answer, so look before posting the same media twice.
    /// `newPet` is told about a cat this created, so a retry doesn't make another.
    @MainActor
    static func submit(_ post: PendingPost, media: Int64, recovering: Bool, newPet: (Int64) -> Void) async throws {
        if recovering, case .ok(let ok) = try await API.client.listSubmissions(path: .init(id: post.categoryID)),
           let feed = try? ok.body.json, (feed.submissions ?? []).contains(where: { $0.isMine && $0.media.id == media }) {
            return
        }
        var pet = post.petID
        if pet == nil {
            let out = try await API.client.createPet(body: .json(.init(name: post.newCatName ?? "")))
            guard case .created(let c) = out else { throw Failure(message: "Couldn't add that cat. Try again.") }
            pet = try c.body.json.id
            newPet(pet!)
        }
        let out = try await API.client.createSubmission(path: .init(id: post.categoryID), body: .json(.init(caption: post.caption, mediaId: media, petId: pet!)))
        if case .default(let status, let problem) = out {
            throw Failure.from(status: status, try? problem.body.applicationProblemJson)
        }
    }
}
