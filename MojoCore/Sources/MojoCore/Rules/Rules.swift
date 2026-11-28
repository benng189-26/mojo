import Foundation

/// Result of looking at one item: where it goes, or why it stays.
public enum Classification: Hashable, Sendable {
    case sort(FileCategory)
    case stay(StayReason)
}

/// Pure sorting rules (spec: Sorting rules, What always stays). Built in T07.
/// Never touches the disk: everything it needs is in FileFacts.
///
/// The checks run in a fixed order, and anything that is not clearly one of
/// the sortable types stays where it is (AGENTS.md: when unsure, leave it).
public struct Rules: Sendable {
    public init() {}

    /// Classify one top-level item of a chosen folder.
    public func classify(_ facts: FileFacts) throws -> Classification {
        let name = facts.name
        let ext = Self.fileExtension(of: name)
        let type = facts.typeIdentifier?.lowercased()

        // 1. Links and aliases are never followed or moved.
        if facts.isSymbolicLink || facts.isAlias { return .stay(.aliasOrLink) }

        // 2. Hidden and system files.
        if facts.isHidden || name.hasPrefix(".") { return .stay(.hidden) }
        if Self.systemNames.contains(name) { return .stay(.systemOrApp) }

        // 3. Unfinished downloads, by extension, before any type check:
        //    browsers give them dyn.* types, and Safari's are packages.
        if Self.unfinishedDownloadExtensions.contains(ext) { return .stay(.unfinishedDownload) }

        // 4. Apps and libraries (both are packages).
        if ext == "app" || type == "com.apple.application-bundle" || type == "com.apple.application" {
            return .stay(.systemOrApp)
        }
        if ext.hasSuffix("library") || Self.libraryTypes.contains(type ?? "") { return .stay(.library) }

        // 5. Folders that are not packages are never moved or rearranged.
        //    Pages, Numbers and Keynote files are folders on disk; a Mac that
        //    has never had iWork may not mark them as packages (T08).
        if facts.isDirectory && !facts.isPackage && !Self.documentPackageExtensions.contains(ext) {
            return .stay(.existingFolder)
        }

        // 6. Project packages such as App.xcodeproj.
        if Self.projectPackageExtensions.contains(ext) { return .stay(.projectFolder) }

        // 7. Cloud files that are not fully on this Mac (T01 findings).
        switch facts.cloud {
        case .onlineOnly: return .stay(.onlineOnly)
        case .notYetUploaded: return .stay(.notYetUploaded)
        case .notInCloud, .downloaded: break
        }

        // 8. Files Mojo could not move safely.
        if facts.isLocked { return .stay(.locked) }
        if !facts.isWritable { return .stay(.readOnly) }

        // 9. Source code, checked before plain text (build note). Markdown is
        //    plain text, not code (design decision 4).
        if Self.codeExtensions.contains(ext) || Self.codeTypes.contains(type ?? "") {
            return .stay(.codeFile)
        }

        // 10. The six sortable categories: extension first, then type.
        if let category = Self.categoryByExtension[ext] ?? Self.categoryByType[type ?? ""] {
            return .sort(category)
        }

        // 11. Anything else, including unknown packages, stays.
        return .stay(.unknownType)
    }

    /// True when the chosen folder's own top level marks it as a project
    /// (.xcodeproj, .xcworkspace, Package.swift, .git, package.json).
    /// Then nothing in it moves. Names are compared ignoring capitals,
    /// because the Mac's disk ignores them too (T01 Q6).
    public func isProjectFolder(topLevelNames: [String]) throws -> Bool {
        topLevelNames.contains { name in
            let lower = name.lowercased()
            return Self.projectMarkerNames.contains(lower)
                || Self.projectPackageExtensions.contains(Self.fileExtension(of: lower))
        }
    }

    // MARK: - Tables

