import Darwin
import Foundation

/// The move log: one file per run, one JSON line per entry. Each line is
/// written and flushed to disk before FileEngine takes the step it
/// describes, so Undo works after a quit, crash or unplugged drive
/// (spec: Save the move log before moving). Lives in FileEngine because
/// it writes files; History and the app only read it.
final class MoveLog {
    let url: URL
    private let descriptor: Int32

    static func fileName(runID: UUID) -> String { "run-\(runID.uuidString).jsonl" }

    init(folder: URL, runID: UUID) throws {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            throw MojoError.logWriteFailed("Mojo could not make its log folder.")
        }
        url = folder.appendingPathComponent(Self.fileName(runID: runID))
        // O_EXCL: a run's log is new; never append to or replace another file.
        descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_APPEND, 0o600)
        guard descriptor >= 0 else {
            throw MojoError.logWriteFailed("Mojo could not start its move log: \(String(cString: strerror(errno))).")
        }
    }

    deinit { close(descriptor) }

    /// Append one entry and flush it to disk. If this fails, FileEngine stops.
    func write(_ entry: LogEntry) throws {
        var data = try Self.encoder.encode(entry)
        data.append(0x0A)
        let written = data.withUnsafeBytes { Darwin.write(descriptor, $0.baseAddress, $0.count) }
        guard written == data.count, fsync(descriptor) == 0 else {
            throw MojoError.logWriteFailed("Mojo could not save its move log, so it stopped.")
        }
    }

    // MARK: Reading (read only)

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]   // one line, stable order
        return encoder
    }()

    /// Entries of one run in the order they were written. A half-written last
    /// line (the app stopped mid-write) is ignored.
    static func read(runID: UUID, in folder: URL) throws -> [LogEntry] {
        try read(file: folder.appendingPathComponent(fileName(runID: runID)))
    }

    static func read(file: URL) throws -> [LogEntry] {
        let data = try Data(contentsOf: file)
        let decoder = JSONDecoder()
        return data.split(separator: 0x0A).compactMap { try? decoder.decode(LogEntry.self, from: Data($0)) }
    }

    /// Every run in the folder, each as its entries. No folder means no runs.
    static func allRuns(in folder: URL) throws -> [[LogEntry]] {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        return try names
            .filter { $0.hasPrefix("run-") && $0.hasSuffix(".jsonl") }
            .map { try read(file: folder.appendingPathComponent($0)) }
            .filter { !$0.isEmpty }
    }
}
