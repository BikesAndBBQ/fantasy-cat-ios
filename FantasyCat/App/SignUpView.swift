import SwiftUI

struct SignUpView: View {
    @Environment(AppModel.self) private var model
    let back: () -> Void
    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var invite = ""
    @State private var reminders = true
    @State private var busy = false
    @State private var failure: String?

    private var ready: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && username.count >= 3 && email.contains("@") && password.count >= 10
    }

    var body: some View {
        AuthPage(title: "Create an account", lede: "Takes a minute. Then add your cats.") {
            if let failure { AuthNotice(text: failure, bad: true) }
            FCField(label: "Your name", text: $name, help: "What the other managers see.", contentType: .name)
            FCField(label: "Username", text: $username, help: "Letters, numbers and underscores.", contentType: .username)
            FCField(label: "Email", text: $email, help: "For password resets and round reminders.", contentType: .emailAddress, keyboard: .emailAddress)
            FCField(label: "Password", text: $password, help: "Ten characters or more. A suggested strong password is perfect.", secure: true, contentType: .newPassword)
            FCField(label: "Invite code", text: $invite, help: "Optional. If a friend sent you a link, paste it here to join their league.")
            Toggle(isOn: $reminders) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Email me round reminders").type(.bodyStrong).foregroundStyle(Tokens.ink)
                    Text("A nudge when rounds open, close and post. Easy to turn off later.").type(.small).foregroundStyle(Tokens.muted)
                }
            }
            .tint(Tokens.ink)
            Button("Create account") { submit() }.buttonStyle(.fc(.primary, block: true, busy: busy)).disabled(!ready || busy).accessibilityIdentifier("signup-submit")
        } footer: {
            AuthFooterLink(lead: "Already have one?", action: "Sign in", perform: back)
        }
        #if DEBUG
        .task {
            // `-autosignup <username>`: fill the form with that name and submit.
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "-autosignup"), args.indices.contains(i + 1) else { return }
            (name, username, email, password) = (args[i + 1].capitalized, args[i + 1], "\(args[i + 1])@example.com", "fantasy-cat-dev")
            if !args.contains("-nosubmit") { submit() }
        }
        #endif
    }

    private func submit() {
        busy = true
        failure = nil
        let code = invite.trimmingCharacters(in: .whitespacesAndNewlines)
        let inviteCode = code.isEmpty ? nil : (URL(string: code).flatMap { $0.scheme != nil ? $0.pathComponents.last : nil } ?? code).lowercased()
        Task {
            do {
                try await model.signUp(name: name.trimmingCharacters(in: .whitespaces), username: username.trimmingCharacters(in: .whitespaces),
                                       email: email.trimmingCharacters(in: .whitespaces), password: password, reminders: reminders, invite: inviteCode)
            } catch { failure = Failure.from(error).message }
            busy = false
        }
    }
}

struct ForgotPasswordView: View {
    @Environment(AppModel.self) private var model
    let back: () -> Void
    @State private var email = ""
    @State private var busy = false
    @State private var sent = false
    @State private var failure: String?

    var body: some View {
        AuthPage(title: "Forgot your password?", lede: "We'll email you a link to choose a new one.") {
            if let failure { AuthNotice(text: failure, bad: true) }
            if sent {
                AuthNotice(text: "If that address has an account, a reset link is on its way. It works for an hour.", bad: false)
            } else {
                FCField(label: "Email", text: $email, contentType: .emailAddress, keyboard: .emailAddress)
                Button("Send reset link") {
                    busy = true
                    failure = nil
                    Task {
                        do { try await model.forgotPassword(email: email.trimmingCharacters(in: .whitespaces)); sent = true } catch { failure = Failure.from(error).message }
                        busy = false
                    }
                }
                .buttonStyle(.fc(.primary, block: true, busy: busy)).disabled(!email.contains("@") || busy)
            }
        } footer: {
            AuthFooterLink(lead: "Remembered it?", action: "Sign in", perform: back)
        }
    }
}

// MARK: Shared frame for the signed-out screens

struct AuthPage<Content: View, Footer: View>: View {
    let title: String
    var lede: String?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                (Text("Fantasy ") + Text("Cat").foregroundStyle(Tokens.accentInk) + Text(" League")).type(.wordmark).foregroundStyle(Tokens.ink)
                VStack(alignment: .leading, spacing: 8) {
                    Text(title).type(.hero).foregroundStyle(Tokens.ink).accessibilityAddTraits(.isHeader)
                    if let lede { Text(lede).type(.body).foregroundStyle(Tokens.muted) }
                }
                VStack(alignment: .leading, spacing: 16) { content }
                footer
            }
            .padding(24)
            .padding(.top, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(PageBackground())
    }
}

struct AuthNotice: View {
    let text: String
    let bad: Bool
    var body: some View {
        Text(text).type(.small).foregroundStyle(bad ? Tokens.danger : Tokens.good).padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background((bad ? Tokens.danger : Tokens.good).opacity(0.12), in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
    }
}

struct AuthFooterLink: View {
    let lead: String
    let action: String
    let perform: () -> Void
    var body: some View {
        HStack(spacing: 5) {
            Text(lead).type(.small).foregroundStyle(Tokens.muted)
            Button(action, action: perform).type(.smallStrong).foregroundStyle(Tokens.ink).underline()
        }
        .frame(minHeight: 44)
    }
}
