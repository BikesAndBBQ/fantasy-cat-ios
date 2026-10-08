import FantasyCatCore
import SwiftUI

/// On This week: a post that outlived the run of the app that started it
/// (PostRecovery). Still going, or what went wrong and what to do about it.
struct PendingPostNotice: View {
    let post: PendingPost
    /// Nil once the round has closed: then there's nothing to post again to.
    var postAgain: (() -> Void)?
    var dismiss: () -> Void = {}

    var body: some View {
        Card {
            switch post.stage {
            case .uploading, .submitting:
                HStack(spacing: 12) {
                    ProgressView().tint(Tokens.accent)
                    Text(post.stage == .uploading ? "Your post to \(post.categoryName) is still uploading." : "Posting to \(post.categoryName)…")
                        .type(.body).foregroundStyle(Tokens.ink)
                }
                .accessibilityElement(children: .combine)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your post to \(post.categoryName) didn't go up").type(.bodyStrong).foregroundStyle(Tokens.ink)
                        Text(message).type(.small).foregroundStyle(Tokens.muted)
                    }
                    .accessibilityElement(children: .combine)
                    HStack {
                        if let postAgain { Button("Post it again", action: postAgain).buttonStyle(.fc(.primary, size: .sm)) }
                        Button("Dismiss", action: dismiss).buttonStyle(.fc(size: .sm))
                    }
                }
            }
        }
    }
}
