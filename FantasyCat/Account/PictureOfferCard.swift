import SwiftUI

/// "Use your Google picture?" Asked once, of someone with no picture who
/// signed in with Google (server sc-289, D47); either answer ends it for good.
/// The web's PictureOfferCard, with the picture shown: the app has no CSP
/// keeping Google's images out.
struct PictureOfferCard: View {
    let picture: URL?
    /// Returns what to tell the person if it failed, or nil.
    let answer: (Bool) async -> String?
    @State private var busy: Bool?
    @State private var failure: String?

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Eyebrow("Your picture")
                HStack(spacing: 12) {
                    Avatar(url: picture, kind: .person, size: .md)
                    Text("You don't have a picture yet. Use the one from your Google account?")
                        .type(.body).foregroundStyle(Tokens.muted)
                }
                if let failure { Text(failure).type(.small).foregroundStyle(Tokens.danger) }
                HStack {
                    Button("Use my Google picture") { reply(true) }
                        .buttonStyle(.fc(.ink, size: .sm, busy: busy == true))
                        .accessibilityIdentifier("picture-offer-use")
                    Button("No thanks") { reply(false) }
                        .buttonStyle(.fc(size: .sm, busy: busy == false))
                        .accessibilityIdentifier("picture-offer-no")
                }
                .disabled(busy != nil)
            }
        }
    }

    private func reply(_ use: Bool) {
        busy = use
        failure = nil
        Task {
            failure = await answer(use)
            busy = nil
        }
    }
}
