import Foundation

/// Builds a Plan from scanned facts. Pure: reads nothing from disk and
/// changes nothing. Built in T10.
public struct Planner: Sendable {
    public var rules: Rules
    /// A file changed this recently may still be in use (being saved,
    /// edited or copied), so it stays (T10 decision 1, approved by Ben).
    public var busyWindow: TimeInterval
    /// The time "now" for the busy check. Tests may fix it.
    public var now: @Sendable () -> Date

    public init(rules: Rules = Rules(), busyWindow: TimeInterval = FileEngine.defaultBusyWindow,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.rules = rules
        self.busyWindow = busyWindow
        self.now = now
    }

    /// - Parameters:
    ///   - folder: the chosen folder.
    ///   - items: its top-level items from the Scanner.
    ///   - isSynced: true when the folder is in iCloud or another synced service.
    ///   - isFirstRun: true on the first tidy, to warn about apps that link to files.
    public func plan(folder: URL, items: [FileFacts], isSynced: Bool, isFirstRun: Bool) throws -> Plan {
        var warnings: [PlanWarning] = []
        if isSynced { warnings.append(.syncedFolder) }
        if isFirstRun { warnings.append(.firstRunLinkedApps) }

        // A chosen folder that is itself a project: nothing in it moves.
        if try rules.isProjectFolder(topLevelNames: items.map(\.name)) {
            return Plan(folder: folder, moves: [],
                        stays: items.map { Stay(url: $0.url, reason: .projectFolder) },
                        warnings: warnings)
        }

        let time = now()
        var moves: [PlannedMove] = []
        var stays: [Stay] = []
        for item in items {
            switch try rules.classify(item) {
            case .stay(let reason):
                stays.append(Stay(url: item.url, reason: reason))
            case .sort(let category):
                if Self.isBusy(item.fingerprint, now: time, window: busyWindow) {
                    stays.append(Stay(url: item.url, reason: .inUse))
                    continue
                }
                moves.append(PlannedMove(
                    source: item.url, fingerprint: item.fingerprint, category: category,
                    targetFolderName: Self.targetFolderName(for: category, in: items)))
            }
        }
        return Plan(folder: folder, moves: moves, stays: stays, warnings: warnings)
    }

    /// Remove moves the user unticked. Returns a new plan with a new hash,
    /// so it needs a fresh Approval.
    public func unticking(_ sources: Set<URL>, from plan: Plan) -> Plan {
        var copy = plan
        copy.moves.removeAll { sources.contains($0.source) }
        return copy
    }

    /// An existing folder whose name matches ignoring capitals is used as is
    /// (design decision 5). Otherwise Mojo's own name for the category.
    static func targetFolderName(for category: FileCategory, in items: [FileFacts]) -> String {
        let wanted = category.folderName.lowercased()
        if let existing = items.first(where: {
            $0.isDirectory && !$0.isPackage && !$0.isSymbolicLink && !$0.isAlias
                && $0.name.lowercased() == wanted
        }) {
            return existing.name
        }
        return category.folderName
    }

    static func isBusy(_ fingerprint: Fingerprint, now: Date, window: TimeInterval) -> Bool {
        // A date in the future also counts: the clock or the file is odd.
        now.timeIntervalSince(fingerprint.modified) < window
    }
}
