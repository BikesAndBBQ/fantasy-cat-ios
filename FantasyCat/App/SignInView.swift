import SwiftUI

/// Username or email, and a password. The fields carry the content types that
/// let iOS offer saved passwords above the keyboard: the system does that, no
/// extension injects anything (the reason this app exists, server D30).
/// Google runs in the system sign-in sheet (GoogleSignIn.swift). Passkeys need
/// the associated-domains entitlement, which needs the paid developer team.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @State private var login = ""
    @State private var password = ""
    @State private var busy = false
    @State private var failure: String?
    @State private var googling = false

    private var canSubmit: Bool { !login.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                (Text("Fantasy ") + Text("Cat").foregroundStyle(Tokens.accentInk) + Text(" League"))
                    .type(.wordmark).foregroundStyle(Tokens.ink)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome back").type(.hero).foregroundStyle(Tokens.ink).accessibilityAddTraits(.isHeader)
                    Text("Sign in to see what the cats have been up to.").type(.body).foregroundStyle(Tokens.muted)
                }
                VStack(alignment: .leading, spacing: 16) {
                    if model.googleAvailable {
                        Button { google() } label: {
                            HStack(spacing: 10) { GoogleMark().frame(width: 18, height: 18); Text("Continue with Google") }
                        }
                        .buttonStyle(.fc(block: true, busy: googling))
                        .disabled(busy || googling)
                        .accessibilityIdentifier("signin-google")
                        HStack(spacing: 10) {
                            Rectangle().fill(Tokens.line).frame(height: 1)
                            Text("or").type(.small).foregroundStyle(Tokens.muted)
                            Rectangle().fill(Tokens.line).frame(height: 1)
                        }
                    }
                    if let failure {
                        Text(failure).type(.small).foregroundStyle(Tokens.danger)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Tokens.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
                            .accessibilityIdentifier("signin-error")
                    }
                    FCField(label: "Username or email", text: $login, contentType: .username, keyboard: .emailAddress)
                        .accessibilityIdentifier("signin-login")
                    FCField(label: "Password", text: $password, secure: true, contentType: .password)
                        .accessibilityIdentifier("signin-password")
                        .onSubmit(submit)
                    Button("Sign in", action: submit)
                        .buttonStyle(.fc(.primary, block: true, busy: busy))
                        .disabled(!canSubmit || busy)
                        .accessibilityIdentifier("signin-submit")
                }
                Text("New here? Create your account at fantasycat.co for now; sign-up in the app is on its way.")
                    .type(.small).foregroundStyle(Tokens.muted)
            }
            .padding(24)
            .padding(.top, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PageBackground())
        .task { await model.loadProviders() }
        #if DEBUG
        // `-autologin <user> <password>`: fills the form and presses the button,
        // so the whole path (network, Keychain, next screen) can be checked from
        // the command line. Debug builds only; never in a release binary.
        .task {
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "-autologin"), args.indices.contains(i + 2) else { return }
            login = args[i + 1]
            password = args[i + 2]
            submit()
        }
        #endif
    }

    private func google() {
        googling = true
        failure = nil
        Task {
            do { try await model.signInWithGoogle() } catch {
                let message = Failure.from(error).message
                failure = message.isEmpty ? nil : message // empty: they closed the sheet themselves
            }
            googling = false
        }
    }

    private func submit() {
        guard canSubmit, !busy else { return }
        busy = true
        failure = nil
        Task {
            do { try await model.signIn(login: login.trimmingCharacters(in: .whitespaces), password: password) } catch { failure = Failure.from(error).message }
            busy = false
        }
    }
}

#Preview { SignInView().environment(AppModel()) }

/// Google's "G", drawn rather than bundled: four arcs and a bar, in Google's
/// own brand colors (the one place a raw color is right: it's their mark, not
/// our palette, and their guidelines require it unmodified).
struct GoogleMark: View {
    var body: some View {
        Canvas { ctx, size in
            let s = size.width / 18
            func arc(_ from: Double, _ to: Double, _ c: Color) {
                var p = Path()
                p.addArc(center: .init(x: 9 * s, y: 9 * s), radius: 6.6 * s, startAngle: .degrees(from), endAngle: .degrees(to), clockwise: false)
                ctx.stroke(p, with: .color(c), lineWidth: 3.1 * s)
            }
            arc(-42, 10, Color(red: 0.26, green: 0.52, blue: 0.96))
            arc(10, 130, Color(red: 0.20, green: 0.66, blue: 0.33))
            arc(130, 208, Color(red: 0.98, green: 0.74, blue: 0.02))
            arc(208, 318, Color(red: 0.92, green: 0.26, blue: 0.21))
            ctx.fill(Path(CGRect(x: 9 * s, y: 7.5 * s, width: 8.1 * s, height: 3.1 * s)), with: .color(Color(red: 0.26, green: 0.52, blue: 0.96)))
        }
        .accessibilityHidden(true)
    }
}