    /// Lowercased extension after the last dot, or "" when there is none.
    /// A leading dot alone (".secret") is not an extension.
    static func fileExtension(of name: String) -> String {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return String(name[name.index(after: dot)...]).lowercased()
    }

    static let systemNames: Set<String> = ["Icon\r", "Thumbs.db", "desktop.ini"]

    static let unfinishedDownloadExtensions: Set<String> = [
        "crdownload", "download", "part", "partial", "opdownload", "!ut", "aria2",
    ]

    static let libraryTypes: Set<String> = [
        "com.apple.photos.library", "com.apple.iphoto.library", "com.apple.music.library",
    ]

    static let documentPackageExtensions: Set<String> = ["pages", "numbers", "key"]

    static let projectMarkerNames: Set<String> = [".git", "package.json", "package.swift"]
    static let projectPackageExtensions: Set<String> = ["xcodeproj", "xcworkspace"]

    static let codeExtensions: Set<String> = [
        "swift", "py", "js", "mjs", "cjs", "ts", "tsx", "jsx", "java", "kt", "c", "h", "m",
        "mm", "cpp", "cc", "hpp", "cs", "go", "rs", "rb", "php", "sh", "zsh", "bash", "pl",
        "lua", "r", "sql", "html", "htm", "css", "scss", "json", "yaml", "yml", "toml",
        "xml", "plist", "ipynb", "gradle", "make", "cmake",
    ]
    static let codeTypes: Set<String> = [
        "public.source-code", "public.swift-source", "public.python-script",
        "com.netscape.javascript-source", "public.shell-script", "public.c-source",
        "public.c-header", "public.objective-c-source", "public.c-plus-plus-source",
        "public.ruby-script", "public.perl-script", "public.php-script", "public.json",
        "public.html", "public.xml", "com.apple.property-list",
    ]

    static let categoryByExtension: [String: FileCategory] = [
        "pdf": .documents, "doc": .documents, "docx": .documents, "xls": .documents,
        "xlsx": .documents, "ppt": .documents, "pptx": .documents, "pages": .documents,
        "numbers": .documents, "key": .documents, "txt": .documents, "md": .documents,
        "markdown": .documents,
        "jpg": .images, "jpeg": .images, "png": .images, "heic": .images,
        "mp4": .videos, "mov": .videos,
        "mp3": .audio, "m4a": .audio, "wav": .audio,
        "dmg": .installers, "pkg": .installers,
        "zip": .zipFiles,
    ]
    static let categoryByType: [String: FileCategory] = [
        "com.adobe.pdf": .documents,
        "com.microsoft.word.doc": .documents,
        "org.openxmlformats.wordprocessingml.document": .documents,
        "com.microsoft.excel.xls": .documents,
        "org.openxmlformats.spreadsheetml.sheet": .documents,
        "com.microsoft.powerpoint.ppt": .documents,
        "org.openxmlformats.presentationml.presentation": .documents,
        "com.apple.iwork.pages.sffpages": .documents, "com.apple.iwork.pages.pages": .documents,
        "com.apple.iwork.numbers.sffnumbers": .documents, "com.apple.iwork.numbers.numbers": .documents,
        "com.apple.iwork.keynote.sffkey": .documents, "com.apple.iwork.keynote.key": .documents,
        "public.plain-text": .documents, "public.utf8-plain-text": .documents,
        "net.daringfireball.markdown": .documents,
        "public.jpeg": .images, "public.png": .images, "public.heic": .images,
        "public.mpeg-4": .videos, "com.apple.quicktime-movie": .videos,
        "public.mp3": .audio, "com.apple.m4a-audio": .audio, "public.mpeg-4-audio": .audio,
        "com.microsoft.waveform-audio": .audio,
        "com.apple.disk-image-udif": .installers, "com.apple.disk-image": .installers,
        "com.apple.installer-package-archive": .installers,
        "public.zip-archive": .zipFiles, "com.pkware.zip-archive": .zipFiles,
    ]
}
