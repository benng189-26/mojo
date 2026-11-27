import Foundation
import XCTest
@testable import MojoCore

/// Safety tests from docs/spec.md "Test before release", plus the rules in
/// docs/design.md. Written in T03 before the code exists, so most fail with
/// `notImplemented` until T07 to T11 build the parts they use.
/// Never weaken or skip one of these to make it pass (AGENTS.md).
final class SafetyTests: XCTestCase {
    var sample: URL!
    var engine: FileEngine!

    override func setUpWithError() throws {
        sample = try SampleFolder.make()
        engine = FileEngine(logFolder: SampleFolder.logFolder(for: sample))
    }

    // MARK: What always stays

    /// Spec: Desktop holds a Swift project folder → the folder is unchanged.
    func testProjectFolderInsideIsUnchanged() throws {
        let before = try listing(sample, "MyApp")
        try tidy(sample, engine: engine)
        XCTAssertEqual(try listing(sample, "MyApp"), before)
        XCTAssertTrue(exists(sample, "MyApp/Package.swift"))
        XCTAssertTrue(exists(sample, "website/.git"))
    }

    /// Spec: the chosen folder contains .git / package.json → nothing in it moves.
    func testChosenProjectFolderMovesNothing() throws {
        let project = sample.appendingPathComponent("ProjectRoot")
        let before = try listing(project)
        let (plan, result) = try tidy(project, engine: engine)
        XCTAssertTrue(plan.moves.isEmpty)
        XCTAssertTrue(result.moved.isEmpty)
        XCTAssertEqual(try listing(project), before)
    }

    /// Spec: a loose .swift file stays. Also other code, unknown types,
    /// hidden files and links.
    func testCodeUnknownHiddenAndLinksStay() throws {
        try tidy(sample, engine: engine)
        for name in ["script.swift", "tool.py", "mystery.xyz", ".secret", "link-outside", "link-inside"] {
            XCTAssertTrue(exists(sample, name), "\(name) should stay")
        }
    }

    /// Spec: an unfinished download stays.
    func testUnfinishedDownloadsStay() throws {
        try tidy(sample, engine: engine)
        for name in ["movie.mp4.crdownload", "setup.dmg.download", "data.zip.part"] {
            XCTAssertTrue(exists(sample, name), "\(name) should stay")
        }
    }

    /// Spec: locked files are left, and the reason is given.
    func testLockedFileStaysWithReason() throws {
        let (plan, _) = try tidy(sample, engine: engine)
        XCTAssertTrue(exists(sample, "locked.pdf"))
        let lockedURL = sample.appendingPathComponent("locked.pdf").standardizedFileURL
        XCTAssertTrue(plan.stays.contains { $0.url.standardizedFileURL == lockedURL && $0.reason == .locked })
    }

    // MARK: Sorting

    /// Spec: a Pages document goes to Documents, as one file.
    func testPagesPackageGoesToDocumentsWhole() throws {
        try tidy(sample, engine: engine)
        XCTAssertTrue(exists(sample, "Documents/Essay.pages/Index.zip"))
        XCTAssertTrue(exists(sample, "Documents/Essay.pages/Data/preview.jpg"))
        XCTAssertFalse(exists(sample, "Essay.pages"))
    }

    /// Spec: a ZIP file moves to ZIP files and stays unopened.
    func testZipMovesUnopened() throws {
        try tidy(sample, engine: engine)
        XCTAssertEqual(try contents(sample, "ZIP files/archive.zip"), "PK fake zip")
        XCTAssertEqual(try listing(sample, "ZIP files"), ["archive.zip"])
    }

    /// Spec: an Images folder already exists → files are added, nothing
    /// inside is rearranged.
    func testExistingImagesFolderNotRearranged() throws {
        try tidy(sample, engine: engine)
        XCTAssertEqual(try contents(sample, "Images/old-holiday.jpg"), "old")
        XCTAssertTrue(exists(sample, "Images/nested/keep.png"))
        XCTAssertTrue(exists(sample, "Images/photo.jpg"))
    }

    // MARK: Never overwrite

    /// Spec: two files named the same meet → both kept, one gets a number.
    func testExactNameClashKeepsBoth() throws {
        try tidy(sample, engine: engine)
        XCTAssertEqual(try contents(sample, "Documents/invoice.pdf"), "old invoice")
        XCTAssertEqual(try contents(sample, "Documents/invoice 2.pdf"), "new invoice")
    }

    /// Spec: two names differ only in capital letters → both kept, one numbered.
    func testCaseOnlyClashKeepsBoth() throws {
        try tidy(sample, engine: engine)
        XCTAssertEqual(try contents(sample, "Documents/report.pdf"), "old report")
        XCTAssertEqual(try contents(sample, "Documents/Report 2.pdf"), "new report")
    }

