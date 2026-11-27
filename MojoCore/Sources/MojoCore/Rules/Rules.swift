import Foundation

/// Result of looking at one item: where it goes, or why it stays.
public enum Classification: Hashable, Sendable {
    case sort(FileCategory)
    case stay(StayReason)
}

/// Pure sorting rules (spec: Sorting rules, What always stays). Built in T07.
/// Never touches the disk: everything it needs is in FileFacts.
public struct Rules: Sendable {
    public init() {}

    /// Classify one top-level item of a chosen folder.
    public func classify(_ facts: FileFacts) throws -> Classification {
        throw MojoError.notImplemented("Rules.classify (T07)")
    }

    /// True when the chosen folder's own top level marks it as a project
    /// (.xcodeproj, .xcworkspace, Package.swift, .git, package.json).
    /// Then nothing in it moves.
    public func isProjectFolder(topLevelNames: [String]) throws -> Bool {
        throw MojoError.notImplemented("Rules.isProjectFolder (T07)")
    }
}
