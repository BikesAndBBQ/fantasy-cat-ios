import SwiftUI

/// The first screen. For now it proves the app builds, is signed, launches and
/// follows the system theme and text size. Sign-in arrives in milestone 2.
struct WelcomeView: View {
    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                (Text("Fantasy ") + Text("Cat").foregroundStyle(Theme.accent) + Text(" League"))
                    .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("A weekly cat photo contest for you and your friends.")
                    .font(.body)
                    .foregroundStyle(Theme.ink.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
    }
}

#Preview("Light") { WelcomeView() }
#Preview("Dark") { WelcomeView().preferredColorScheme(.dark) }