    // MARK: Approval and changes after the plan

    /// Design: FileEngine refuses a plan that differs from what was approved.
    func testChangedPlanIsRefused() throws {
        let original = Plan(folder: sample, moves: [], stays: [], warnings: [])
        let approval = Approval(approving: original)
        var changed = original
        changed.warnings.append(.syncedFolder)
        XCTAssertThrowsError(try engine.apply(changed, approval: approval)) { error in
            XCTAssertEqual(error as? MojoError, .approvalMismatch)
        }
    }

    /// Design: unticking makes a new plan that needs a new approval.
    func testUntickingNeedsNewApproval() throws {
        let items = try FolderScanner().scan(folder: sample)
        let plan = try Planner().plan(folder: sample, items: items, isSynced: false, isFirstRun: false)
        let approval = Approval(approving: plan)
        let first = try XCTUnwrap(plan.moves.first)
        let unticked = Planner().unticking([first.source], from: plan)
        XCTAssertFalse(approval.matches(unticked))
    }

    /// Spec: a file changes after the plan is shown → it is skipped and listed.
    func testFileChangedAfterPlanIsSkipped() throws {
        let items = try FolderScanner().scan(folder: sample)
        let plan = try Planner().plan(folder: sample, items: items, isSynced: false, isFirstRun: false)
        let pdf = sample.appendingPathComponent("sample.pdf")
        try SampleFolder.touch(pdf)
        let result = try engine.apply(plan, approval: Approval(approving: plan))
        XCTAssertTrue(exists(sample, "sample.pdf"))
        XCTAssertTrue(result.skipped.contains { $0.url.lastPathComponent == "sample.pdf" && $0.reason == .changedSincePlan })
    }

    // MARK: Labels and undo

    /// Spec: a file already has a label → kept; undo restores the original state.
    func testExistingLabelKeptAndUndoRestores() throws {
        let before = try tags(sample, "tagged.pdf")
        let (_, result) = try tidy(sample, engine: engine)
        let after = try tags(sample, "Documents/tagged.pdf")
        for tag in before { XCTAssertTrue(after.contains(tag), "existing label \(tag) was lost") }
        XCTAssertGreaterThan(after.count, before.count, "Mojo's label was not added")
        _ = try engine.undo(runID: result.runID)
        XCTAssertTrue(exists(sample, "tagged.pdf"))
        XCTAssertEqual(try tags(sample, "tagged.pdf"), before)
    }

    /// Spec: user adds a file to a new folder, then undoes → folder and file stay.
    func testUndoKeepsFolderWithNewFile() throws {
        let (_, result) = try tidy(sample, engine: engine)
        try SampleFolder.addFile(named: "mine.mp3", in: sample.appendingPathComponent("Audio"))
        _ = try engine.undo(runID: result.runID)
        XCTAssertTrue(exists(sample, "Audio/mine.mp3"))
        XCTAssertTrue(exists(sample, "song.mp3"))
    }

    /// Spec/design: undo removes only folders Mojo made, and only if empty
    /// (a .DS_Store alone counts as empty).
    func testUndoRemovesOnlyEmptyFoldersMojoMade() throws {
        let (_, result) = try tidy(sample, engine: engine)
        _ = try engine.undo(runID: result.runID)
        XCTAssertFalse(exists(sample, "Videos"))
        XCTAssertTrue(exists(sample, "Documents"), "existing folder must stay")
        XCTAssertTrue(exists(sample, "Images"), "existing folder must stay")
        XCTAssertTrue(exists(sample, "clip.mp4"))
    }

    /// Spec: the app quits halfway through → undo still restores moved files.
    func testUndoAfterQuitHalfway() throws {
        engine.crashAfterMoves = 3
        let items = try FolderScanner().scan(folder: sample)
        let plan = try Planner().plan(folder: sample, items: items, isSynced: false, isFirstRun: false)
        _ = try? engine.apply(plan, approval: Approval(approving: plan))

        let restarted = FileEngine(logFolder: SampleFolder.logFolder(for: sample))
        let interrupted = try restarted.interruptedRuns()
        XCTAssertEqual(interrupted.count, 1)
        _ = try restarted.undo(runID: try XCTUnwrap(interrupted.first))
        for move in plan.moves {
            XCTAssertTrue(FileManager.default.fileExists(atPath: move.source.path), "\(move.source.lastPathComponent) not restored")
        }
    }

    /// Spec: user searches the history for a moved file → it shows the new place.
    func testHistoryFindsMovedFile() throws {
        try tidy(sample, engine: engine)
        let hits = try History(logFolder: SampleFolder.logFolder(for: sample)).search("song.wav")
        XCTAssertTrue(hits.contains { $0.kind == .moved && $0.to?.path.hasSuffix("Audio/song.wav") == true })
    }
}
