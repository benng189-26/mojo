import Foundation

/// Builds a Plan from scanned facts. Pure: changes nothing. Built in T07/T10.
public struct Planner: Sendable {
    public var rules: Rules

    public init(rules: Rules = Rules()) {
        self.rules = rules
    }

    /// - Parameters:
    ///   - folder: the chosen folder.
    ///   - items: its top-level items from the Scanner.
    ///   - isSynced: true when the folder is in iCloud or another synced service.
    ///   - isFirstRun: true on the first tidy, to warn about apps that link to files.
    public func plan(folder: URL, items: [FileFacts], isSynced: Bool, isFirstRun: Bool) throws -> Plan {
        throw MojoError.notImplemented("Planner.plan (T07)")
    }

    /// Remove moves the user unticked. Returns a new plan with a new hash,
    /// so it needs a fresh Approval.
    public func unticking(_ sources: Set<URL>, from plan: Plan) -> Plan {
        var copy = plan
        copy.moves.removeAll { sources.contains($0.source) }
        return copy
    }
}
