import Foundation

public struct MovedItem: Codable, Hashable, Sendable {
    public var from: URL
    public var to: URL
    /// Labels Mojo added, so Undo removes only these.
    public var labelsAdded: [String]

    public init(from: URL, to: URL, labelsAdded: [String]) {
        self.from = from
        self.to = to
        self.labelsAdded = labelsAdded
    }
}

public struct FailedItem: Codable, Hashable, Sendable {
    public var url: URL
    public var message: String

    public init(url: URL, message: String) {
        self.url = url
        self.message = message
    }
}

/// What actually happened in a tidy, undo or clean-up. Counts on screen come
/// from here, never from the animation.
public struct RunResult: Codable, Hashable, Sendable {
    public var runID: UUID
    public var moved: [MovedItem]
    public var skipped: [Stay]
    public var failed: [FailedItem]
    /// Folders Mojo made in this run.
    public var foldersCreated: [URL]

    public init(runID: UUID, moved: [MovedItem] = [], skipped: [Stay] = [],
                failed: [FailedItem] = [], foldersCreated: [URL] = []) {
        self.runID = runID
        self.moved = moved
        self.skipped = skipped
        self.failed = failed
        self.foldersCreated = foldersCreated
    }
}

/// One line of the move log, written and flushed before each step.
public struct LogEntry: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case aboutToMove, moved, folderCreated, labelAdded, trashed, undone, folderRemoved, putBack
    }

    public var id: UUID
    public var runID: UUID
    public var date: Date
    public var kind: Kind
    public var from: URL?
    public var to: URL?
    public var fileID: UInt64?
    public var labels: [String]

    public init(id: UUID = UUID(), runID: UUID, date: Date = Date(), kind: Kind,
                from: URL? = nil, to: URL? = nil, fileID: UInt64? = nil, labels: [String] = []) {
        self.id = id
        self.runID = runID
        self.date = date
        self.kind = kind
        self.from = from
        self.to = to
        self.fileID = fileID
        self.labels = labels
    }
}
