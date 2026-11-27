import Foundation

/// Reads the top level of a chosen folder. Read only: never follows links,
/// never downloads an online-only file, can be cancelled. Built in T08.
public struct FolderScanner: Sendable {
    public init() {}

    /// Facts for every top-level item, including hidden ones (Rules decides
    /// what stays). Throws `MojoError.cancelled` if `isCancelled` turns true.
    public func scan(folder: URL, isCancelled: @Sendable () -> Bool = { false }) throws -> [FileFacts] {
        throw MojoError.notImplemented("FolderScanner.scan (T08)")
    }

    /// Fresh facts for one item, used by FileEngine just before a move.
    public func facts(for url: URL) throws -> FileFacts {
        throw MojoError.notImplemented("FolderScanner.facts (T08)")
    }
}
