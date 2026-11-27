import Foundation
import XCTest
@testable import MojoCore

/// Pure rule tests: no disk access. Fail with notImplemented until T07.
final class RulesTests: XCTestCase {
    private func facts(_ name: String, type: String?, directory: Bool = false, package: Bool = false,
                       hidden: Bool = false, cloud: CloudState = .notInCloud,
                       link: Bool = false, alias: Bool = false, locked: Bool = false,
                       writable: Bool = true) -> FileFacts {
        FileFacts(url: URL(fileURLWithPath: "/sample/\(name)"), name: name,
                  fingerprint: Fingerprint(fileID: 1, size: 1, modified: Date(timeIntervalSince1970: 0)),
                  typeIdentifier: type, isDirectory: directory, isPackage: package,
                  isSymbolicLink: link, isAlias: alias, isHidden: hidden, isLocked: locked,
                  isWritable: writable, tags: [], cloud: cloud)
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

    // MARK: - T07 additions

    /// The Mac ignores capitals, and so do the rules (T01 Q6).
    func testExtensionsIgnoreCapitals() throws {
        XCTAssertEqual(try Rules().classify(facts("Report.PDF", type: "com.adobe.pdf")), .sort(.documents))
        XCTAssertEqual(try Rules().classify(facts("IMG_1.JPG", type: nil)), .sort(.images))
    }

    /// Pages, Numbers and Keynote files are packages but sort as documents.
    func testDocumentPackagesSort() throws {
        XCTAssertEqual(try Rules().classify(facts("Essay.pages", type: "com.apple.iwork.pages.sffpages",
                                                  directory: true, package: true)), .sort(.documents))
        XCTAssertEqual(try Rules().classify(facts("Big.pkg", type: "com.apple.installer-package-archive",
                                                  directory: true, package: true)), .sort(.installers))
    }

    func testAppsLibrariesAndProjectPackagesStay() throws {
        let rules = Rules()
        XCTAssertEqual(try rules.classify(facts("Tool.app", type: "com.apple.application-bundle",
                                                directory: true, package: true)), .stay(.systemOrApp))
        XCTAssertEqual(try rules.classify(facts("Photos Library.photoslibrary", type: "com.apple.photos.library",
                                                directory: true, package: true)), .stay(.library))
        XCTAssertEqual(try rules.classify(facts("App.xcodeproj", type: "com.apple.xcode.project",
                                                directory: true, package: true)), .stay(.projectFolder))
        XCTAssertEqual(try rules.classify(facts("Thing.bundle", type: "com.apple.bundle",
                                                directory: true, package: true)), .stay(.unknownType))
    }

    /// Safari's unfinished download is a package; it must not sort as a video.
    func testUnfinishedDownloadPackagesStay() throws {
        XCTAssertEqual(try Rules().classify(facts("film.mp4.download", type: "com.apple.safari.download",
                                                  directory: true, package: true)), .stay(.unfinishedDownload))
        XCTAssertEqual(try Rules().classify(facts("big.zip.part", type: "dyn.ah62d4rv4ge80"
                                                  )), .stay(.unfinishedDownload))
    }

    func testLinksLockedAndReadOnlyStay() throws {
        let rules = Rules()
        XCTAssertEqual(try rules.classify(facts("a.pdf", type: "com.adobe.pdf", link: true)), .stay(.aliasOrLink))
        XCTAssertEqual(try rules.classify(facts("a.pdf", type: "com.adobe.pdf", alias: true)), .stay(.aliasOrLink))
        XCTAssertEqual(try rules.classify(facts("a.pdf", type: "com.adobe.pdf", locked: true)), .stay(.locked))
        XCTAssertEqual(try rules.classify(facts("a.pdf", type: "com.adobe.pdf", writable: false)), .stay(.readOnly))
    }

    func testHiddenByNameAndSystemFilesStay() throws {
        XCTAssertEqual(try Rules().classify(facts(".DS_Store", type: "public.data")), .stay(.hidden))
        XCTAssertEqual(try Rules().classify(facts("Icon\r", type: "public.data")), .stay(.systemOrApp))
    }

    /// A downloaded iCloud file sorts like any other.
    func testDownloadedCloudFileSorts() throws {
        XCTAssertEqual(try Rules().classify(facts("a.pdf", type: "com.adobe.pdf", cloud: .downloaded)), .sort(.documents))
    }

    func testProjectMarkersIgnoreCapitals() throws {
        XCTAssertTrue(try Rules().isProjectFolder(topLevelNames: ["PACKAGE.JSON"]))
        XCTAssertTrue(try Rules().isProjectFolder(topLevelNames: ["My App.XcodeProj"]))
        XCTAssertFalse(try Rules().isProjectFolder(topLevelNames: ["git-notes.txt", "package.json.bak"]))
    }
}
