import Foundation
import XCTest
@testable import MojoCore

/// T10: FileEngine moves, labels, name clashes, changed and busy files, and
/// the move log. Every test uses a fresh sample folder, never a real one.
final class FileEngineTests: XCTestCase {
    var sample: URL!
    var logFolder: URL!
    var engine: FileEngine!

    override func setUpWithError() throws {
        sample = try SampleFolder.make()
        logFolder = SampleFolder.logFolder(for: sample)
        engine = FileEngine(logFolder: logFolder)
    }

    private func makePlan(_ folder: URL? = nil) throws -> Plan {
        let folder = folder ?? sample!
        return try Planner().plan(folder: folder, items: try FolderScanner().scan(folder: folder),
                                  isSynced: false, isFirstRun: false)
    }

    // MARK: Moves

    func testTidyMovesEachFileToItsFolder() throws {
        let (plan, result) = try tidy(sample, engine: engine)
        XCTAssertEqual(result.moved.count, plan.moves.count)
        XCTAssertTrue(result.failed.isEmpty, "\(result.failed)")
        for name in ["Documents/sample.pdf", "Documents/Essay.pages", "Images/photo.png",
                     "Videos/clip.mov", "Audio/song.m4a", "Installers/installer.pkg", "ZIP files/archive.zip"] {
            XCTAssertTrue(exists(sample, name), name)
        }
        XCTAssertEqual(try contents(sample, "Documents/sample.pdf"), "sample pdf", "contents changed")
        for move in plan.moves {
            XCTAssertFalse(FileManager.default.fileExists(atPath: move.source.path), "\(move.source.lastPathComponent) still loose")
        }
    }

    func testOnlyNewFoldersAreReportedAsMade() throws {
        let (_, result) = try tidy(sample, engine: engine)
        let made = Set(result.foldersCreated.map(\.lastPathComponent))
        XCTAssertEqual(made, ["Videos", "Audio", "Installers", "ZIP files"])
    }

    func testBusyFileStays() throws {
        let (_, result) = try tidy(sample, engine: engine)
        XCTAssertTrue(exists(sample, "just-saved.docx"))
        XCTAssertFalse(result.moved.contains { $0.from.lastPathComponent == "just-saved.docx" })
    }

    /// Re-checked just before moving: a file edited after planning stays.
    func testFileBecomesBusyAfterPlanStays() throws {
        let plan = try makePlan()
        engine.busyWindow = 10 * 365 * 24 * 3600   // everything counts as just changed
        let result = try engine.apply(plan, approval: Approval(approving: plan))
        XCTAssertTrue(result.moved.isEmpty)
        XCTAssertEqual(result.skipped.count, plan.moves.count)
        XCTAssertTrue(result.skipped.allSatisfy { $0.reason == .inUse })
    }

    func testFileRemovedAfterPlanIsSkipped() throws {
        let plan = try makePlan()
        try SampleFolder.rename(sample.appendingPathComponent("sample.txt"), to: "renamed.txt") // safety-check: allow test renames a file in its own sample
        let result = try engine.apply(plan, approval: Approval(approving: plan))
        XCTAssertTrue(result.skipped.contains { $0.url.lastPathComponent == "sample.txt" && $0.reason == .missing })
        XCTAssertTrue(exists(sample, "renamed.txt"))
        XCTAssertFalse(exists(sample, "Documents/sample.txt"))
    }

    // MARK: Never overwrite

    func testFileAppearingAtTargetIsNotOverwritten() throws {
        let plan = try makePlan()
        try SampleFolder.addFile(named: "sample.docx", in: sample.appendingPathComponent("Documents"))
        let result = try engine.apply(plan, approval: Approval(approving: plan))
        XCTAssertEqual(try contents(sample, "Documents/sample.docx"), "new")
        XCTAssertEqual(try contents(sample, "Documents/sample 2.docx"), "sample docx")
        XCTAssertTrue(result.moved.contains { $0.to.lastPathComponent == "sample 2.docx" })
    }

    func testPackageClashKeepsExtension() throws {
        XCTAssertEqual(FileEngine.numbered("Essay.pages", 2), "Essay 2.pages")
        XCTAssertEqual(FileEngine.numbered("Report.PDF", 3), "Report 3.PDF")
        XCTAssertEqual(FileEngine.numbered("notes", 2), "notes 2")
        XCTAssertEqual(FileEngine.numbered("a.tar.gz", 2), "a.tar 2.gz")
        XCTAssertEqual(FileEngine.numbered("invoice.pdf", 1), "invoice.pdf")
    }

