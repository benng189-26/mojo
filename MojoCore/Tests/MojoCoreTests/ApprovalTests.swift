import Foundation
import XCTest
@testable import MojoCore

/// Approval checks are real code in T03 (pure, no files), so these pass now.
final class ApprovalTests: XCTestCase {
    private let folder = URL(fileURLWithPath: "/sample")

    private func move(_ name: String) -> PlannedMove {
        PlannedMove(source: folder.appendingPathComponent(name),
                    fingerprint: Fingerprint(fileID: 7, size: 3, modified: Date(timeIntervalSince1970: 100)),
                    category: .documents, targetFolderName: "Documents")
    }

    func testApprovalMatchesSamePlan() {
        let plan = Plan(folder: folder, moves: [move("a.pdf")], stays: [], warnings: [])
        XCTAssertTrue(Approval(approving: plan).matches(plan))
    }

    func testAnyChangeBreaksApproval() {
        let plan = Plan(folder: folder, moves: [move("a.pdf"), move("b.pdf")], stays: [], warnings: [])
        let approval = Approval(approving: plan)

        var fewer = plan; fewer.moves.removeLast()
        var otherTarget = plan; otherTarget.moves[0].targetFolderName = "Images"
        var otherPrint = plan; otherPrint.moves[0].fingerprint.size = 4
        var otherID = plan; otherID.id = UUID()

        for changed in [fewer, otherTarget, otherPrint, otherID] {
            XCTAssertFalse(approval.matches(changed))
        }
    }

    func testEngineRefusesUnapprovedPlanBeforeTouchingAnything() {
        let engine = FileEngine(logFolder: URL(fileURLWithPath: "/nonexistent-log"))
        let plan = Plan(folder: folder, moves: [move("a.pdf")], stays: [], warnings: [])
        let other = Plan(folder: folder, moves: [], stays: [], warnings: [])
        XCTAssertThrowsError(try engine.apply(plan, approval: Approval(approving: other))) { error in
            XCTAssertEqual(error as? MojoError, .approvalMismatch)
        }
        XCTAssertThrowsError(try engine.trash([], approval: Approval(approving: other), plan: plan)) { error in
            XCTAssertEqual(error as? MojoError, .approvalMismatch)
        }
    }
}
