import Foundation
import XCTest
@testable import MojoCore

/// T09: saved folders survive a restart and ask again when they change.
/// Runs outside the sandbox, so bookmarks are plain; the sandboxed,
/// security-scoped path is checked by hand in the app (see the card).
final class FolderAccessTests: XCTestCase {
    private var sample: URL!
    private var store: MemoryFolderStore!

    override func setUpWithError() throws {
        sample = try SampleFolder.make()
        store = MemoryFolderStore()
    }

    private func access() -> FolderAccess { FolderAccess(store: store, securityScoped: false) }

    /// A second FolderAccess on the same store is the app after a restart.
    func testSavedFolderIsReadyAfterRestart() throws {
        try access().add(sample)
        let restarted = access()
        let saved = try XCTUnwrap(restarted.folders.first)
        guard case .ready(let url) = restarted.status(of: saved) else {
            return XCTFail("expected ready, got \(restarted.status(of: saved))")
        }
        XCTAssertEqual(FolderAccess.comparable(url.path), FolderAccess.comparable(sample.path))
    }

    /// Spec: a folder is renamed → ask the user to choose it again.
    func testRenamedFolderNeedsChoosingAgain() throws {
        let saved = try access().add(sample)
        try SampleFolder.rename(sample, to: sample.lastPathComponent + " renamed") // safety-check: allow test renames its own sample folder
        XCTAssertEqual(access().status(of: saved), .chooseAgain(.renamedOrMoved))
    }

    /// Spec: access is lost → ask again, never guess.
    func testBrokenBookmarkNeedsChoosingAgain() throws {
        var saved = try access().add(sample)
        saved.bookmark = Data("not a bookmark".utf8)
        XCTAssertEqual(access().status(of: saved), .chooseAgain(.missing))
    }

    /// Remove from list forgets the folder and leaves it exactly as it was.
    func testRemoveForgetsButKeepsFolder() throws {
        let before = try listing(sample)
        let saved = try access().add(sample)
        access().remove(id: saved.id)
        XCTAssertTrue(access().folders.isEmpty)
        XCTAssertEqual(try listing(sample), before)
    }

    func testChoosingTheSameFolderTwiceKeepsOneEntry() throws {
        try access().add(sample)
        try access().add(sample)
        XCTAssertEqual(access().folders.count, 1)
    }

    func testOnlyFoldersCanBeChosen() {
        XCTAssertThrowsError(try access().add(sample.appendingPathComponent("sample.pdf")))
    }

    /// A ready folder can be read while it is open.
    func testWithAccessReadsTheFolder() throws {
        let saved = try access().add(sample)
        let count = try access().withAccess(to: saved) { url in
            try FolderScanner().scan(folder: url).count
        }
        XCTAssertEqual(count, try listing(sample).count)
    }

    /// A folder that needs choosing again is never opened.
    func testWithAccessRefusesAFolderThatMoved() throws {
        let saved = try access().add(sample)
        try SampleFolder.rename(sample, to: sample.lastPathComponent + " moved") // safety-check: allow test renames its own sample folder
        XCTAssertThrowsError(try access().withAccess(to: saved) { _ in 0 })
    }
}
