import SwiftUI
import MojoCore

/// Placeholder window for T04. Shows the folders Mojo sorts into, read from
/// MojoCore, to prove the app links the package. Reads no user folder.
struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mojo")
                .font(.largeTitle.bold())
            Text("Not ready yet. When it is, Mojo will sort these into folders:")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(FileCategory.allCases, id: \.self) { category in
                    Label(category.folderName, systemImage: "folder")
                }
            }
            Spacer()
        }
        .padding(24)
    }
}

#Preview {
    ContentView()
}
