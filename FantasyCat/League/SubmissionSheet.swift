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
            }
            .padding(16)
        }
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

    private var aspect: CGFloat {
        guard let w = submission.media.width, let h = submission.media.height, w > 0, h > 0 else { return Tokens.photoRatio }
        return CGFloat(w) / CGFloat(h)
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
