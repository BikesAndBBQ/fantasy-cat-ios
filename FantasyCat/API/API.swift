import Foundation
import HTTPTypes
import OpenAPIRuntime
import OpenAPIURLSession

/// Where the server is. Production unless told otherwise:
/// `-api http://localhost:8080` points a Simulator build at `./dev.sh`.
enum Server {
    static let url: URL = {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-api"), args.indices.contains(i + 1), let u = URL(string: args[i + 1]) { return u }
        return URL(string: "https://fantasycat.co")!
    }()
}

/// Every request says "I'm a native client" and, once signed in, who it is.
/// The server answers the first by returning the session token in the body
/// instead of a cookie (server DECISIONS D36).
struct SessionMiddleware: ClientMiddleware {
    func intercept(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String,
                   next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[HTTPField.Name("X-Session-Transport")!] = "bearer"
        if let token = Keychain.token { request.headerFields[.authorization] = "Bearer \(token)" }
        return try await next(request, body, baseURL)
    }
}

enum API {
    /// The generated client. Never hand-write a request the spec describes.
    static let client: Client = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = nil // bearer only: no cookie jar to disagree with the Keychain
        config.httpShouldSetCookies = false
        config.httpAdditionalHeaders = ["User-Agent": userAgent]
        return Client(
            serverURL: Server.url.appending(path: "api"),
            configuration: .init(dateTranscoder: ServerDateTranscoder()),
            transport: URLSessionTransport(configuration: .init(session: URLSession(configuration: config))),
            middlewares: [SessionMiddleware()]
        )
    }()

    /// Shown in the server's session list, so "which device is this?" has an answer.
    static let userAgent: String = {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "FantasyCat-iOS/\(v)"
    }()
}

/// What to show a person when a call fails: the server's own sentence when it
/// sent one (they're written for people), otherwise something honest.
struct Failure: Error, Equatable {
    var status: Int?
    var message: String

    static func from(status: Int, _ problem: Components.Schemas.ErrorModel?) -> Failure {
        var message = problem?.detail ?? problem?.title ?? "Something went wrong (\(status))."
        // Validation failures arrive as a bland summary plus the useful part per field.
        let fields = (problem?.errors ?? []).compactMap { e -> String? in
            guard let m = e.message, !m.isEmpty else { return nil }
            let name = e.location?.split(separator: ".").last.map { $0.replacingOccurrences(of: "_", with: " ") }
            return name.map { "\($0.prefix(1).uppercased() + $0.dropFirst()): \(m)" } ?? m
        }
        if !fields.isEmpty, status == 422 || message.lowercased().contains("validation") { message = fields.joined(separator: "\n") }
        return Failure(status: status, message: message)
    }
    static func from(_ error: any Error) -> Failure {
        if let f = error as? Failure { return f }
        if let e = (error as? ClientError)?.underlyingError as? URLError ?? error as? URLError {
            return Failure(message: e.code == .notConnectedToInternet ? "You're offline." : "Couldn't reach Fantasy Cat League. Check your connection and try again.")
        }
        #if DEBUG
        print("API failure:", error) // `make console` shows this; a decode error here means the spec and server disagree
        #endif
        return Failure(message: "Something went wrong. Try again.")
    }
}
