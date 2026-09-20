import Observation
import SwiftUI

/// Who is signed in, and the only place that changes.
@MainActor @Observable
final class AppModel {
    enum Phase: Equatable {
        case starting
        case signedOut
        case signedIn(Components.Schemas.UserView, leagues: [Components.Schemas.LeagueSummary])
    }
    private(set) var phase: Phase = .starting

    /// On launch: a stored token is only a claim until the server agrees.
    func start() async {
        #if DEBUG
        // `-signout`: sign out at launch, so that path can be checked from the command line too.
        if ProcessInfo.processInfo.arguments.contains("-signout") { await signOut(); return }
        #endif
        guard Keychain.token != nil else { phase = .signedOut; return }
        do {
            switch try await API.client.me(.init()) {
            case .ok(let ok):
                let me = try ok.body.json
                phase = .signedIn(me.user, leagues: me.leagues ?? [])
            case .default(let status, _):
                if status == 401 { Keychain.token = nil } // revoked or expired
                phase = .signedOut
            }
        } catch {
            // Offline at launch: keep the token, show the door. Signing in again isn't required next time.
            phase = .signedOut
        }
    }

    func signIn(login: String, password: String) async throws(Failure) {
        do {
            let out = try await API.client.login(body: .json(.init(login: login, password: password)))
            switch out {
            case .ok(let ok):
                let body = try ok.body.json
                guard let token = body.sessionToken, !token.isEmpty else {
                    throw Failure(message: "The server didn't return a session. Update the app.")
                }
                Keychain.token = token
                phase = .signedIn(body.user, leagues: body.leagues ?? [])
            case .default(let status, let problem):
                throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch {
            throw Failure.from(error)
        }
    }

    /// Whether the server offers Google at all (it's configuration there).
    private(set) var googleAvailable = false
    func loadProviders() async {
        if case .ok(let ok) = try? await API.client.authProviders(.init()), let body = try? ok.body.json { googleAvailable = body.google }
    }

    func signInWithGoogle() async throws(Failure) {
        let handoff = try await GoogleSignIn().run()
        do {
            switch try await API.client.exchangeAppLogin(body: .json(.init(code: handoff.code, verifier: handoff.verifier))) {
            case .ok(let ok):
                let body = try ok.body.json
                guard let token = body.sessionToken, !token.isEmpty else { throw Failure(message: "The server didn't return a session. Update the app.") }
                Keychain.token = token
                phase = .signedIn(body.user, leagues: body.leagues ?? [])
            case .default(let status, let problem):
                throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch {
            throw Failure.from(error)
        }
    }

    func signOut() async {
        _ = try? await API.client.logout(.init()) // best effort: the local token goes either way
        Keychain.token = nil
        phase = .signedOut
    }
}
