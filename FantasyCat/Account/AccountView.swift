import SwiftUI

/// You, your cats, and the way out. The counterpart of the web's /account,
/// minus what still lives there: changing your password and managing passkeys.
struct AccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var store: AccountStore?
    @State private var name = ""
    @State private var username = ""
    @State private var newCat = ""
    @State private var saving = false
    @State private var adding = false
    @State private var notice: String?
    @State private var failure: String?
    var onLeagues: (() -> Void)?

    private var user: Components.Schemas.UserView? { if case .signedIn(let u, _) = model.phase { u } else { nil } }

    var body: some View {
        ScrollView {
            if let user, let store {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Spacer()
                        Button("Done") { dismiss() }.buttonStyle(.fc(size: .sm))
                    }
                    header(user, store)
                    if let failure { banner(failure, bad: true) }
                    if let notice { banner(notice, bad: false) }
                    if !user.emailVerified { confirmEmail(user, store) }
                    cats(store)
                    Divider().overlay(Tokens.line)
                    profile(user, store)
                    Divider().overlay(Tokens.line)
                    reminders(user, store)
                    Divider().overlay(Tokens.line)
                    VStack(alignment: .leading, spacing: 10) {
                        if let onLeagues { Button("Start or join another league") { dismiss(); onLeagues() }.buttonStyle(.fc(size: .sm)) }
                        Text("Changing your password and managing passkeys still happen at fantasycat.co.").type(.small).foregroundStyle(Tokens.muted)
                        Button("Sign out") { Task { dismiss(); await model.signOut() } }.buttonStyle(.fc(.danger, size: .sm)).accessibilityIdentifier("sign-out")
                    }
                }
                .padding(20)
            } else {
                ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Tokens.paper)
        .task {
            let s = AccountStore(model: model)
            store = s
            name = user?.displayName ?? ""
            username = user?.username ?? ""
            await s.loadPets()
            #if DEBUG
            // `-addcat <name>` and `-setavatar <file>` press the same buttons from the command line.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-addcat"), args.indices.contains(i + 1), !s.pets.contains(where: { $0.name == args[i + 1] }) { failure = await s.addCat(args[i + 1]) }
            if let i = args.firstIndex(of: "-setavatar"), args.indices.contains(i + 1) {
                do { failure = await s.setAvatar(mediaID: try await MediaUpload.photo(URL(fileURLWithPath: args[i + 1]))) } catch { failure = Failure.from(error).message }
            }
            #endif
        }
    }

    private func header(_ user: Components.Schemas.UserView, _ store: AccountStore) -> some View {
        HStack(spacing: 16) {
            AvatarPicker(url: user.avatarUrl.flatMap(URL.init(string:)), kind: .person, size: .lg, label: "Change your picture") { await store.setAvatar(mediaID: $0) }
            VStack(alignment: .leading, spacing: 4) {
                PageTitle(user.displayName, eyebrow: "@\(user.username)")
                HStack(spacing: 6) {
                    Text("Tap the picture to change it.").type(.small).foregroundStyle(Tokens.muted)
                    if user.avatarUrl != nil {
                        Button("Remove") { Task { failure = await store.removeAvatar() } }.type(.smallStrong).foregroundStyle(Tokens.ink).underline()
                    }
                }
            }
        }
    }

    private func confirmEmail(_ user: Components.Schemas.UserView, _ store: AccountStore) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Confirm your email")
                Text("We sent a link to \(user.email). Until it's confirmed, a password reset can't reach you.").type(.body).foregroundStyle(Tokens.muted)
                Button("Send it again") { Task { failure = await store.resendVerification(); if failure == nil { notice = "Confirmation email sent." } } }.buttonStyle(.fc(size: .sm))
            }
        }
    }

    private func cats(_ store: AccountStore) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow("Your cats")
            if store.loaded, store.pets.isEmpty {
                Text("Add the cats you'll be entering. Every post is tagged with one.").type(.body).foregroundStyle(Tokens.muted)
            }
            ForEach(store.pets, id: \.id) { pet in CatRow(pet: pet, store: store) { failure = $0 } }
            HStack(alignment: .bottom, spacing: 10) {
                FCField(label: "Add a cat", text: $newCat)
                Button("Add") {
                    adding = true
                    Task {
                        failure = await store.addCat(newCat.trimmingCharacters(in: .whitespaces))
                        if failure == nil { newCat = "" }
                        adding = false
                    }
                }
                .buttonStyle(.fc(.ink, busy: adding))
                .disabled(newCat.trimmingCharacters(in: .whitespaces).isEmpty || adding)
                .accessibilityIdentifier("add-cat")
            }
        }
    }

    private func profile(_ user: Components.Schemas.UserView, _ store: AccountStore) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Profile")
            FCField(label: "Your name", text: $name, contentType: .name)
            FCField(label: "Username", text: $username, help: "What you sign in with, and how you appear as @name. Capitals are kept; signing in ignores them.", contentType: .username)
            Button("Save profile") {
                saving = true
                Task {
                    failure = await store.saveProfile(name: name.trimmingCharacters(in: .whitespaces), username: username.trimmingCharacters(in: .whitespaces))
                    notice = failure == nil ? "Profile saved." : nil
                    saving = false
                }
            }
            .buttonStyle(.fc(busy: saving))
            .disabled(saving || name.trimmingCharacters(in: .whitespaces).isEmpty || (name == user.displayName && username == user.username))
        }
    }

    private func reminders(_ user: Components.Schemas.UserView, _ store: AccountStore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow("Round reminders")
            Toggle(isOn: Binding(get: { user.notifyEmail }, set: { on in Task { failure = await store.setReminders(on, name: user.displayName) } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Email me round reminders").type(.bodyStrong).foregroundStyle(Tokens.ink)
                    Text("When a round opens, the day before it closes, when voting starts, and when results post.").type(.small).foregroundStyle(Tokens.muted)
                }
            }
            .tint(Tokens.ink)
        }
    }

    private func banner(_ text: String, bad: Bool) -> some View {
        Text(text).type(.small).foregroundStyle(bad ? Tokens.danger : Tokens.good).padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background((bad ? Tokens.danger : Tokens.good).opacity(0.12), in: RoundedRectangle(cornerRadius: Tokens.Radius.field, style: .continuous))
    }
}

