import Foundation

/// A post whose media is going up in the background upload session, written
/// down before the upload starts. If iOS ends the app before the upload
/// finishes, the session finishes it anyway and relaunches the app, which
/// finds this and submits the post the person asked for (I7).
public struct PendingPost: Codable, Equatable, Sendable {
    /// Also the upload task's `taskDescription`, which is how a relaunched app
    /// matches a finished upload to its post.
    public var id: String
    public var league: String // slug
    public var categoryID: Int64
    public var categoryName: String
    public var petID: Int64?
    public var newCatName: String?
    public var caption: String
    public var created: Date
    /// Set once the upload has finished: what's left is the submission.
    public var mediaID: Int64?
    /// Set when finishing it failed. Shown once, then dismissed.
    public var failure: String?

    public init(id: String = UUID().uuidString, league: String, categoryID: Int64, categoryName: String,
                petID: Int64?, newCatName: String?, caption: String, created: Date) {
        self.id = id
        self.league = league
        self.categoryID = categoryID
        self.categoryName = categoryName
        self.petID = petID
        self.newCatName = newCatName
        self.caption = caption
        self.created = created
    }

    public enum Stage: Equatable, Sendable {
        case uploading
        case submitting
        case failed(String)
    }

    public var stage: Stage {
        if let failure { return .failed(failure) }
        return mediaID == nil ? .uploading : .submitting
    }
}

/// One JSON file per pending post in a directory. Small and rare (one per post
/// in flight), so there is no index to keep consistent.
public struct PendingPosts: Sendable {
    public let directory: URL
    /// Older than this, a post is dropped unread: the round it was for has
    /// almost certainly moved on, and nobody is waiting for it any more.
    public static let maxAge: TimeInterval = 2 * 86400

    public init(directory: URL) { self.directory = directory }

    private func file(_ id: String) -> URL { directory.appending(path: "\(id).json") }

    public func save(_ post: PendingPost) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(post).write(to: file(post.id), options: .atomic)
    }

    public func load(_ id: String) -> PendingPost? {
        (try? Data(contentsOf: file(id))).flatMap { try? JSONDecoder().decode(PendingPost.self, from: $0) }
    }

    public func remove(_ id: String) {
        try? FileManager.default.removeItem(at: file(id))
    }

    /// Every readable post, oldest first. Unreadable files and posts older
    /// than `maxAge` are deleted on the way.
    public func all(now: Date) -> [PendingPost] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        var out: [PendingPost] = []
        for f in files where f.pathExtension == "json" {
            guard let data = try? Data(contentsOf: f), let p = try? JSONDecoder().decode(PendingPost.self, from: data),
                  now.timeIntervalSince(p.created) < Self.maxAge else {
                try? FileManager.default.removeItem(at: f)
                continue
            }
            out.append(p)
        }
        return out.sorted { $0.created < $1.created }
    }
}
