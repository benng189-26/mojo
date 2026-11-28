import Foundation
import XCTest
@testable import MojoCore

/// T08: the scanner reads the top level of a sample folder, changes nothing,
/// never follows links, and can be cancelled.
final class ScannerTests: XCTestCase {
    private var sample: URL!

    override func setUpWithError() throws {
        sample = try SampleFolder.make()
    }

    /// Every top-level name, and nothing from inside subfolders.
    func testScanListsTopLevelOnlyIncludingHidden() throws {
        let names = try FolderScanner().scan(folder: sample).map(\.name).sorted()
        XCTAssertEqual(names, try listing(sample))
        XCTAssertTrue(names.contains(".secret"))
        XCTAssertFalse(names.contains("old-holiday.jpg"), "scanner looked inside Images/")
    }

    /// Scanning twice leaves every name, size and date exactly as it was.
    func testScanChangesNothing() throws {
        let before = try snapshot(sample)
        _ = try FolderScanner().scan(folder: sample)
        _ = try FolderScanner().scan(folder: sample)
        XCTAssertEqual(try snapshot(sample), before)
    }

    /// Links are described as links, never as what they point to.
    func testLinksAreNotFollowed() throws {
        let items = try FolderScanner().scan(folder: sample)
        for name in ["link-outside", "link-inside"] {
            let item = try XCTUnwrap(items.first { $0.name == name }, name)
            XCTAssertTrue(item.isSymbolicLink, name)
            XCTAssertNil(item.typeIdentifier, name)
            XCTAssertEqual(try Rules().classify(item), .stay(.aliasOrLink), name)
        }
    }

    /// Spec: traps stay in place. Each one gets the reason the manifest gives.
    func testTrapsStay() throws {
        let items = Dictionary(uniqueKeysWithValues: try FolderScanner().scan(folder: sample).map { ($0.name, $0) })
        let expected: [String: StayReason] = [
            "locked.pdf": .locked,
            "movie.mp4.crdownload": .unfinishedDownload,
            "setup.dmg.download": .unfinishedDownload,
            "data.zip.part": .unfinishedDownload,
            "script.swift": .codeFile,
            "tool.py": .codeFile,
            "mystery.xyz": .unknownType,
            ".secret": .hidden,
            "Documents": .existingFolder,
            "Images": .existingFolder,
            "MyApp": .existingFolder,
            "website": .existingFolder,
            "ProjectRoot": .existingFolder,
        ]
        for (name, reason) in expected {
            let item = try XCTUnwrap(items[name], name)
            XCTAssertEqual(try Rules().classify(item), .stay(reason), name)
        }
    }

    /// Real files from the sample sort the way the spec table says.
    func testSortableSampleFilesClassify() throws {
        let items = Dictionary(uniqueKeysWithValues: try FolderScanner().scan(folder: sample).map { ($0.name, $0) })
        let expected: [String: FileCategory] = [
            "sample.pdf": .documents, "Essay.pages": .documents, "notes.md": .documents,
            "Report.pdf": .documents, "tagged.pdf": .documents,
            "archive.zip": .zipFiles, "old-installer.pkg": .installers, "big-video.mov": .videos,
        ]
        for (name, category) in expected {
            let item = try XCTUnwrap(items[name], name)
            XCTAssertEqual(try Rules().classify(item), .sort(category), name)
        }
    }

    /// Existing Finder labels are read (T01 Q5).
    func testTagsAreRead() throws {
        let item = try XCTUnwrap(try FolderScanner().scan(folder: sample).first { $0.name == "tagged.pdf" })
        XCTAssertTrue(item.tags.contains("Red"), "tags read: \(item.tags)")
    }

    /// The fingerprint changes when the file changes, so FileEngine can skip it.
    func testFactsSeeChangesSinceScan() throws {
        let url = sample.appendingPathComponent("sample.pdf")
        let first = try FolderScanner().facts(for: url)
        XCTAssertNotEqual(first.fingerprint.fileID, 0)
        try SampleFolder.touch(url)
        let second = try FolderScanner().facts(for: url)
        XCTAssertEqual(first.fingerprint.fileID, second.fingerprint.fileID)
        XCTAssertNotEqual(first.fingerprint, second.fingerprint)
    }

    func testMissingFolderThrows() {
        let gone = sample.appendingPathComponent("no-such-folder")
        XCTAssertThrowsError(try FolderScanner().scan(folder: gone)) { error in
            XCTAssertEqual(error as? MojoError, .folderUnavailable(gone))
        }
    }

    /// Spec: Cancel works, even part way through a large folder.
    func testCancelStopsALargeScan() throws {
        let big = try SampleFolder.make(many: 2000)
        let all = try FolderScanner().scan(folder: big)
        XCTAssertGreaterThan(all.count, 2000)

        let counter = CallCounter(limit: 50)
        XCTAssertThrowsError(try FolderScanner().scan(folder: big, isCancelled: { counter.tick() })) { error in
            XCTAssertEqual(error as? MojoError, .cancelled)
        }
        XCTAssertLessThan(counter.count, 60, "scanner kept going after Cancel")
    }

    // MARK: Helpers

    /// Names, sizes and dates of everything in a folder, without following links.
    private func snapshot(_ folder: URL) throws -> [String] {
        var lines: [String] = []
        let fm = FileManager.default
        guard let walker = fm.enumerator(atPath: folder.path) else { return [] }
        while let relative = walker.nextObject() as? String {
            let attributes = try fm.attributesOfItem(atPath: folder.appendingPathComponent(relative).path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? -1
            let date = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? -1
            lines.append("\(relative) \(size) \(date)")
        }
        return lines.sorted()
    }
}

/// Returns true once it has been asked `limit` times.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private let limit: Int
    private(set) var count = 0
    init(limit: Int) { self.limit = limit }
    func tick() -> Bool {
        lock.lock(); defer { lock.unlock() }
        count += 1
        return count > limit
    }
}
