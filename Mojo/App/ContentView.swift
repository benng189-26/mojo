import SwiftUI
import MojoCore

/// Main window. Shows the folders Mojo sorts into (from MojoCore) and the
/// Folders screen (T09). Reads only folders the user chose.
struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mojo")
                .font(.largeTitle.bold())
            Text("Mojo will sort loose files into these folders:")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(FileCategory.allCases, id: \.self) { category in
                    Label(category.folderName, systemImage: "folder")
                }
            }
            Divider()
            FoldersView()
        }
        .padding(24)
    }
}

#Preview {
    ContentView()
}
