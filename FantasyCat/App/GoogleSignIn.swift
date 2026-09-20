import AuthenticationServices
import CryptoKit
import UIKit

/// Google sign-in, without Google's SDK. The system sign-in sheet
/// (`ASWebAuthenticationSession`) runs the server's ordinary web flow; because
/// that sheet is a browser and not this app, the server ends the flow by
/// redirecting to `fantasycat://auth/google?code=…` and the app trades the
/// code for a session token (server D38).
///
/// A custom URL scheme can be claimed by any app, so the code alone is worth
/// nothing: it only redeems together with `verifier`, a secret that never
/// leaves this process. The server was given its SHA-256 when the flow began.
@MainActor
final class GoogleSignIn: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let scheme = "fantasycat"

    struct Result { let code: String; let verifier: String }

    func run() async throws(Failure) -> Result {
        var bytes = [UInt8](repeating: 0, count: 48)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let verifier = Data(bytes).base64URL
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URL

        var start = URLComponents(url: Server.url.appending(path: "api/auth/google/start"), resolvingAgainstBaseURL: false)!
        start.queryItems = [URLQueryItem(name: "app_challenge", value: challenge)]

        let callback: URL
        do {
            callback = try await withCheckedThrowingContinuation { continuation in
                let session = ASWebAuthenticationSession(url: start.url!, callback: .customScheme(Self.scheme)) { url, error in
                    if let url { continuation.resume(returning: url) } else { continuation.resume(throwing: error ?? URLError(.unknown)) }
                }
                session.presentationContextProvider = self
                // Share Safari's cookies: someone already signed in to Google there isn't asked again.
                session.prefersEphemeralWebBrowserSession = false
                if !session.start() { continuation.resume(throwing: URLError(.cannotLoadFromNetwork)) }
            }
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            throw Failure(message: "") // they closed the sheet; nothing to say
        } catch {
            throw Failure(message: "Couldn't open Google sign-in. Try again.")
        }

        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let reason = items.first(where: { $0.name == "error" })?.value { throw Failure(message: Self.sentence(for: reason)) }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw Failure(message: "Google sign-in didn't finish. Try again.")
        }
        return Result(code: code, verifier: verifier)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap(\.windows).first(where: \.isKeyWindow) ?? ASPresentationAnchor()
    }

    /// The same reasons, in the same words, as the web's sign-in page.
    private static func sentence(for reason: String) -> String {
        switch reason {
        case "google_cancelled": ""
        case "google_unverified": "Google hasn't verified that email address, so we can't use it to sign you in."
        case "google_expired": "That sign-in took too long. Try again."
        default: "Google sign-in didn't work. Try again."
        }
    }
}

private extension Data {
    var base64URL: String {
        base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
}
