import Foundation

/// Errors MojoCore can report. Every reason is something the app can show the user.
public enum MojoError: Error, Equatable, Sendable {
    /// Placeholder thrown by stubs until a later card builds the real code.
    case notImplemented(String)
    /// FileEngine was handed a Plan that does not match the user's Approval.
    case approvalMismatch
    /// The scan was cancelled by the user.
    case cancelled
    /// The folder is no longer reachable (renamed, unplugged or access lost).
    case folderUnavailable(URL)
}
