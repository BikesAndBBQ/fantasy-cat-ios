import AuthenticationServices
import CryptoKit
import SwiftUI

/// Sign in with Apple (server D43, I17). The system sheet hands the app an
/// identity token signed by Apple; the server verifies it and returns a
/// session. No browser, no code exchange as with Google.
///
/// The button is Apple's own `SignInWithAppleButton`, not an `.fc` button:
/// Apple's guidelines fix its mark, wording and colors, so it is the one
/// control on these screens not drawn from the design system (I17). Its
/// height and corner radius are matched to ours.
struct AppleSignInButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    /// Reports a failure to the screen that shows it; nil clears it.
    var failed: (String?) -> Void
    @State private var nonce = ""

    var body: some View {
        SignInWithAppleButton(.continue) { request in
            nonce = Self.randomNonce()
            request.requestedScopes = [.fullName, .email]
            // Apple signs this hash into the token; the server gets the nonce itself and compares.
            request.nonce = SHA256.hash(data: Data(nonce.utf8)).map { String(format: "%02x", $0) }.joined()
            failed(nil)
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                      let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
                    failed("Sign in with Apple didn't finish. Try again.")
                    return
                }
                let code = credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
                let name = credential.fullName.map { PersonNameComponentsFormatter().string(from: $0) }
                let sent = nonce
                Task {
                    do { try await model.signInWithApple(identityToken: token, authorizationCode: code, nonce: sent, name: name) } catch {
                        failed(Failure.from(error).message)
                    }
                }
            case .failure(let error):
                // They closed the sheet themselves: nothing to say.
                if (error as? ASAuthorizationError)?.code != .canceled { failed("Sign in with Apple didn't work. Try again.") }
            }
        }
        .signInWithAppleButtonStyle(scheme == .dark ? .white : .black)
        .frame(height: 46)
        .clipShape(Capsule())
        .accessibilityIdentifier("signin-apple")
    }

    private static func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
