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

extension Components.Schemas.SubmissionView: Identifiable {}
