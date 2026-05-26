import SwiftUI

@main
struct RedditDesktopApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1184, height: 761)
    }
}
