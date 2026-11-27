import Foundation
import XCTest
@testable import MojoCore

/// Pure rule tests: no disk access. Fail with notImplemented until T07.
final class RulesTests: XCTestCase {
    private func facts(_ name: String, type: String?, directory: Bool = false, package: Bool = false,
                       hidden: Bool = false, cloud: CloudState = .notInCloud) -> FileFacts {
        FileFacts(url: URL(fileURLWithPath: "/sample/\(name)"), name: name,
                  fingerprint: Fingerprint(fileID: 1, size: 1, modified: Date(timeIntervalSince1970: 0)),
                  typeIdentifier: type, isDirectory: directory, isPackage: package,
                  isSymbolicLink: false, isAlias: false, isHidden: hidden, isLocked: false,
                  isWritable: true, tags: [], cloud: cloud)
    }

    func testCategoriesFromSpecTable() throws {
        let rules = Rules()
        XCTAssertEqual(try rules.classify(facts("a.pdf", type: "com.adobe.pdf")), .sort(.documents))
        XCTAssertEqual(try rules.classify(facts("a.jpg", type: "public.jpeg")), .sort(.images))
        XCTAssertEqual(try rules.classify(facts("a.mov", type: "com.apple.quicktime-movie")), .sort(.videos))
        XCTAssertEqual(try rules.classify(facts("a.mp3", type: "public.mp3")), .sort(.audio))
        XCTAssertEqual(try rules.classify(facts("a.dmg", type: "com.apple.disk-image-udif")), .sort(.installers))
        XCTAssertEqual(try rules.classify(facts("a.zip", type: "public.zip-archive")), .sort(.zipFiles))
    }

    /// Design decision 4: Markdown is plain text.
    func testMarkdownGoesToDocuments() throws {
        XCTAssertEqual(try Rules().classify(facts("notes.md", type: "net.daringfireball.markdown")), .sort(.documents))
    }

    /// Build note: check for source code before plain text.
    func testCodeStaysEvenThoughItIsText() throws {
        XCTAssertEqual(try Rules().classify(facts("a.swift", type: "public.swift-source")), .stay(.codeFile))
        XCTAssertEqual(try Rules().classify(facts("a.py", type: "public.python-script")), .stay(.codeFile))
    }

    func testUnknownAndUnfinishedStay() throws {
        XCTAssertEqual(try Rules().classify(facts("a.xyz", type: "dyn.ah62d4rv4ge80")), .stay(.unknownType))
        XCTAssertEqual(try Rules().classify(facts("m.mp4.crdownload", type: "dyn.ah62d4rv4ge80g6xer75065dtqfwa")), .stay(.unfinishedDownload))
    }

    /// T01 findings: online-only and still-uploading iCloud files stay.
    func testCloudFilesThatAreNotLocalStay() throws {
        XCTAssertEqual(try Rules().classify(facts("a.pdf", type: "com.adobe.pdf", cloud: .onlineOnly)), .stay(.onlineOnly))
        XCTAssertEqual(try Rules().classify(facts("a.pdf", type: "com.adobe.pdf", cloud: .notYetUploaded)), .stay(.notYetUploaded))
    }

    func testFoldersAndHiddenStay() throws {
        XCTAssertEqual(try Rules().classify(facts("Stuff", type: "public.folder", directory: true)), .stay(.existingFolder))
        XCTAssertEqual(try Rules().classify(facts(".secret", type: "public.data", hidden: true)), .stay(.hidden))
    }

    func testProjectMarkers() throws {
        let rules = Rules()
        for marker in [".git", "package.json", "Package.swift", "App.xcodeproj", "App.xcworkspace"] {
            XCTAssertTrue(try rules.isProjectFolder(topLevelNames: ["a.pdf", marker]), marker)
        }
        XCTAssertFalse(try rules.isProjectFolder(topLevelNames: ["a.pdf", "b.jpg"]))
    }
}
