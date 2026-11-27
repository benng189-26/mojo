import Foundation

/// Finder label colours, by Finder's own label number. Stored by number
/// because the colour names Finder shows depend on the Mac's language.
public enum LabelColor: Int, Codable, CaseIterable, Sendable {
    case gray = 1, green = 2, purple = 3, blue = 4, yellow = 5, red = 6, orange = 7
}

/// The folders Mojo sorts into (spec: Sorting rules).
public enum FileCategory: String, Codable, CaseIterable, Sendable {
    case documents, images, videos, audio, installers, zipFiles

    /// Name of the folder Mojo makes or adds to.
    public var folderName: String {
        switch self {
        case .documents: return "Documents"
        case .images: return "Images"
        case .videos: return "Videos"
        case .audio: return "Audio"
        case .installers: return "Installers"
        case .zipFiles: return "ZIP files"
        }
    }

    /// Label Mojo adds beside any existing labels.
    public var label: LabelColor {
        switch self {
        case .documents: return .blue
        case .images: return .green
        case .videos: return .orange
        case .audio: return .purple
        case .installers: return .gray
        case .zipFiles: return .yellow
        }
    }
}

/// Why an item stays where it is. Each case maps to a line of plain text the
/// app shows the user (spec: "When unsure, leave the file where it is and say why").
public enum StayReason: String, Codable, CaseIterable, Sendable {
    case hidden
    case systemOrApp
    case existingFolder
    case projectFolder          // chosen folder holds .git, Package.swift, etc.
    case library
    case codeFile
    case unfinishedDownload
    case unknownType
    case aliasOrLink
    case locked
    case readOnly
    case onlineOnly             // iCloud or other cloud: not downloaded
    case notYetUploaded         // iCloud: still uploading (T01 finding)
    case inUse
    case changedSincePlan
    case missing
}
