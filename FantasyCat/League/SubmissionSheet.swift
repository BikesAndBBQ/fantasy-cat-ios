import FantasyCatCore
import AVKit
import SwiftUI

/// One post, large. The subject is the cat, so the cat's face leads.
struct SubmissionSheet: View {
    let submission: Submission
    let canDelete: Bool
    let store: LeagueStore
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?
    @State private var deleting = false
    @State private var failure: String?

    var body: some View {
        let s = submission
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Group {
                        if s.media.kind == .video, let player {
                            VideoPlayer(player: player).aspectRatio(aspect, contentMode: .fit)
                        } else {
                            MediaTile(media: s.media, large: true).aspectRatio(aspect, contentMode: .fit)
                        }
                    }
                    .frame(maxWidth: .infinity).frame(maxHeight: 520)
                    .background(Tokens.sunken).clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.card, style: .continuous))
                    .accessibilityLabel("\(s.petName), posted by \(s.manager.displayName)")

                    HStack(spacing: 10) {
                        Avatar(url: s.petPhotoUrl.flatMap(URL.init(string:)), kind: .cat, size: .md)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.petName).type(.bodyStrong).foregroundStyle(Tokens.ink)
                            Text("\(s.manager.displayName), \(TimeText.ago(s.createdAt))").type(.small).foregroundStyle(Tokens.muted)
                        }
                        Spacer()
                        Button("Close") { dismiss() }.buttonStyle(.fc(size: .sm))
                    }
                    if !s.caption.isEmpty { Text(s.caption).type(.body).foregroundStyle(Tokens.ink) }
                    Reactions(submission: s, store: store)
                    if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
                    if s.isMine, canDelete {
                        Button("Take it down") {
                            deleting = true
                            Task {
                                failure = await store.delete(s)
                                deleting = false
                                if failure == nil { dismiss() }
                            }
                        }
                        .buttonStyle(.fc(.danger, size: .sm, busy: deleting))
                    }
                    if !s.isMine { ReportOrBlock(submission: s, store: store) { dismiss() } }
                    Comments(submission: s, store: store, scroll: scroll)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Tokens.paper)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .onAppear {
                if s.media.kind == .video, let url = s.media.displayUrl.flatMap(URL.init(string:)) {
                    let p = AVPlayer(url: url)
                    player = p
                    p.play()
                }
            }
            .onDisappear { player?.pause() }
        }
    }

    private var aspect: CGFloat {
        guard let w = submission.media.width, let h = submission.media.height, w > 0, h > 0 else { return Tokens.photoRatio }
        return CGFloat(w) / CGFloat(h)
    }
}

/// The post's reactions (server designs/20261017-reactions.md): tap to add
/// or take back, optimistic, with the server's answer replacing the guess.
/// Your own post shows counts and names only.
private struct Reactions: View {
    typealias Reaction = Components.Schemas.ReactionView
    let submission: Submission
    let store: LeagueStore
    @State private var reactions: [Reaction]
    @State private var busy = false
    @State private var failure: String?

    init(submission: Submission, store: LeagueStore) {
        self.submission = submission
        self.store = store
        _reactions = State(initialValue: submission.reactions ?? [])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ReactionRow(reactions: reactions, quickPicks: store.league?.quickReactions ?? [], readOnly: submission.isMine, busy: busy) { emoji, on in
                toggle(emoji, on: on)
            }
            if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
        }
    }

    private func toggle(_ emoji: String, on: Bool) {
        let before = reactions
        var next = reactions.compactMap { r -> Reaction? in
            guard r.emoji == emoji else { return r }
            var r = r
            r.count += on ? 1 : -1
            r.isMine = on
            r.by = on ? (r.by ?? []) + ["you"] : (r.by ?? []).filter { $0 != "you" }
            return r.count > 0 ? r : nil
        }
        if on, !before.contains(where: { $0.emoji == emoji }) { next.append(Reaction(by: ["you"], count: 1, emoji: emoji, isMine: true)) }
        reactions = next
        failure = nil
        busy = true
        Task {
            let out = await store.react(submission, emoji: emoji, on: on)
            if let r = out.reactions { reactions = r } else { reactions = before; failure = out.failure }
            busy = false
        }
    }
}

