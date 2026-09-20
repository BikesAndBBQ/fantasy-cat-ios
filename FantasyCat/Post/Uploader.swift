import Foundation

/// POST /api/media. The one request written by hand: the server takes a
/// streamed multipart body of up to 100 MB there, which is deliberately not in
/// the OpenAPI spec, so there is nothing to generate it from.
///
/// It runs in a background URLSession, so an upload that's under way finishes
/// even if the person leaves the app, which is most of why this app exists.
/// (Picking up the *result* of an upload that finished after the app was
/// killed is not handled yet: the post would have to be redone.)
final class Uploader: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    static let shared = Uploader()

    private struct Pending {
        var data = Data()
        var progress: @Sendable (Double) -> Void
        var done: CheckedContinuation<Components.Schemas.MediaView, any Error>
        var bodyFile: URL
    }
    private let lock = NSLock()
    private var pending: [Int: Pending] = [:]
    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.background(withIdentifier: "co.fantasycat.app.upload")
        c.httpCookieStorage = nil
        c.isDiscretionary = false // the person is waiting
        c.sessionSendsLaunchEvents = true
        return URLSession(configuration: c, delegate: self, delegateQueue: nil)
    }()

    func upload(_ file: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> Components.Schemas.MediaView {
        // A background session uploads from a file, so the multipart envelope is
        // written to disk around the media rather than built in memory.
        let boundary = "fcl-\(UUID().uuidString)"
        let body = FileManager.default.temporaryDirectory.appending(path: "upload-\(UUID().uuidString).multipart")
        try Self.writeMultipart(file: file, boundary: boundary, to: body)

        var request = URLRequest(url: Server.url.appending(path: "api/media"))
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(API.userAgent, forHTTPHeaderField: "User-Agent")
        guard let token = Keychain.token else { throw Failure(status: 401, message: "Sign in to continue.") }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        return try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, fromFile: body)
            lock.withLock { pending[task.taskIdentifier] = Pending(progress: progress, done: continuation, bodyFile: body) }
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
        lock.withLock { pending[dataTask.taskIdentifier]?.data.append(data) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        guard let p = lock.withLock({ pending.removeValue(forKey: task.taskIdentifier) }) else { return }
        try? FileManager.default.removeItem(at: p.bodyFile)
        if let error { p.done.resume(throwing: Failure.from(error)); return }
        let status = (task.response as? HTTPURLResponse)?.statusCode ?? 0
        let decoder = JSONDecoder()
        if status == 201, let media = try? decoder.decode(Components.Schemas.MediaView.self, from: p.data) {
            p.done.resume(returning: media)
        } else {
            let problem = try? decoder.decode(Components.Schemas.ErrorModel.self, from: p.data)
            p.done.resume(throwing: Failure.from(status: status, problem))
        }
    }
}
