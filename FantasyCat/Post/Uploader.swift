import Foundation

/// POST /api/media. The one request written by hand: the server takes a
/// streamed multipart body of up to 100 MB there, which is deliberately not in
/// the OpenAPI spec, so there is nothing to generate it from.
///
/// It runs in a background URLSession, so an upload that's under way finishes
/// even if the person leaves the app, which is most of why this app exists.
/// If iOS ends the app meanwhile, the session finishes the upload and relaunches
/// the app; the finished upload is then handed to `PostRecovery` by its
/// `taskDescription`, the id of the `PendingPost` it belongs to.
final class Uploader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    static let shared = Uploader()

    private struct Pending {
        var progress: @Sendable (Double) -> Void
        var done: CheckedContinuation<Components.Schemas.MediaView, any Error>
    }
    private let lock = NSLock()
    private var pending: [Int: Pending] = [:]
    /// Response bodies by task, including tasks this process didn't start.
    private var received: [Int: Data] = [:]
    /// From `handleEventsForBackgroundURLSession`: called once the session has
    /// delivered everything it relaunched the app for.
    private var backgroundCompletion: (@Sendable () -> Void)?
    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.background(withIdentifier: "co.fantasycat.app.upload")
        c.httpCookieStorage = nil
        c.isDiscretionary = false // the person is waiting
        c.sessionSendsLaunchEvents = true
        return URLSession(configuration: c, delegate: self, delegateQueue: nil)
    }()

    /// Recreating the session reconnects it to uploads a previous run started,
    /// whose results are then delivered to this delegate. Called at launch.
    func reconnect(completion: (@Sendable () -> Void)? = nil) {
        if let completion { lock.withLock { backgroundCompletion = completion } }
        _ = lock.withLock { session }
    }

    /// The pending posts whose uploads the session is still working on.
    func uploadsInFlight() async -> Set<String> {
        Set(await session.allTasks.filter { $0.state == .running || $0.state == .suspended }.compactMap(\.taskDescription))
    }

    static func bodyFile(_ post: String) -> URL {
        FileManager.default.temporaryDirectory.appending(path: "upload-\(post).multipart")
    }

    /// `post`: the `PendingPost` this is for. Other uploads (an avatar) have
    /// none to finish, and recovery finds nothing under their id.
    func upload(_ file: URL, post: String = UUID().uuidString, progress: @escaping @Sendable (Double) -> Void) async throws -> Components.Schemas.MediaView {
        // A background session uploads from a file, so the multipart envelope is
        // written to disk around the media rather than built in memory.
        let boundary = "fcl-\(UUID().uuidString)"
        let body = Self.bodyFile(post)
        try Self.writeMultipart(file: file, boundary: boundary, to: body)

        var request = URLRequest(url: Server.url.appending(path: "api/media"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(API.userAgent, forHTTPHeaderField: "User-Agent")
        guard let token = Keychain.token else { throw Failure(status: 401, message: "Sign in to continue.") }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return try await withCheckedThrowingContinuation { continuation in
            let task = lock.withLock { session.uploadTask(with: request, fromFile: body) }
            task.taskDescription = post
            lock.withLock { pending[task.taskIdentifier] = Pending(progress: progress, done: continuation) }
            task.resume()
        }
    }

    private static func writeMultipart(file: URL, boundary: String, to out: URL) throws {
        FileManager.default.createFile(atPath: out.path, contents: nil)
        let w = try FileHandle(forWritingTo: out)
        defer { try? w.close() }
        let name = file.lastPathComponent.replacingOccurrences(of: "\"", with: "")
        try w.write(contentsOf: Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8))
        let r = try FileHandle(forReadingFrom: file)
        defer { try? r.close() }
        while let chunk = try r.read(upToCount: 1 << 20), !chunk.isEmpty { try w.write(contentsOf: chunk) }
        try w.write(contentsOf: Data("\r\n--\(boundary)--\r\n".utf8))
    }

    // MARK: URLSession delegate

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        guard totalBytesExpectedToSend > 0 else { return }
        let p = lock.withLock { pending[task.taskIdentifier]?.progress }
        p?(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.withLock { received[dataTask.taskIdentifier, default: Data()].append(data) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let (p, data) = lock.withLock { (pending.removeValue(forKey: task.taskIdentifier), received.removeValue(forKey: task.taskIdentifier) ?? Data()) }
        if let post = task.taskDescription { try? FileManager.default.removeItem(at: Self.bodyFile(post)) }
        let result = Self.result(error: error, status: (task.response as? HTTPURLResponse)?.statusCode ?? 0, data: data)
        if let p {
            p.done.resume(with: result)
        } else if let post = task.taskDescription {
            // Started by a run of the app that has since ended.
            Task { @MainActor in PostRecovery.shared.uploadEnded(post, result.map(\.id)) }
        }
    }

    private static func result(error: (any Error)?, status: Int, data: Data) -> Result<Components.Schemas.MediaView, any Error> {
        if let error {
            let reason = (error as NSError).userInfo[NSURLErrorBackgroundTaskCancelledReasonKey] as? Int
            if reason == NSURLErrorCancelledReasonUserForceQuitApplication {
                return .failure(Failure(message: "The upload stopped when the app was closed. Post it again."))
            }
            return .failure(Failure.from(error))
        }
        let decoder = JSONDecoder()
        if status == 201, let media = try? decoder.decode(Components.Schemas.MediaView.self, from: data) { return .success(media) }
        return .failure(Failure.from(status: status, try? decoder.decode(Components.Schemas.ErrorModel.self, from: data)))
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        guard let done = lock.withLock({ backgroundCompletion.take() }) else { return }
        // Finishing the post these events started holds a background task of its
        // own (PostRecovery), so saying "done" now doesn't cut it short.
        DispatchQueue.main.async { done() }
    }
}
