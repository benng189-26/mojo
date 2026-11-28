import Foundation
import XCTest
@testable import MojoCore

/// T10: the Planner turns scanned facts into a Plan. It never changes a file.
final class PlannerTests: XCTestCase {
    var sample: URL!

    override func setUpWithError() throws {
        sample = try SampleFolder.make()
    }

    private func plan(_ folder: URL? = nil, synced: Bool = false, firstRun: Bool = false) throws -> Plan {
        let folder = folder ?? sample!
        return try Planner().plan(folder: folder, items: try FolderScanner().scan(folder: folder),
                                  isSynced: synced, isFirstRun: firstRun)
    }

    private func move(_ plan: Plan, _ name: String) -> PlannedMove? {
        plan.moves.first { $0.source.lastPathComponent == name }
    }

    private func reason(_ plan: Plan, _ name: String) -> StayReason? {
        plan.stays.first { $0.url.lastPathComponent == name }?.reason
    }

    func testPlanningChangesNothing() throws {
        let before = try listing(sample)
        _ = try plan()
        XCTAssertEqual(try listing(sample), before)
    }

    func testEachTypeGoesToItsFolder() throws {
        let plan = try plan()
        let expected: [String: String] = [
            "sample.pdf": "Documents", "sample.docx": "Documents", "sample.txt": "Documents",
            "Essay.pages": "Documents", "notes.md": "Documents", "Report.pdf": "Documents",
            "photo.jpg": "Images", "photo.heic": "Images", "clip.mp4": "Videos",
            "song.wav": "Audio", "installer.dmg": "Installers", "archive.zip": "ZIP files",
        ]
        for (name, folder) in expected {
            XCTAssertEqual(move(plan, name)?.targetFolderName, folder, name)
        }
    }

    func testWhatStaysHasAReason() throws {
        let plan = try plan()
        XCTAssertEqual(reason(plan, "script.swift"), .codeFile)
        XCTAssertEqual(reason(plan, "mystery.xyz"), .unknownType)
        XCTAssertEqual(reason(plan, "link-outside"), .aliasOrLink)
        XCTAssertEqual(reason(plan, "movie.mp4.crdownload"), .unfinishedDownload)
        XCTAssertEqual(reason(plan, "MyApp"), .existingFolder)
        XCTAssertEqual(reason(plan, "Documents"), .existingFolder)
        XCTAssertNil(move(plan, "locked.pdf"))
        // Every top-level item is either a move or a stay, never both or neither.
        let names = try listing(sample)
        XCTAssertEqual(plan.moves.count + plan.stays.count, names.count)
    }

    /// T10 decision 1: a file changed in the last 2 minutes may be in use.
    func testJustSavedFileStaysAsInUse() throws {
        let plan = try plan()
        XCTAssertNil(move(plan, "just-saved.docx"))
        XCTAssertEqual(reason(plan, "just-saved.docx"), .inUse)
    }

    func testBusyWindowUsesTheClock() throws {
        let items = try FolderScanner().scan(folder: sample)
        let later = Planner(now: { Date().addingTimeInterval(600) })
        let plan = try later.plan(folder: sample, items: items, isSynced: false, isFirstRun: false)
        XCTAssertEqual(move(plan, "just-saved.docx")?.targetFolderName, "Documents")
    }

    /// Design decision 5: an existing folder matching ignoring capitals is used.
    func testExistingFolderMatchedIgnoringCapitals() throws {
        let items = try FolderScanner().scan(folder: sample).map { facts -> FileFacts in
            var copy = facts
            if facts.name == "Images" { copy.name = "images" }
            return copy
        }
        let plan = try Planner().plan(folder: sample, items: items, isSynced: false, isFirstRun: false)
        XCTAssertEqual(move(plan, "photo.jpg")?.targetFolderName, "images")
        XCTAssertEqual(move(plan, "clip.mp4")?.targetFolderName, "Videos")
    }

    /// A link named like a target folder is not a folder Mojo adds to.
    func testLinkIsNotUsedAsTargetFolder() throws {
        let items = try FolderScanner().scan(folder: sample).map { facts -> FileFacts in
            var copy = facts
            if facts.name == "link-inside" { copy.name = "Videos" }
            return copy
        }
        let plan = try Planner().plan(folder: sample, items: items, isSynced: false, isFirstRun: false)
        XCTAssertEqual(move(plan, "clip.mp4")?.targetFolderName, "Videos")
        XCTAssertEqual(reason(plan, "Videos"), .aliasOrLink)
    }

    func testChosenProjectFolderPlansNoMoves() throws {
        let plan = try plan(sample.appendingPathComponent("ProjectRoot"))
        XCTAssertTrue(plan.moves.isEmpty)
        XCTAssertTrue(plan.stays.allSatisfy { $0.reason == .projectFolder })
        XCTAssertEqual(plan.stays.count, 2)
    }

    func testWarnings() throws {
        XCTAssertEqual(try plan().warnings, [])
        XCTAssertEqual(try plan(synced: true, firstRun: true).warnings, [.syncedFolder, .firstRunLinkedApps])
    }

    func testSamePlanTwiceExceptID() throws {
        var a = try plan()
        let b = try plan()
        a.id = b.id
        XCTAssertEqual(a.contentHash, b.contentHash)
    }
}
