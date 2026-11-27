import Foundation
import XCTest
@testable import MojoCore

/// Test helpers. Every test works on a fresh folder made by
/// scripts/make-sample-folder.sh inside the system temporary folder, never a
/// real user folder (AGENTS.md). Helpers here are the only test code allowed
/// to create or change files, and each such line carries a safety-check tag.
enum SampleFolder {
    /// Repo root, found from this file's path: MojoCore/Tests/MojoCoreTests/.
    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // MojoCoreTests
            .deletingLastPathComponent()   // Tests
            .deletingLastPathComponent()   // MojoCore
            .deletingLastPathComponent()   // repo
    }

    /// Makes a new sample folder and returns its URL.
    static func make(file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent("MojoTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true) // safety-check: allow test sample parent in temp folder

        let script = repoRoot.appendingPathComponent("scripts/make-sample-folder.sh")
        let process = Process() // safety-check: allow runs the sample folder script
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path, parent.path, "--large-mb", "1"]
        let output = Pipe()
        process.standardOutput = output
        process.standardError = output
        try process.run()
        process.waitUntilExit()
        let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        guard process.terminationStatus == 0 else {
            XCTFail("sample folder script failed: \(text)", file: file, line: line)
            throw MojoError.folderUnavailable(parent)
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: parent.path)
        guard let name = names.first(where: { $0.hasPrefix("MojoSample-") && !$0.hasSuffix(".txt") }) else {
            throw MojoError.folderUnavailable(parent)
        }
        return parent.appendingPathComponent(name, isDirectory: true)
    }

    /// A folder for the move log, next to the sample (not inside it).
    static func logFolder(for sample: URL) -> URL {
        sample.deletingLastPathComponent().appendingPathComponent("log", isDirectory: true)
    }

    /// Simulates the user editing a file after the plan was shown.
    static func touch(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url) // safety-check: allow test edits a sample file
        try handle.seekToEnd()
        handle.write(Data(" edited".utf8))
        try handle.close()
    }

    /// Simulates the user dropping a new file into a folder.
    static func addFile(named name: String, in folder: URL) throws {
        let url = folder.appendingPathComponent(name)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        try Data("new".utf8).write(to: url, options: .withoutOverwriting) // safety-check: allow test adds a sample file
    }
}

// MARK: - Small read-only helpers

func exists(_ folder: URL, _ relative: String) -> Bool {
    FileManager.default.fileExists(atPath: folder.appendingPathComponent(relative).path)
}

func contents(_ folder: URL, _ relative: String) throws -> String {
    String(decoding: try Data(contentsOf: folder.appendingPathComponent(relative)), as: UTF8.self)
}

func tags(_ folder: URL, _ relative: String) throws -> [String] {
    let url = folder.appendingPathComponent(relative)
    return try url.resourceValues(forKeys: [.tagNamesKey]).tagNames ?? []
}

/// Names of everything inside a folder, sorted.
func listing(_ folder: URL, _ relative: String = "") throws -> [String] {
    let url = relative.isEmpty ? folder : folder.appendingPathComponent(relative)
    return try FileManager.default.contentsOfDirectory(atPath: url.path).sorted()
}

/// Scan, plan, approve and tidy one folder, as the app will.
@discardableResult
func tidy(_ folder: URL, engine: FileEngine, isFirstRun: Bool = false) throws -> (Plan, RunResult) {
    let items = try FolderScanner().scan(folder: folder)
    let plan = try Planner().plan(folder: folder, items: items, isSynced: false, isFirstRun: isFirstRun)
    let result = try engine.apply(plan, approval: Approval(approving: plan))
    return (plan, result)
}
