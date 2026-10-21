import FantasyCatCore
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

    /// Your Google picture, offered once while you have none (server D47).
    /// Comes with every answer that says who you are; either reply ends it.
    private(set) var pictureOffer: String?

    /// Which sign-ins the account has connected (server sc-702). Comes with
    /// every answer that says who you are; the account screen names them.
    struct SignIns: Equatable {
        var google = false
        var apple = false
        /// "Google and Apple", or "a passkey" when neither: how the account
        /// screen says how you get in without a password, as the web does.
        var name: String {
            let ways = [google ? "Google" : nil, apple ? "Apple" : nil].compactMap { $0 }
            return ways.isEmpty ? "a passkey" : ways.joined(separator: " and ")
        }
    }
    private(set) var signIns = SignIns()
    /// The notification settings grid from `GET /me`: a row per category this
    /// person is shown, with a cell per channel that exists (server
    /// designs/20261019-notification-settings.md §3). Empty until /me is read.
    private(set) var notifications: [Components.Schemas.NotificationRow] = []

    /// The code of an invite link the app was opened with, kept until it's
    /// used: by signing up with it, or on the join screen once signed in.
    var pendingInvite: String?

    /// A link the app was opened with. Only invites mean anything yet.
    func open(_ url: URL) {
        if let code = Invite.code(fromLink: url) { pendingInvite = code }
    }

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
                apply(me)
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
                pictureOffer = body.pictureOffer
                signIns = SignIns(google: body.hasGoogle, apple: body.hasApple)
            case .default(let status, let problem):
                throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch {
            throw Failure.from(error)
        }
    }

    /// The server sent a fresh picture of the account (after a profile change).
    func apply(_ me: Components.Schemas.MeBody) {
        phase = .signedIn(me.user, leagues: me.leagues ?? [])
        pictureOffer = me.pictureOffer
        signIns = SignIns(google: me.hasGoogle, apple: me.hasApple)
        notifications = me.notifications ?? []
    }

    /// Re-read who we are and which leagues we're in (after creating, joining or leaving one).
    func reload() async {
        if case .ok(let ok) = try? await API.client.me(.init()), let me = try? ok.body.json { apply(me) }
    }

    func signUp(name: String, username: String, email: String, password: String, reminders: Bool, invite: String?) async throws(Failure) {
        do {
            let body = Components.Schemas.SignupInputBody(displayName: name, email: email, inviteCode: invite, notifyEmail: reminders, password: password, username: username)
            switch try await API.client.signup(body: .json(body)) {
            case .created(let c):
                let out = try c.body.json
                guard let token = out.sessionToken, !token.isEmpty else { throw Failure(message: "The server didn't return a session. Update the app.") }
                Keychain.token = token
                if invite != nil { pendingInvite = nil } // joined on the way in
                phase = .signedIn(out.user, leagues: out.leagues ?? [])
                pictureOffer = out.pictureOffer
                signIns = SignIns(google: out.hasGoogle, apple: out.hasApple)
            case .default(let status, let problem):
                throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch { throw Failure.from(error) }
    }

    /// Use the offered picture, or say no. Either way the server never asks
    /// again. The copy is made in the background, so the picture is fetched
    /// again a few seconds after a yes.
    func answerPictureOffer(use: Bool) async throws(Failure) {
        do {
            switch try await API.client.answerPictureOffer(body: .json(.init(use: use))) {
            case .ok(let ok): apply(try ok.body.json)
            case .default(let status, let problem): throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch { throw Failure.from(error) }
        if use {
            Task {
                try? await Task.sleep(for: .seconds(4))
                await reload()
            }
        }
    }

    /// `current` is nil for an account that has no password yet (Google or passkey only).
    func changePassword(current: String?, new: String) async throws(Failure) {
        do {
            switch try await API.client.changePassword(body: .json(.init(currentPassword: current, newPassword: new))) {
            case .noContent: await reload()
            case .default(let status, let problem): throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch { throw Failure.from(error) }
    }

    /// Always "sent", whether or not the address has an account: the server doesn't say, and neither do we.
    func forgotPassword(email: String) async throws(Failure) {
        do {
            switch try await API.client.forgotPassword(body: .json(.init(email: email))) {
            case .noContent: return
            case .default(let status, let problem): throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch { throw Failure.from(error) }
    }

    /// Set when the server says this build is too old to use (I13). While it
    /// is set, RootView shows only the update screen.
    struct UpdateRequired: Equatable {
        var message: String
        var url: URL?
    }
    private(set) var updateRequired: UpdateRequired?

    /// Asked at launch and on every return to the foreground, signed in or
    /// not. Offline or an answer it can't read leaves things as they were:
    /// the check never locks anyone out by failing.
    func checkForUpdate() async {
        guard case .ok(let ok) = try? await API.client.iosAppVersion(.init()), let body = try? ok.body.json else { return }
        #if DEBUG
        // `-minbuild <n>`: pretend the server said n, to see the screen without touching the server.
        let args = ProcessInfo.processInfo.arguments
        let minBuild = args.firstIndex(of: "-minbuild").flatMap { args.indices.contains($0 + 1) ? Int64(args[$0 + 1]) : nil } ?? body.minBuild
        #else
        let minBuild = body.minBuild
        #endif
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        updateRequired = UpdateCheck.mustUpdate(build: build, minBuild: minBuild)
            ? UpdateRequired(message: body.message, url: URL(string: body.updateUrl))
            : nil
    }

    /// Whether the server offers Google at all (it's configuration there).
    private(set) var googleAvailable = false
    /// The same for Sign in with Apple (server D43).
    private(set) var appleAvailable = false
    func loadProviders() async {
        if case .ok(let ok) = try? await API.client.authProviders(.init()), let body = try? ok.body.json {
            googleAvailable = body.google
            appleAvailable = body.apple
        }
    }

    func signInWithApple(identityToken: String, authorizationCode: String?, nonce: String, name: String?) async throws(Failure) {
        do {
            let name = name.flatMap { $0.isEmpty ? nil : $0 }
            switch try await API.client.appleSignIn(body: .json(.init(authorizationCode: authorizationCode, identityToken: identityToken, name: name, nonce: nonce))) {
            case .ok(let ok):
                let body = try ok.body.json
                guard let token = body.sessionToken, !token.isEmpty else { throw Failure(message: "The server didn't return a session. Update the app.") }
                Keychain.token = token
                phase = .signedIn(body.user, leagues: body.leagues ?? [])
                pictureOffer = body.pictureOffer
                signIns = SignIns(google: body.hasGoogle, apple: body.hasApple)
            case .default(let status, let problem):
                throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch {
            throw Failure.from(error)
        }
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
                pictureOffer = body.pictureOffer
                signIns = SignIns(google: body.hasGoogle, apple: body.hasApple)
            case .default(let status, let problem):
                throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch {
            throw Failure.from(error)
        }
    }

    /// Deletes the account and everything it posted (server D40). The server
    /// refuses, with a sentence saying why, while you run a league that still
    /// has other managers; then nothing changes here.
    func deleteAccount() async throws(Failure) {
        do {
            switch try await API.client.deleteMe(.init()) {
            case .noContent:
                Keychain.token = nil
                phase = .signedOut
                pictureOffer = nil; signIns = SignIns()
            case .default(let status, let problem):
                throw Failure.from(status: status, try? problem.body.applicationProblemJson)
            }
        } catch { throw Failure.from(error) }
    }

    func signOut() async {
        _ = try? await API.client.logout(.init()) // best effort: the local token goes either way
        Keychain.token = nil
        phase = .signedOut
        pictureOffer = nil; signIns = SignIns()
    }
}
