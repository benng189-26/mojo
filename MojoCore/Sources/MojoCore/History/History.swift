import Foundation

/// Read-only view of the move log for the history screen. Built in T18.
public struct History: Sendable {
    public let logFolder: URL

    public init(logFolder: URL) {
        self.logFolder = logFolder
    }

    /// Every logged entry whose old or new name contains `text`, newest first.
    public func search(_ text: String) throws -> [LogEntry] {
        throw MojoError.notImplemented("History.search (T18)")
    }

    /// All entries of one run, in the order they happened.
    public func entries(runID: UUID) throws -> [LogEntry] {
        throw MojoError.notImplemented("History.entries (T18)")
    }
}
