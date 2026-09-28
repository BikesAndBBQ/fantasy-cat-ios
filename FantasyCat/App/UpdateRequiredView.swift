import SwiftUI

/// Shown instead of everything else when the server says this build is too
/// old (I13). There is deliberately no way past it: no close, no "later".
struct UpdateRequiredView: View {
    let update: AppModel.UpdateRequired
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                (Text("Fantasy ") + Text("Cat").foregroundStyle(Tokens.accentInk) + Text(" League"))
                    .type(.wordmark).foregroundStyle(Tokens.ink)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Time to update").type(.hero).foregroundStyle(Tokens.ink).accessibilityAddTraits(.isHeader)
                    Text(update.message).type(.body).foregroundStyle(Tokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("update-message")
                }
                VStack(alignment: .leading, spacing: 12) {
                    if let url = update.url {
                        Button("Update the app") { openURL(url) }
                            .buttonStyle(.fc(.primary, block: true))
                            .accessibilityIdentifier("update-open")
                    }
                    Text("Opens TestFlight. When the new version is installed, open Fantasy Cat League again.")
                        .type(.small).foregroundStyle(Tokens.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(24)
            .padding(.top, 40)
        }
        .background(PageBackground())
    }
}
