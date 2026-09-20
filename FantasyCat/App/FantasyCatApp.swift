import SwiftUI

@main
struct FantasyCatApp: App {
    @State private var model = AppModel()

    init() { Typefaces.register() }

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("-gallery") {
                    GalleryView()
                } else {
                    RootView()
                }
            }
            .environment(model)
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Group {
            switch model.phase {
            case .starting:
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(PageBackground())
            case .signedOut:
                AuthFlow()
            case .signedIn(let user, let leagues):
                HomeView(user: user, leagues: leagues)
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.phase)
        .task { await model.start() }
    }
}
