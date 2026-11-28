import Darwin
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
    /// A file changed less than this long ago may still be in use, so it
    /// stays (T10 decision 1, approved by Ben 2026-11-28).
    public static let defaultBusyWindow: TimeInterval = 120

    /// Where the move log lives. Tests pass a folder next to their sample.
    public let logFolder: URL
    public var busyWindow: TimeInterval = FileEngine.defaultBusyWindow

    /// Test hook: after this many moves, stop right after logging "about to
    /// move" for the next file, as if the app had crashed between design
    /// steps 3 and 5. Only used by tests; nil in the app.
    var crashAfterMoves: Int?

    private let rules = Rules()
    private let scanner = FolderScanner()

    public init(logFolder: URL) {
        self.logFolder = logFolder
    }

    struct SimulatedCrash: Error {}

    // MARK: - Tidy

    /// Carry out an approved tidy, one file at a time (docs/design.md, How a
    /// move works). Files that changed, are busy or are no longer safe to
    /// move are skipped and listed. Nothing is ever overwritten.
    public func apply(_ plan: Plan, approval: Approval) throws -> RunResult {
        guard approval.matches(plan) else { throw MojoError.approvalMismatch }

        // Check the whole plan before touching anything.
        let folder = plan.folder.standardizedFileURL
        guard Self.isRealFolder(folder) else { throw MojoError.folderUnavailable(folder) }
        let folderReal = folder.resolvingSymlinksInPath().path
        for move in plan.moves {
            let name = move.source.lastPathComponent
            let parent = move.source.standardizedFileURL.deletingLastPathComponent()
            guard parent.resolvingSymlinksInPath().path == folderReal, Self.isPlainName(name) else {
                throw MojoError.invalidPlan("\(name) is not directly inside \(folder.lastPathComponent)")
            }
            guard Self.isPlainName(move.targetFolderName) else {
                throw MojoError.invalidPlan("\(move.targetFolderName) is not a folder name")
            }
        }

        let runID = UUID()
        var result = RunResult(runID: runID)

        // Second line of defence: if the chosen folder is now a project,
        // nothing moves, even though the plan said otherwise.
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        if try rules.isProjectFolder(topLevelNames: names) {
            result.skipped = plan.moves.map { Stay(url: $0.source, reason: .projectFolder) }
            return result
        }
        if plan.moves.isEmpty { return result }

        let log = try MoveLog(folder: logFolder, runID: runID)
        try log.write(LogEntry(runID: runID, kind: .runStarted, from: folder))

        var movesDone = 0
        for move in plan.moves {
            let source = folder.appendingPathComponent(move.source.lastPathComponent)
            switch try moveOne(move, source: source, folder: folder, log: log, runID: runID, movesDone: movesDone) {
            case .moved(let item, let createdFolder):
                result.moved.append(item)
                if let createdFolder { result.foldersCreated.append(createdFolder) }
                movesDone += 1
            case .skipped(let reason):
                result.skipped.append(Stay(url: source, reason: reason))
            case .failed(let message):
                result.failed.append(FailedItem(url: source, message: message))
            }
        }

        try log.write(LogEntry(runID: runID, kind: .runFinished, from: folder))
        return result
    }

    private enum Outcome {
        case moved(MovedItem, createdFolder: URL?)
        case skipped(StayReason)
        case failed(String)
    }

    private func moveOne(_ move: PlannedMove, source: URL, folder: URL, log: MoveLog,
                         runID: UUID, movesDone: Int) throws -> Outcome {
        // 1. Read the file again, just before moving it.
        guard let facts = try? scanner.facts(for: source) else { return .skipped(.missing) }
        guard facts.fingerprint == move.fingerprint else { return .skipped(.changedSincePlan) }
        switch try rules.classify(facts) {
        case .stay(let reason): return .skipped(reason)
        case .sort(let category) where category != move.category: return .skipped(.changedSincePlan)
        case .sort: break
        }
        if Planner.isBusy(facts.fingerprint, now: Date(), window: busyWindow) { return .skipped(.inUse) }

        // 2. The target folder must be a real folder, never a link or a file.
        let target = folder.appendingPathComponent(move.targetFolderName, isDirectory: true)
        let needsFolder: Bool
        switch Self.kind(of: target) {
        case .missing: needsFolder = true
        case .folder: needsFolder = false
        case .other:
            return .failed("Something named \(move.targetFolderName) is in the way and is not a plain folder, so this file stayed.")
        }

        var number = 1
        var createdFolder: URL?
        while number < 10_000 {
            let taken = needsFolder && createdFolder == nil ? [] : Self.lowercasedNames(in: target)
            // Pick the first free name, ignoring capitals (T01 Q6).
            var name = Self.numbered(source.lastPathComponent, number)
            while taken.contains(name.lowercased()) {
                number += 1
                name = Self.numbered(source.lastPathComponent, number)
            }
            let destination = target.appendingPathComponent(name)

            // 3. Log first, and flush, so a crash leaves a record.
            try log.write(LogEntry(runID: runID, kind: .aboutToMove, from: source, to: destination,
                                   fileID: facts.fingerprint.fileID))
            if let limit = crashAfterMoves, movesDone >= limit { throw SimulatedCrash() }

            // 4. Make the target folder if needed, and log it as Mojo's.
            if needsFolder && createdFolder == nil {
                if mkdir(target.path, 0o755) == 0 {
                    createdFolder = target
                    try log.write(LogEntry(runID: runID, kind: .folderCreated, to: target))
                } else if errno != EEXIST || Self.kind(of: target) != .folder {
                    return .failed("Mojo could not make the \(move.targetFolderName) folder: \(Self.errorText()).")
                }
            }

            // 5. Exclusive rename: fails rather than replace anything.
            if renamex_np(source.path, destination.path, UInt32(RENAME_EXCL)) != 0 {
                let code = errno
                if code == EEXIST { number += 1; continue }   // a file appeared; try the next number
                if code == EXDEV { return .failed("The folder is on another disk, so Mojo left this file.") }
                return .failed("Mojo could not move this file: \(Self.errorText(code)).")
            }

            // 6. Add Mojo's label beside the existing ones.
            let added = Self.addLabel(move.category.label, to: destination)
            if !added.isEmpty {
                try log.write(LogEntry(runID: runID, kind: .labelAdded, to: destination,
                                       fileID: facts.fingerprint.fileID, labels: added))
            }

            // 7. Done.
            try log.write(LogEntry(runID: runID, kind: .moved, from: source, to: destination,
                                   fileID: facts.fingerprint.fileID, labels: added))
            return .moved(MovedItem(from: source, to: destination, labelsAdded: added),
                          createdFolder: createdFolder)
        }
        return .failed("Mojo could not find a free name for this file.")
    }

    // MARK: - Later cards

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

    // MARK: - Interrupted runs

    /// Runs that were interrupted (quit, crash, unplugged drive), found from
    /// the log on launch: they have a start line but no finish line.
    /// Oldest first. A missing log folder means no runs yet.
    public func interruptedRuns() throws -> [UUID] {
        try MoveLog.allRuns(in: logFolder)
            .filter { entries in
                entries.contains { $0.kind == .runStarted } && !entries.contains { $0.kind == .runFinished }
            }
            .compactMap { $0.first }
            .sorted { $0.date < $1.date }
            .map(\.runID)
    }

    /// For an interrupted run: the file that was being moved when it stopped
    /// ("about to move" with no "moved" after it), with where it really is
    /// now, found by its file ID. Never moves it (T10 decision 3).
    public func inProgressItem(runID: UUID) throws -> (entry: LogEntry, foundAt: URL?)? {
        let entries = try MoveLog.read(runID: runID, in: logFolder)
        guard let last = entries.last(where: { $0.kind == .aboutToMove }) else { return nil }
        let finished = entries.contains { $0.kind == .moved && $0.from == last.from }
        if finished { return nil }
        let candidates = [last.to, last.from].compactMap { $0 }
        let found = candidates.first { url in
            guard let facts = try? scanner.facts(for: url) else { return false }
            return facts.fingerprint.fileID == last.fileID
        }
        return (last, found)
    }

    // MARK: - Helpers

    enum ItemKind { case missing, folder, other }

    /// What is at a path, without following a link there.
    static func kind(of url: URL) -> ItemKind {
        var info = stat()
        guard lstat(url.path, &info) == 0 else { return errno == ENOENT ? .missing : .other }
        guard (info.st_mode & S_IFMT) == S_IFDIR else { return .other }
        // A folder Finder shows as one file (a package) is not a target.
        let values = try? url.resourceValues(forKeys: [.isPackageKey])
        return values?.isPackage == true ? .other : .folder
    }

    static func isRealFolder(_ url: URL) -> Bool { kind(of: url) == .folder }

    /// One path component, nothing that climbs out of a folder.
    static func isPlainName(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\0")
    }

    static func lowercasedNames(in folder: URL) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return Set(names.map { $0.lowercased() })
    }

    /// Finder style: "report.pdf", "report 2.pdf", "Essay 2.pages", "notes 3".
    static func numbered(_ name: String, _ number: Int) -> String {
        guard number > 1 else { return name }
        let ext = Rules.fileExtension(of: name)
        if ext.isEmpty { return "\(name) \(number)" }
        let base = String(name.dropLast(ext.count + 1))
        let originalExt = String(name.suffix(ext.count))
        return "\(base) \(number).\(originalExt)"
    }

    static let tagAttribute = "com.apple.metadata:_kMDItemUserTags"

    /// Finder tags exactly as stored on disk ("Red\n6"), without following a link.
    static func rawTags(of url: URL) -> [String] {
        let size = getxattr(url.path, tagAttribute, nil, 0, 0, XATTR_NOFOLLOW)
        guard size > 0 else { return [] }
        var data = Data(count: size)
        let read = data.withUnsafeMutableBytes { getxattr(url.path, tagAttribute, $0.baseAddress, size, 0, XATTR_NOFOLLOW) }
        guard read == size else { return [] }
        return (try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String]) ?? []
    }

    /// Adds Mojo's colour tag after the existing tags, which are kept exactly.
    /// Returns what was added: nothing if that colour is already there or the
    /// tag could not be written (the file has still moved, so not a failure).
    static func addLabel(_ color: LabelColor, to url: URL) -> [String] {
        let existing = rawTags(of: url)
        let alreadyThere = existing.contains { entry in
            let parts = entry.split(separator: "\n", omittingEmptySubsequences: false)
            return parts.first.map(String.init) == color.finderName
                || (parts.count > 1 && Int(parts[1]) == color.rawValue)
        }
        if alreadyThere { return [] }
        let entry = color.tagEntry
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: existing + [entry], format: .binary, options: 0) else { return [] }
        let status = data.withUnsafeBytes {
            setxattr(url.path, tagAttribute, $0.baseAddress, $0.count, 0, XATTR_NOFOLLOW)
        }
        return status == 0 ? [entry] : []
    }

    static func errorText(_ code: Int32 = errno) -> String {
        String(cString: strerror(code))
    }
}
