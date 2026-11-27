import SwiftUI

/// Mojo app entry point. T04: an empty window only. No folder access, no
/// file changes and no network. All file changes will go through
/// MojoCore's FileEngine (AGENTS.md).
@main
struct MojoApp: App {
    var body: some Scene {
        WindowGroup("Mojo") {
            ContentView()
                .frame(minWidth: 420, minHeight: 320)
        }
        .windowResizability(.contentSize)
    }
}