private struct CatRow: View {
    let pet: Pet
    let store: AccountStore
    let report: (String?) -> Void
    @State private var editing = false
    @State private var name = ""
    @State private var busy = false

    var body: some View {
        Card {
            if editing {
                HStack(alignment: .bottom, spacing: 8) {
                    FCField(label: "Name", text: $name)
                    Button("Save") { act { await store.rename(pet, to: name.trimmingCharacters(in: .whitespaces)) } }.buttonStyle(.fc(.ink, size: .sm, busy: busy))
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") { editing = false }.buttonStyle(.fc(size: .sm))
                }
            } else {
                HStack(spacing: 12) {
                    AvatarPicker(url: pet.photo?.thumbUrl.flatMap(URL.init(string:)), kind: .cat, label: "Change \(pet.name)'s picture") { await store.setPhoto(pet, mediaID: $0) }
                    Text(pet.name).type(.bodyStrong).foregroundStyle(Tokens.ink).lineLimit(1)
                    Spacer()
                    Button("Rename") { name = pet.name; editing = true }.buttonStyle(.fc(size: .sm))
                    Button("Remove") { act { await store.remove(pet) } }.buttonStyle(.fc(.danger, size: .sm, busy: busy))
                }
            }
        }
    }

    private func act(_ work: @escaping () async -> String?) {
        busy = true
        Task {
            let problem = await work()
            report(problem)
            if problem == nil { editing = false }
            busy = false
        }
    }
}
