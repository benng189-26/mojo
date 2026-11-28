import SwiftUI

/// Mojo app entry point. T09: choose folders and keep access to them.
/// No file changes and no network. All file changes will go through
/// MojoCore's FileEngine (AGENTS.md).
@main
struct MojoApp: App {
    var body: some Scene {
        WindowGroup("Mojo") {
            ContentView()
                .frame(minWidth: 640, minHeight: 560)
        }
        .windowResizability(.contentSize)
    }
}
