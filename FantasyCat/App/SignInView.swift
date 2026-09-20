import SwiftUI

/// Username or email, and a password. The fields carry the content types that
/// let iOS offer saved passwords above the keyboard: the system does that, no
/// extension injects anything (the reason this app exists, server D30).
/// Passkeys and Google arrive with the Team ID and the sign-in handoff.
struct SignInView: View {
    @Environment(AppModel.self) private var model
    @State private var login = ""
    @State private var password = ""
    @State private var busy = false
    @State private var failure: String?

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
