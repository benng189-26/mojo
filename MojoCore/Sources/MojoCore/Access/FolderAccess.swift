import Foundation

/// One folder the user chose, as Mojo remembers it.
public struct SavedFolder: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    /// Where the folder was when the user chose it.
    public var path: String
    /// Bookmark that lets Mojo open the folder again after a restart.
    public var bookmark: Data

    public init(id: UUID = UUID(), path: String, bookmark: Data) {
        self.id = id
        self.path = path
        self.bookmark = bookmark
    }

    public var name: String { URL(fileURLWithPath: path).lastPathComponent }
}

/// Why a saved folder can't be used until the user chooses it again
/// (spec: Technical issues, Folder access).
public enum ChooseAgainReason: String, Codable, Sendable {
    case renamedOrMoved     // it resolves, but not at the path the user chose
    case missing            // it can't be found any more
    case noAccess           // it's there, but Mojo may not open it
}

public enum FolderStatus: Equatable, Sendable {
    case ready(URL)
    case chooseAgain(ChooseAgainReason)
}

/// Where the list of saved folders is kept. The app uses its own
/// preferences; tests use memory. Never inside the user's folders.
public protocol FolderStore: AnyObject {
    func load() -> [SavedFolder]
    func save(_ folders: [SavedFolder])
}

/// Saves the list in the app's own preferences (UserDefaults).
public final class DefaultsFolderStore: FolderStore {
    private let defaults: UserDefaults
    private let key = "savedFolders.v1"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func load() -> [SavedFolder] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedFolder].self, from: data)) ?? []
    }

    public func save(_ folders: [SavedFolder]) {
        if let data = try? JSONEncoder().encode(folders) { defaults.set(data, forKey: key) }
    }
}

/// Keeps the list in memory, for tests. A second FolderAccess sharing the
/// same store behaves like the app after a restart.
public final class MemoryFolderStore: FolderStore {
    private var folders: [SavedFolder] = []
    public init() {}
    public func load() -> [SavedFolder] { folders }
    public func save(_ folders: [SavedFolder]) { self.folders = folders }
}

/// Remembers the folders the user chose and checks them before use (T09).
/// Read only towards the user's files: it makes and reads bookmarks, lists
/// folders, and never moves, renames or writes anything in them.
public final class FolderAccess {
    private let store: FolderStore
    private let securityScoped: Bool

    /// `securityScoped` is true in the sandboxed app. Tests run outside the
    /// sandbox and use plain bookmarks, which behave the same for renames.
    public init(store: FolderStore, securityScoped: Bool = true) {
        self.store = store
        self.securityScoped = securityScoped
    }

    public var folders: [SavedFolder] { store.load() }

    /// Remember a folder the user picked in the Open panel. Picking the same
    /// folder twice keeps one entry with a fresh bookmark.
    @discardableResult
    public func add(_ url: URL) throws -> SavedFolder {
        let folder = url.standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory),
              isDirectory.boolValue else { throw MojoError.folderUnavailable(folder) }
        let bookmark: Data
        do {
            bookmark = try folder.bookmarkData(options: createOptions, includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            throw MojoError.folderUnavailable(folder)
        }
        var list = store.load()
        let key = Self.comparable(folder.path)
        let saved: SavedFolder
        if let index = list.firstIndex(where: { Self.comparable($0.path) == key }) {
            list[index].bookmark = bookmark
            saved = list[index]
        } else {
            saved = SavedFolder(path: folder.path, bookmark: bookmark)
            list.append(saved)
        }
        store.save(list)
        return saved
    }

    /// Forget a folder. The folder itself is not touched.
    public func remove(id: UUID) {
        store.save(store.load().filter { $0.id != id })
    }

    /// Check a saved folder. Ready only if it resolves, is still where the
    /// user chose it, and can be listed. A stale bookmark at the same place
    /// is quietly refreshed.
    public func status(of folder: SavedFolder) -> FolderStatus {
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: folder.bookmark, options: resolveOptions,
                                 relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return .chooseAgain(.missing)
        }
        guard Self.comparable(url.path) == Self.comparable(folder.path) else {
            return .chooseAgain(.renamedOrMoved)
        }
        let opened = securityScoped ? url.startAccessingSecurityScopedResource() : true
        defer { if opened && securityScoped { url.stopAccessingSecurityScopedResource() } }
        guard FileManager.default.fileExists(atPath: url.path) else { return .chooseAgain(.missing) }
        guard opened, (try? FileManager.default.contentsOfDirectory(atPath: url.path)) != nil else {
            return .chooseAgain(.noAccess)
        }
        if stale, let fresh = try? url.bookmarkData(options: createOptions, includingResourceValuesForKeys: nil, relativeTo: nil) {
            var list = store.load()
            if let index = list.firstIndex(where: { $0.id == folder.id }) {
                list[index].bookmark = fresh
                store.save(list)
            }
        }
        return .ready(url)
    }

    /// Open a ready folder for the length of `body`, then close it again.
    public func withAccess<T>(to folder: SavedFolder, _ body: (URL) throws -> T) throws -> T {
        guard case .ready(let url) = status(of: folder) else {
            throw MojoError.folderUnavailable(URL(fileURLWithPath: folder.path))
        }
        let opened = securityScoped ? url.startAccessingSecurityScopedResource() : true
        defer { if opened && securityScoped { url.stopAccessingSecurityScopedResource() } }
        guard opened else { throw MojoError.folderUnavailable(url) }
        return try body(url)
    }

    // MARK: -

    private var createOptions: URL.BookmarkCreationOptions { securityScoped ? [.withSecurityScope] : [] }
    private var resolveOptions: URL.BookmarkResolutionOptions {
        securityScoped ? [.withSecurityScope, .withoutUI] : [.withoutUI]
    }

    /// Paths compared the way the Mac does: links like /var → /private/var
    /// resolved, capitals ignored (T01 Q6), no trailing slash.
    static func comparable(_ path: String) -> String {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL.path.lowercased()
    }
}
