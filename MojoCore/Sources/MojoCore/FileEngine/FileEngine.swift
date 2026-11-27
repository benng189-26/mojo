import Foundation

/// The ONLY part of Mojo allowed to move, rename, label, trash or remove files,
/// or create or remove folders (AGENTS.md). scripts/safety-check.sh exempts
/// this folder and nothing else. Built in T10 (moves), T11 (undo), T16 (trash).
///
/// Rules every method follows (docs/design.md):
/// - acts only with a matching Approval;
/// - re-checks each file's fingerprint just before acting;
/// - writes and flushes a log entry before each step;
/// - moves with an exclusive rename, so nothing is ever overwritten;
/// - never deletes, except `.DS_Store` in a folder Mojo made, during Undo;
/// - never empties the Trash.
public final class FileEngine {
    /// Where the move log lives. Tests pass a folder inside their sample.
    public let logFolder: URL

    /// Test hook: stop after this many moves, as if the app had crashed.
    /// Only used by tests; nil in the app.
    var crashAfterMoves: Int?

    public init(logFolder: URL) {
        self.logFolder = logFolder
    }

    /// Carry out an approved tidy.
    public func apply(_ plan: Plan, approval: Approval) throws -> RunResult {
        guard approval.matches(plan) else { throw MojoError.approvalMismatch }
        throw MojoError.notImplemented("FileEngine.apply (T10)")
    }

    /// Undo one run: files go back with their old labels, Mojo's empty
    /// folders are removed, anything changed since is reported, not guessed.
    public func undo(runID: UUID) throws -> RunResult {
        throw MojoError.notImplemented("FileEngine.undo (T11)")
    }

    /// Clean up: send ticked files to the Trash and log where each went.
    public func trash(_ items: [FileFacts], approval: Approval, plan: Plan) throws -> RunResult {
        guard approval.matches(plan) else { throw MojoError.approvalMismatch }
        throw MojoError.notImplemented("FileEngine.trash (T16)")
    }

    /// Put one logged item back where it came from (History's Put back).
    public func putBack(entryID: UUID) throws -> RunResult {
        throw MojoError.notImplemented("FileEngine.putBack (T11)")
    }

    /// Runs that were interrupted (quit, crash, unplugged drive), found from
    /// the log on launch.
    public func interruptedRuns() throws -> [UUID] {
        throw MojoError.notImplemented("FileEngine.interruptedRuns (T10)")
    }
}
