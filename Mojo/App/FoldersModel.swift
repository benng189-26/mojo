import AppKit
import MojoCore

/// The folders the user chose, and whether each one can be used (T09).
/// Reads only: it makes bookmarks, lists folders and counts their items.
@MainActor
final class FoldersModel: ObservableObject {
    struct Row: Identifiable {
        let folder: SavedFolder
        let status: FolderStatus
        let itemCount: Int?
        var id: UUID { folder.id }
    }

    @Published private(set) var rows: [Row] = []
    @Published var problem: String?

    private let access = FolderAccess(store: DefaultsFolderStore())

    init() { refresh() }

    /// Check every saved folder again, as on launch.
    func refresh() {
        rows = access.folders.map { folder in
            let status = access.status(of: folder)
            var count: Int?
            if case .ready = status {
                count = try? access.withAccess(to: folder) { url in
                    try FolderScanner().scan(folder: url).count
                }
            }
            return Row(folder: folder, status: status, itemCount: count)
        }
    }

    /// Show the system Open panel, starting in `start` if given. The user
    /// still has to click Open; Mojo never picks a folder by itself.
    func choose(startingIn start: URL? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        panel.prompt = "Choose"
        panel.message = "Choose the folders Mojo may tidy. Nothing changes until you approve a plan."
        if let start { panel.directoryURL = start }
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            do { try access.add(url) } catch { problem = "Mojo couldn't remember \(url.lastPathComponent)." }
        }
        refresh()
    }

    func remove(_ row: Row) {
        access.remove(id: row.folder.id)
        refresh()
    }

    /// The real home folder. Inside the sandbox, FileManager's Desktop and
    /// Downloads point into Mojo's own container, so use the account's home.
    static var realHome: URL {
        if let entry = getpwuid(getuid()), let dir = entry.pointee.pw_dir {
            return URL(fileURLWithPath: String(cString: dir), isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    static let shortcuts: [(name: String, folder: String)] = [
        ("Desktop", "Desktop"), ("Downloads", "Downloads"), ("Documents", "Documents"),
    ]
}