    /// A link where Mojo would make a folder must not be followed.
    func testLinkInTheWayOfANewFolderIsNotFollowed() throws {
        let outside = sample.deletingLastPathComponent().appendingPathComponent("outside", isDirectory: true)
        try SampleFolder.addFolder(outside)
        let plan = try makePlan()
        try SampleFolder.addLink(named: "Videos", pointingTo: outside, in: sample)
        let result = try engine.apply(plan, approval: Approval(approving: plan))
        XCTAssertEqual(try listing(outside), [], "Mojo followed a link out of the chosen folder")
        XCTAssertTrue(exists(sample, "clip.mp4"))
        XCTAssertTrue(result.failed.contains { $0.url.lastPathComponent == "clip.mp4" })
    }

    // MARK: Refused plans

    func testPlanWithFileOutsideTheFolderIsRefused() throws {
        var plan = try makePlan()
        let first = try XCTUnwrap(plan.moves.first)
        plan.moves.append(PlannedMove(source: sample.appendingPathComponent("Documents/report.pdf"),
                                      fingerprint: first.fingerprint, category: .documents,
                                      targetFolderName: "Documents"))
        let before = try listing(sample)
        XCTAssertThrowsError(try engine.apply(plan, approval: Approval(approving: plan))) { error in
            guard case .invalidPlan = error as? MojoError else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(try listing(sample), before, "something moved before the plan was refused")
    }

    func testTargetNameThatClimbsOutIsRefused() throws {
        var plan = try makePlan()
        plan.moves[0].targetFolderName = ".."
        XCTAssertThrowsError(try engine.apply(plan, approval: Approval(approving: plan)))
        plan.moves[0].targetFolderName = "a/b"
        XCTAssertThrowsError(try engine.apply(plan, approval: Approval(approving: plan)))
    }

    // MARK: Labels

    func testMojoLabelAddedBesideExistingOne() throws {
        let before = FileEngine.rawTags(of: sample.appendingPathComponent("tagged.pdf"))
        let (_, result) = try tidy(sample, engine: engine)
        let after = FileEngine.rawTags(of: sample.appendingPathComponent("Documents/tagged.pdf"))
        XCTAssertEqual(after, before + ["Blue\n4"])
        let moved = try XCTUnwrap(result.moved.first { $0.from.lastPathComponent == "tagged.pdf" })
        XCTAssertEqual(moved.labelsAdded, ["Blue\n4"])
        XCTAssertEqual(FileEngine.rawTags(of: sample.appendingPathComponent("Images/photo.jpg")), ["Green\n2"])
    }

    // MARK: Move log

    func testLogRecordsEveryStepInOrder() throws {
        let (_, result) = try tidy(sample, engine: engine)
        let entries = try MoveLog.read(runID: result.runID, in: logFolder)
        XCTAssertEqual(entries.first?.kind, .runStarted)
        XCTAssertEqual(entries.last?.kind, .runFinished)
        for item in result.moved {
            let about = entries.firstIndex { $0.kind == .aboutToMove && $0.to == item.to }
            let done = entries.firstIndex { $0.kind == .moved && $0.to == item.to }
            XCTAssertNotNil(about, "\(item.to.lastPathComponent) not logged before moving")
            XCTAssertNotNil(done)
            if let about, let done { XCTAssertLessThan(about, done) }
        }
        let made = entries.filter { $0.kind == .folderCreated }.compactMap(\.to)
        XCTAssertEqual(Set(made), Set(result.foldersCreated))
        XCTAssertEqual(try engine.interruptedRuns(), [])
    }

    func testLogIsOutsideTheChosenFolder() throws {
        try tidy(sample, engine: engine)
        XCTAssertFalse(try listing(sample).contains { $0.hasPrefix("run-") })
    }

    /// The app stops between logging a move and making it (design steps 3–5).
    func testCrashHalfwayIsFoundOnNextLaunch() throws {
        engine.crashAfterMoves = 3
        let plan = try makePlan()
        XCTAssertThrowsError(try engine.apply(plan, approval: Approval(approving: plan)))

        let restarted = FileEngine(logFolder: logFolder)
        let runs = try restarted.interruptedRuns()
        XCTAssertEqual(runs.count, 1)
        let runID = try XCTUnwrap(runs.first)
        let entries = try MoveLog.read(runID: runID, in: logFolder)
        XCTAssertEqual(entries.filter { $0.kind == .moved }.count, 3)

        // The fourth file was logged but never moved: found where it was.
        let progress = try XCTUnwrap(try restarted.inProgressItem(runID: runID))
        let fourth = plan.moves[3].source.lastPathComponent
        XCTAssertEqual(progress.entry.from?.lastPathComponent, fourth)
        XCTAssertEqual(progress.foundAt?.lastPathComponent, fourth)
        XCTAssertTrue(exists(sample, fourth), "Mojo moved it again after the crash")
    }

    func testNoLogWhenNothingMoves() throws {
        let project = sample.appendingPathComponent("ProjectRoot")
        let (_, result) = try tidy(project, engine: engine)
        XCTAssertTrue(result.moved.isEmpty)
        XCTAssertEqual(try MoveLog.allRuns(in: logFolder).count, 0)
    }
}