/// The post's thread and the composer (server designs/20261019-comments.md,
/// D55): fetched when the sheet opens, oldest first. Each comment's "…" menu
/// offers Delete on yours, Remove from your post on your own post, Report
/// on someone else's. The composer sits last, so it is above the keyboard
/// when it has focus; after a send the sheet scrolls it back above the
/// keyboard, since the new comment has pushed it down (Ryan, sc-3492).
private struct Comments: View {
    typealias Comment = LeagueStore.Comment
    let submission: Submission
    let store: LeagueStore
    let scroll: ScrollViewProxy
    @State private var comments: [Comment]?
    @State private var draft = ""
    @State private var sending = false
    @State private var reporting: Comment?
    @State private var reason = ""
    @State private var busy = false
    @State private var failure: String?
    @FocusState private var composing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider().overlay(Tokens.line)
            Eyebrow(title)
            if let comments {
                if comments.isEmpty {
                    Text("Nothing yet. Say something nice.").type(.small).foregroundStyle(Tokens.muted)
                }
                ForEach(comments, id: \.id) { c in
                    CommentRow(name: c.isMine ? "You" : c.author.displayName, avatar: c.author.avatarUrl.flatMap(URL.init(string:)),
                               when: c.createdAt, text: c.body, actions: actions(for: c)) { a in act(a, on: c) }
                    if reporting?.id == c.id { reportForm(c) }
                }
            } else {
                ProgressView().tint(Tokens.muted).frame(maxWidth: .infinity)
            }
            if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
            Composer(text: $draft, busy: sending, send: send, focused: $composing).id("composer")
        }
        .task { await load() }
    }

    private var title: String {
        guard let n = comments?.count, n > 0 else { return "Comments" }
        return n == 1 ? "1 comment" : "\(n) comments"
    }

    private func actions(for c: Comment) -> [CommentRow.Action] {
        if c.isMine { return [.delete] }
        var a: [CommentRow.Action] = []
        if c.canRemove { a.append(.remove) }
        a.append(.report)
        return a
    }

    @ViewBuilder private func reportForm(_ c: Comment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            FCField(label: "What's wrong with it?", text: $reason, help: "Optional. Only the people who run Fantasy Cat see this.")
            HStack(spacing: 10) {
                Button("Report this comment") {
                    busy = true
                    Task {
                        failure = await store.reportComment(c, reason: reason)
                        busy = false
                        if failure == nil { comments?.removeAll { $0.id == c.id }; reporting = nil; reason = "" }
                    }
                }
                .buttonStyle(.fc(.danger, size: .sm, busy: busy)).accessibilityIdentifier("send-comment-report")
                Button("Cancel") { reporting = nil; reason = "" }.buttonStyle(.fc(size: .sm))
            }
        }
        .padding(.leading, 36)
    }

    private func load() async {
        let out = await store.comments(of: submission)
        if let c = out.comments { comments = c } else { comments = []; failure = out.failure }
    }

    private func act(_ a: CommentRow.Action, on c: Comment) {
        failure = nil
        switch a {
        case .report: reporting = c
        case .delete, .remove:
            let before = comments
            comments?.removeAll { $0.id == c.id } // gone at once; back if the server says no
            Task {
                if let f = await store.deleteComment(c, on: submission) { failure = f; comments = before }
            }
        }
    }

    private func send() {
        let body = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, !sending else { return }
        sending = true
        failure = nil
        Task {
            let out = await store.comment(on: submission, body: body)
            sending = false
            if let c = out.comment {
                comments = (comments ?? []) + [c]
                draft = ""
                // Once the thread has laid out with the new comment, bring the
                // composer back up above the keyboard; it keeps focus for the next one.
                try? await Task.sleep(for: .milliseconds(80))
                withAnimation(.easeOut(duration: 0.2)) { scroll.scrollTo("composer", anchor: .bottom) }
            } else {
                failure = out.failure
            }
        }
    }
}

/// Report this post, or block the person who posted it (server D41). Each
/// asks once before it acts; both hide what they're about at once.
private struct ReportOrBlock: View {
    let submission: Submission
    let store: LeagueStore
    let done: () -> Void
    private enum Step { case choose, report, block }
    @State private var step = Step.choose
    @State private var reason = ""
    @State private var busy = false
    @State private var failure: String?

    init(submission: Submission, store: LeagueStore, done: @escaping () -> Void) {
        self.submission = submission
        self.store = store
        self.done = done
        #if DEBUG
        // `-openpost report` / `-openpost block`: start at that step, to see it.
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-openpost"), args.indices.contains(i + 1) {
            _step = State(initialValue: args[i + 1] == "report" ? .report : args[i + 1] == "block" ? .block : .choose)
        }
        #endif
    }

    var body: some View {
        let name = submission.manager.displayName
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(Tokens.line)
            switch step {
            case .choose:
                HStack(spacing: 10) {
                    Button("Report post") { step = .report }.buttonStyle(.fc(size: .sm)).accessibilityIdentifier("report-post")
                    Button("Block \(name)") { step = .block }.buttonStyle(.fc(size: .sm)).accessibilityIdentifier("block-member")
                }
            case .report:
                FCField(label: "What's wrong with it?", text: $reason, help: "Optional. Only the people who run Fantasy Cat see this.")
                failureText
                HStack(spacing: 10) {
                    Button("Report this post") { act { await store.report(submission, reason: reason) } }
                        .buttonStyle(.fc(.danger, size: .sm, busy: busy)).accessibilityIdentifier("send-report")
                    Button("Cancel") { step = .choose }.buttonStyle(.fc(size: .sm))
                }
            case .block:
                Text("Block \(name)? Their posts disappear for you: in the feed, on your ballot and in results. They aren't told. You can unblock them on your account page.")
                    .type(.body).foregroundStyle(Tokens.ink)
                failureText
                HStack(spacing: 10) {
                    Button("Block \(name)") { act { await store.block(submission.manager) } }
                        .buttonStyle(.fc(.danger, size: .sm, busy: busy)).accessibilityIdentifier("confirm-block")
                    Button("Cancel") { step = .choose }.buttonStyle(.fc(size: .sm))
                }
            }
        }
    }

    @ViewBuilder private var failureText: some View {
        if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
    }

    private func act(_ call: @escaping () async -> String?) {
        busy = true
        Task {
            failure = await call()
            busy = false
            if failure == nil { done() }
        }
    }
}

extension Components.Schemas.SubmissionView: Identifiable {}
