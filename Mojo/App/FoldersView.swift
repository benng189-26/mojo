import SwiftUI
import MojoCore

/// T09: choose folders, see whether each is ready, remove from the list.
struct FoldersView: View {
    @StateObject private var model = FoldersModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Folders").font(.title.bold())
            Text("Mojo only looks at folders you choose here. It doesn't sort anything yet.")
                .foregroundStyle(.secondary)

            if model.rows.isEmpty {
                Text("No folders yet.").foregroundStyle(.secondary)
            } else {
                List(model.rows) { row in
                    FolderRow(row: row,
                              chooseAgain: { model.choose(startingIn: URL(fileURLWithPath: row.folder.path).deletingLastPathComponent()) },
                              remove: { model.remove(row) })
                }
                .frame(minHeight: 160)
            }

            HStack {
                Button("Choose folder…") { model.choose() }
                    .keyboardShortcut("o")
                ForEach(FoldersModel.shortcuts, id: \.name) { shortcut in
                    Button(shortcut.name) {
                        model.choose(startingIn: FoldersModel.realHome.appendingPathComponent(shortcut.folder, isDirectory: true))
                    }
                    .help("Opens the Choose window at \(shortcut.name). You still click Choose.")
                }
                Spacer()
                Button("Check again") { model.refresh() }
            }
            if let problem = model.problem {
                Text(problem).foregroundStyle(.red)
            }
        }
    }
}

private struct FolderRow: View {
    let row: FoldersModel.Row
    let chooseAgain: () -> Void
    let remove: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "folder")
            VStack(alignment: .leading, spacing: 2) {
                Text(row.folder.name).bold()
                Text(row.folder.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                Text(statusText).font(.caption).foregroundStyle(isReady ? Color.secondary : Color.orange)
            }
            Spacer()
            if !isReady { Button("Choose again…", action: chooseAgain) }
            Button("Remove from list", action: remove)
                .help("Mojo forgets this folder. The folder itself is not changed.")
        }
        .accessibilityElement(children: .combine)
    }

    private var isReady: Bool {
        if case .ready = row.status { return true }
        return false
    }

    private var statusText: String {
        switch row.status {
        case .ready:
            if let count = row.itemCount { return "Ready: \(count) item\(count == 1 ? "" : "s") at the top level" }
            return "Ready"
        case .chooseAgain(.renamedOrMoved): return "This folder was renamed or moved. Choose it again."
        case .chooseAgain(.missing): return "Mojo can't find this folder. Choose it again."
        case .chooseAgain(.noAccess): return "Mojo no longer has permission. Choose it again."
        }
    }
}
