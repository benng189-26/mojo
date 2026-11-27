import Foundation

/// File ID + size + modified date, taken at scan time. FileEngine compares it
/// again just before moving and skips the file if anything differs.
public struct Fingerprint: Codable, Hashable, Sendable {
    public var fileID: UInt64
    public var size: Int64
    public var modified: Date

    public init(fileID: UInt64, size: Int64, modified: Date) {
        self.fileID = fileID
        self.size = size
        self.modified = modified
    }
}

/// iCloud state of an item, read without downloading it (T01 Q1, Q2).
public enum CloudState: String, Codable, Sendable {
    case notInCloud
    case downloaded
    case onlineOnly
    case notYetUploaded
}

/// Everything Rules and Planner need to know about one top-level item.
/// The Scanner fills this in; nothing here can change a file.
public struct FileFacts: Codable, Hashable, Sendable {
    public var url: URL
    public var name: String
    public var fingerprint: Fingerprint
    /// Uniform type identifier, e.g. "com.adobe.pdf". `dyn.*` means unknown.
    public var typeIdentifier: String?
    public var isDirectory: Bool
    public var isPackage: Bool
    public var isSymbolicLink: Bool
    public var isAlias: Bool
    public var isHidden: Bool
    public var isLocked: Bool
    public var isWritable: Bool
    public var tags: [String]
    public var cloud: CloudState

    public init(url: URL, name: String, fingerprint: Fingerprint, typeIdentifier: String?,
                isDirectory: Bool, isPackage: Bool, isSymbolicLink: Bool, isAlias: Bool,
                isHidden: Bool, isLocked: Bool, isWritable: Bool, tags: [String],
                cloud: CloudState) {
        self.url = url
        self.name = name
        self.fingerprint = fingerprint
        self.typeIdentifier = typeIdentifier
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isSymbolicLink = isSymbolicLink
        self.isAlias = isAlias
        self.isHidden = isHidden
        self.isLocked = isLocked
        self.isWritable = isWritable
        self.tags = tags
        self.cloud = cloud
    }
}
