import SwiftUI

/// You, your cats, and the way out. The counterpart of the web's /account,
/// minus what still lives there: managing passkeys.
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
    @State private var blocked: [Components.Schemas.PersonView] = []
    var onLeagues: (() -> Void)?

    private var user: Components.Schemas.UserView? { if case .signedIn(let u, _) = model.phase { u } else { nil } }

    var body: some View {
        ScrollViewReader { proxy in
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
                    PasswordSection(hasPassword: user.hasPassword)
                    Divider().overlay(Tokens.line)
                    VStack(alignment: .leading, spacing: 10) {
                        if let onLeagues { Button("Start or join another league") { dismiss(); onLeagues() }.buttonStyle(.fc(size: .sm)) }
                        Text("Passkeys are still managed at fantasycat.co.").type(.small).foregroundStyle(Tokens.muted)
                        Button("Sign out") { Task { dismiss(); await model.signOut() } }.buttonStyle(.fc(.danger, size: .sm)).accessibilityIdentifier("sign-out")
                    }
                    if !blocked.isEmpty {
                        Divider().overlay(Tokens.line)
                        BlockedSection(blocked: $blocked)
                    }
                    Divider().overlay(Tokens.line)
                    DeleteAccountSection().id("delete-account")
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
            blocked = await BlockedSection.load()
            #if DEBUG
            // `-addcat <name>` and `-setavatar <file>` press the same buttons from the command line.
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-addcat"), args.indices.contains(i + 1), !s.pets.contains(where: { $0.name == args[i + 1] }) { failure = await s.addCat(args[i + 1]) }
            if let i = args.firstIndex(of: "-setavatar"), args.indices.contains(i + 1) {
                do { failure = await s.setAvatar(mediaID: try await MediaUpload.photo(URL(fileURLWithPath: args[i + 1]))) } catch { failure = Failure.from(error).message }
            }
            // `-deleteaccount` (see DeleteAccountSection) also scrolls there, to see what it says.
            if args.contains("-deleteaccount") { try? await Task.sleep(for: .seconds(1)); proxy.scrollTo("delete-account", anchor: .bottom) }
            #endif
        }
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

/// The members you've blocked (server D41), each with a way back. The
/// account screen shows it only when there are any: most people never block
/// anyone. (It loads them there: an absent view never runs its own `.task`.)
private struct BlockedSection: View {
    @Binding var blocked: [Components.Schemas.PersonView]
    @State private var busy: Int64?
    @State private var failure: String?

    static func load() async -> [Components.Schemas.PersonView] {
        guard case .ok(let ok) = try? await API.client.listBlocks(), let body = try? ok.body.json else { return [] }
        return body.blocked ?? []
    }

    var body: some View {
                VStack(alignment: .leading, spacing: 10) {
                    Eyebrow("Blocked")
                    Text("You don't see their posts. Unblock someone to see them again.").type(.small).foregroundStyle(Tokens.muted)
                    if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
                    ForEach(blocked, id: \.id) { p in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(p.displayName).type(.bodyStrong).foregroundStyle(Tokens.ink)
                                Text("@\(p.username)").type(.small).foregroundStyle(Tokens.muted)
                            }
                            Spacer()
                            Button("Unblock") { Task { await unblock(p) } }
                                .buttonStyle(.fc(size: .sm, busy: busy == p.id))
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Tokens.surface)
                        .overlay(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous).stroke(Tokens.line, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                    }
                }
    }

    private func unblock(_ p: Components.Schemas.PersonView) async {
        busy = p.id
        defer { busy = nil }
        do {
            switch try await API.client.unblockUser(path: .init(id: p.id)) {
            case .noContent: failure = nil; blocked = await Self.load()
            case .default(let status, let prob): failure = Failure.from(status: status, try? prob.body.applicationProblemJson).message
            }
        } catch { failure = Failure.from(error).message }
    }
}

/// The same two steps as the web's: ask, then confirm in place.
private struct DeleteAccountSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var sure = false
    @State private var busy = false
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Eyebrow("Delete account")
            Text("Removes your account, your cats, and every photo and video you posted, from our servers too. Your leagues keep going without you; the points other people earned stay.").type(.small).foregroundStyle(Tokens.muted)
            if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
            if sure {
                Text("Delete your account? This can't be undone.").type(.bodyStrong).foregroundStyle(Tokens.ink)
                HStack(spacing: 10) {
                    Button("Yes, delete everything") {
                        busy = true
                        failure = nil
                        Task {
                            do { try await model.deleteAccount(); dismiss() } catch { failure = Failure.from(error).message; sure = false }
                            busy = false
                        }
                    }
                    .buttonStyle(.fc(.danger, size: .sm, busy: busy))
                    .disabled(busy)
                    .accessibilityIdentifier("confirm-delete-account")
                    Button("Keep it") { sure = false }.buttonStyle(.fc(size: .sm)).disabled(busy)
                }
            } else {
                Button("Delete my account") { sure = true }.buttonStyle(.fc(.danger, size: .sm)).accessibilityIdentifier("delete-account")
            }
        }
        #if DEBUG
        // `-deleteaccount ask` presses the first button, `-deleteaccount yes` both.
        .task {
            let args = ProcessInfo.processInfo.arguments
            guard let i = args.firstIndex(of: "-deleteaccount"), args.indices.contains(i + 1) else { return }
            sure = true
            guard args[i + 1] == "yes" else { return }
            busy = true
            do { try await model.deleteAccount() } catch { failure = Failure.from(error).message; sure = false }
            busy = false
        }
        #endif
    }
}

private struct PasswordSection: View {
    @Environment(AppModel.self) private var model
    let hasPassword: Bool
    @State private var current = ""
    @State private var new = ""
    @State private var busy = false
    @State private var failure: String?
    @State private var done = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Eyebrow("Password")
            if !hasPassword {
                Text("You sign in with Google or a passkey. Adding a password gives you another way in.").type(.small).foregroundStyle(Tokens.muted)
            }
            if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
            if done { Text(hasPassword ? "Password changed." : "Password set.").type(.small).foregroundStyle(Tokens.good) }
            if hasPassword { FCField(label: "Current password", text: $current, secure: true, contentType: .password) }
            FCField(label: hasPassword ? "New password" : "Password", text: $new, help: "Ten characters or more.", secure: true, contentType: .newPassword)
            Button(hasPassword ? "Change password" : "Set a password") {
                busy = true
                failure = nil
                done = false
                Task {
                    do { try await model.changePassword(current: hasPassword ? current : nil, new: new); done = true; current = ""; new = "" } catch { failure = Failure.from(error).message }
                    busy = false
                }
            }
            .buttonStyle(.fc(busy: busy))
            .disabled(busy || new.count < 10 || (hasPassword && current.isEmpty))
        }
    }
}
