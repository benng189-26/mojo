import CryptoKit
import Foundation

/// One move the user will approve.
public struct PlannedMove: Codable, Hashable, Sendable {
    public var source: URL
    public var fingerprint: Fingerprint
    public var category: FileCategory
    /// Folder name inside the chosen folder. An existing folder whose name
    /// matches ignoring capitals is used as is (design decision 5).
    public var targetFolderName: String

    public init(source: URL, fingerprint: Fingerprint, category: FileCategory, targetFolderName: String) {
        self.source = source
        self.fingerprint = fingerprint
        self.category = category
        self.targetFolderName = targetFolderName
    }
}

/// An item that stays, and why.
public struct Stay: Codable, Hashable, Sendable {
    public var url: URL
    public var reason: StayReason

    public init(url: URL, reason: StayReason) {
        self.url = url
        self.reason = reason
    }
}

public enum PlanWarning: String, Codable, Hashable, Sendable {
    /// The chosen folder syncs with iCloud: moves reach all devices.
    case syncedFolder
    /// First run: apps that link to files may report moved files missing.
    case firstRunLinkedApps
}

/// What Mojo proposes for one chosen folder. Building a Plan changes nothing.
public struct Plan: Codable, Hashable, Sendable {
    public var id: UUID
    public var folder: URL
    public var moves: [PlannedMove]
    public var stays: [Stay]
    public var warnings: [PlanWarning]

    public init(id: UUID = UUID(), folder: URL, moves: [PlannedMove], stays: [Stay], warnings: [PlanWarning]) {
        self.id = id
        self.folder = folder
        self.moves = moves
        self.stays = stays
        self.warnings = warnings
    }

    /// SHA-256 of the plan's contents. Any change after approval changes it.
    public var contentHash: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = (try? encoder.encode(self)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// Made by the app only when the user presses the wand for this exact plan.
/// FileEngine refuses to act if the plan's id or contents differ.
public struct Approval: Hashable, Sendable {
    public let planID: UUID
    public let planHash: String

    public init(approving plan: Plan) {
        planID = plan.id
        planHash = plan.contentHash
    }

    public func matches(_ plan: Plan) -> Bool {
        planID == plan.id && planHash == plan.contentHash
    }
}
