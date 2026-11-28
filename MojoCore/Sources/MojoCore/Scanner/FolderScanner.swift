import Foundation
import UniformTypeIdentifiers

/// Reads the top level of a chosen folder. Read only: never follows links,
/// never downloads an online-only file, can be cancelled. Built in T08.
///
/// Everything here only reads: directory listing, resource values and
/// `lstat`-style attributes. Nothing opens a file's contents, so an
/// online-only iCloud file is never downloaded (T01 Q2).
public struct FolderScanner: Sendable {
    public init() {}

    static let keys: [URLResourceKey] = [
        .nameKey, .fileSizeKey, .contentModificationDateKey, .contentTypeKey,
        .isDirectoryKey, .isPackageKey, .isSymbolicLinkKey, .isAliasFileKey,
        .isHiddenKey, .isUserImmutableKey, .isWritableKey, .tagNamesKey,
        .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey, .ubiquitousItemIsUploadedKey,
    ]

    /// Facts for every top-level item, including hidden ones (Rules decides
    /// what stays). Throws `MojoError.cancelled` if `isCancelled` turns true.
    /// Results are sorted by name so plans come out the same every time.
    public func scan(folder: URL, isCancelled: @Sendable () -> Bool = { false }) throws -> [FileFacts] {
        if isCancelled() { throw MojoError.cancelled }
        let urls: [URL]
        do {
            // No options: hidden files are included, and links are listed as
            // links, not followed. Only the top level is read.
            urls = try FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: Self.keys, options: [])
        } catch {
            throw MojoError.folderUnavailable(folder)
        }
        var result: [FileFacts] = []
        result.reserveCapacity(urls.count)
        for url in urls {
            if isCancelled() { throw MojoError.cancelled }
            result.append(try facts(for: url))
        }
        return result.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Fresh facts for one item, used by FileEngine just before a move.
    /// A link is described as itself, never as the item it points to.
    public func facts(for url: URL) throws -> FileFacts {
        let item = url.standardizedFileURL
        // Attributes of the item itself (lstat): the file number and size of
        // a link are the link's, not its target's.
        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try FileManager.default.attributesOfItem(atPath: item.path)
        } catch {
            throw MojoError.folderUnavailable(item)
        }
        var values = URLResourceValues()
        // Resource values never traverse the last link in a path. Clear any
        // cached values so FileEngine's re-check sees the file as it is now.
        var fresh = item
        fresh.removeAllCachedResourceValues()
        if let read = try? fresh.resourceValues(forKeys: Set(Self.keys)) { values = read }

        let isLink = (attributes[.type] as? FileAttributeType) == .typeSymbolicLink
            || values.isSymbolicLink == true
        let fileID = (attributes[.systemFileNumber] as? NSNumber)?.uint64Value ?? 0
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? Int64(values.fileSize ?? 0)
        let modified = (attributes[.modificationDate] as? Date)
            ?? values.contentModificationDate ?? Date(timeIntervalSince1970: 0)

        return FileFacts(
            url: item,
            name: values.name ?? item.lastPathComponent,
            fingerprint: Fingerprint(fileID: fileID, size: size, modified: modified),
            typeIdentifier: isLink ? nil : values.contentType?.identifier,
            isDirectory: !isLink && values.isDirectory == true,
            isPackage: !isLink && values.isPackage == true,
            isSymbolicLink: isLink,
            // Finder aliases are alias files that are not symbolic links.
            isAlias: !isLink && values.isAliasFile == true,
            isHidden: values.isHidden == true || item.lastPathComponent.hasPrefix("."),
            isLocked: values.isUserImmutable == true,
            isWritable: values.isWritable ?? false,
            tags: values.tagNames ?? [],
            cloud: Self.cloudState(values))
    }

    /// iCloud state from resource values only (T01 Q1, Q2, Q7).
    static func cloudState(_ values: URLResourceValues) -> CloudState {
        guard values.isUbiquitousItem == true else { return .notInCloud }
        if values.ubiquitousItemDownloadingStatus == .notDownloaded { return .onlineOnly }
        if values.ubiquitousItemIsUploaded == false { return .notYetUploaded }
        return .downloaded
    }
}
