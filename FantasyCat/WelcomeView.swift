import SwiftUI

/// The first screen. Sign-in arrives in milestone 2.
struct WelcomeView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            (Text("Fantasy ") + Text("Cat").foregroundStyle(Tokens.accentInk) + Text(" League"))
                .type(.hero)
                .foregroundStyle(Tokens.ink)
                .accessibilityAddTraits(.isHeader)
            Text("A weekly cat photo contest for you and your friends.")
                .type(.body)
                .foregroundStyle(Tokens.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(24)
        .background(PageBackground())
    }
}

#Preview("Light") { WelcomeView() }
#Preview("Dark") { WelcomeView().preferredColorScheme(.dark) }
