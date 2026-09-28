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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if let update = model.updateRequired {
                UpdateRequiredView(update: update) // replaces the app, not a sheet over it (I13)
            } else {
                switch model.phase {
                case .starting:
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity).background(PageBackground())
                case .signedOut:
                    AuthFlow()
                case .signedIn(let user, let leagues):
                    HomeView(user: user, leagues: leagues)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: model.phase)
        .animation(.easeOut(duration: 0.2), value: model.updateRequired)
        .task { await model.start() }
        .task { await model.checkForUpdate() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.checkForUpdate() } }
        }
    }
}
