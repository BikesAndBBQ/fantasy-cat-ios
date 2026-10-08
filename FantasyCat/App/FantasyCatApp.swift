import SwiftUI

@main
struct FantasyCatApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
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

/// For what SwiftUI has no word for: the upload session waking the app.
/// A launch for that may be in the background with no window, so recovery
/// starts here rather than in a view.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        Uploader.shared.reconnect()
        PostRecovery.shared.sweep()
        return true
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        nonisolated(unsafe) let done = completionHandler // called once, on the main queue
        Uploader.shared.reconnect { done() }
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
        // Universal links (fantasycat.co/join/…, release app only: the server's
        // apple-app-site-association leaves the Debug app out).
        .onOpenURL { model.open($0) }
        .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
            if let url = activity.webpageURL { model.open(url) }
        }
        #if DEBUG
        // `-openurl <url>`: what tapping that link does, for the Debug app that can't be given one.
        .task {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-openurl"), args.indices.contains(i + 1), let url = URL(string: args[i + 1]) { model.open(url) }
        }
        #endif
        .task { await model.start() }
        .task { await model.checkForUpdate() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.checkForUpdate() } }
        }
    }
}
