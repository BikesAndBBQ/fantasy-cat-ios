import SwiftUI

@main
struct FantasyCatApp: App {
    init() { Typefaces.register() }

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-gallery") {
                GalleryView()
            } else {
                WelcomeView()
            }
        }
    }
}
