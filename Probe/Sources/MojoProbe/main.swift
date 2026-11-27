// MojoProbe (T01): read-mostly probe of folder, iCloud, Trash and tag behaviour.
//
// Safety:
// - Creates ONE new folder, MojoProbe-<timestamp>, inside the location given
//   on the command line, and only ever acts on files it creates there.
// - Never deletes, never overwrites, never empties the Trash.
// - Never downloads an online-only file: metadata only.
// - No network calls.
//
// Usage:
//   swift run --package-path Probe MojoProbe <location> [--trash] [--check <file>]
//   --trash         also send one probe-made file to the Trash (asks first)
//   --check <file>  report metadata for one file Ben names, read only
//                   (used for the online-only test; nothing is changed)

import Foundation

let fm = FileManager.default
var args = Array(CommandLine.arguments.dropFirst())

func line(_ s: String) { print(s) }
func fail(_ s: String) -> Never { FileHandle.standardError.write(("error: " + s + "\n").data(using: .utf8)!); exit(1) }

func ask(_ q: String) -> Bool {
    print(q + " [y/N] ", terminator: "")
    return (readLine() ?? "").lowercased().hasPrefix("y")
}

// MARK: read-only metadata report

func report(_ url: URL, title: String) {
    let keys: Set<URLResourceKey> = [
        .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey,
        .ubiquitousItemIsDownloadingKey, .ubiquitousItemIsUploadedKey,
        .ubiquitousItemIsUploadingKey, .isUserImmutableKey, .isWritableKey,
        .tagNamesKey, .volumeSupportsCaseSensitiveNamesKey, .volumeIsLocalKey,
        .volumeIsInternalKey, .volumeNameKey, .isPackageKey, .isAliasFileKey,
        .isSymbolicLinkKey, .typeIdentifierKey,
    ]
    line("== \(title): \(url.path)")
    do {
        let v = try url.resourceValues(forKeys: keys)
        line("  type:                \(v.typeIdentifier ?? "?")")
        line("  package:             \(v.isPackage.map(String.init) ?? "?")")
        line("  alias / symlink:     \(v.isAliasFile.map(String.init) ?? "?") / \(v.isSymbolicLink.map(String.init) ?? "?")")
        line("  in iCloud:           \(v.isUbiquitousItem.map(String.init) ?? "?")")
        line("  download status:     \(v.ubiquitousItemDownloadingStatus?.rawValue ?? "n/a")")
        line("  downloading:         \(v.ubiquitousItemIsDownloading.map(String.init) ?? "n/a")")
        line("  uploaded/uploading:  \(v.ubiquitousItemIsUploaded.map(String.init) ?? "n/a") / \(v.ubiquitousItemIsUploading.map(String.init) ?? "n/a")")
        line("  locked (uchg):       \(v.isUserImmutable.map(String.init) ?? "?")")
        line("  writable:            \(v.isWritable.map(String.init) ?? "?")")
        line("  tags:                \(v.tagNames ?? [])")
        line("  volume:              \(v.volumeName ?? "?") local=\(v.volumeIsLocal.map(String.init) ?? "?") internal=\(v.volumeIsInternal.map(String.init) ?? "?")")
        line("  case-sensitive vol:  \(v.volumeSupportsCaseSensitiveNames.map(String.init) ?? "?")")
    } catch {
        line("  could not read metadata: \(error.localizedDescription)")
    }
}

// MARK: parse arguments

if let i = args.firstIndex(of: "--check") {
    guard i + 1 < args.count else { fail("--check needs a file path") }
    let target = URL(fileURLWithPath: args[i + 1]).standardizedFileURL
    // Only files the probe made: the path must sit inside a MojoProbe-* folder.
    let parts = target.pathComponents.dropLast()
    guard parts.contains(where: { $0.hasPrefix("MojoProbe-") }) else {
        fail("--check only reads files inside a MojoProbe-<date> folder the probe made")
    }
    // Read-only: resourceValues never triggers a download.
    report(target, title: "check (read only)")
    exit(0)
}
let doTrash = args.contains("--trash")
args.removeAll { $0.hasPrefix("--") }
guard let locationArg = args.first else {
    fail("usage: MojoProbe <location> [--trash] | --check <file>")
}

let location = URL(fileURLWithPath: locationArg, isDirectory: true).standardizedFileURL
var isDir: ObjCBool = false
guard fm.fileExists(atPath: location.path, isDirectory: &isDir), isDir.boolValue else {
    fail("location is not an existing folder: \(location.path)")
}

// MARK: create the probe's own folder (the only place it acts)

let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
let probeDir = location.appendingPathComponent("MojoProbe-\(stamp)", isDirectory: true)
guard !fm.fileExists(atPath: probeDir.path) else { fail("probe folder already exists") }

func insideProbe(_ url: URL) -> Bool {
    url.standardizedFileURL.path.hasPrefix(probeDir.standardizedFileURL.path + "/")
}

/// Creates a new file inside the probe folder. Refuses to overwrite.
func makeFile(_ name: String, _ text: String) -> URL {
    let url = probeDir.appendingPathComponent(name)
    guard insideProbe(url) else { fail("refusing to write outside probe folder") }
    guard !fm.fileExists(atPath: url.path) else { fail("refusing to overwrite \(name)") }
    guard fm.createFile(atPath: url.path, contents: Data(text.utf8)) else { fail("could not create \(name)") }
    return url
}

line("MojoProbe will create \(probeDir.path)")
line("and act only on files inside it. Nothing else is read or changed.")
guard ask("Continue?") else { line("Stopped. Nothing changed."); exit(0) }

do {
    try fm.createDirectory(at: probeDir, withIntermediateDirectories: false)
} catch { fail("could not create probe folder: \(error.localizedDescription)") }

report(probeDir, title: "probe folder")

// Q5: tags. Add a tag beside an existing one, then check both are present.
let tagged = makeFile("tagged.txt", "tag test")
do {
    // URLResourceValues.tagNames is read-only in Swift, so set tags via NSURL.
    let ns = tagged as NSURL
    try ns.setResourceValue(["Red"], forKey: .tagNamesKey)   // pretend the user had a label
    let existing = try tagged.resourceValues(forKeys: [.tagNamesKey]).tagNames ?? []
    try ns.setResourceValue(existing + ["Blue"], forKey: .tagNamesKey)  // Mojo adds its own beside it
    var fresh = tagged
    fresh.removeAllCachedResourceValues()
    let after = try fresh.resourceValues(forKeys: [.tagNamesKey]).tagNames ?? []
    line("Q5 tags: before=\(existing) after=\(after) kept-existing=\(after.contains("Red"))")
} catch {
    line("Q5 tags: failed: \(error.localizedDescription)")
}

// Q6: case-only clash. Does "Report.txt" exist when we create "report.txt"?
_ = makeFile("report.txt", "lower")
let upper = probeDir.appendingPathComponent("Report.txt")
line("Q6 case clash: Report.txt seen as existing = \(fm.fileExists(atPath: upper.path))")

// Q7: busy / unfinished markers.
let partial = makeFile("movie.mp4.crdownload", "partial")
report(partial, title: "Q7 unfinished download name")

// Q7: locked file. Lock a probe-made file, read the flag back, then unlock it
// so Ben can remove the probe folder normally afterwards.
let locked = makeFile("locked.txt", "lock test")
do {
    let ns = locked as NSURL
    try ns.setResourceValue(true, forKey: .isUserImmutableKey)
    var fresh = locked
    fresh.removeAllCachedResourceValues()
    let seen = try fresh.resourceValues(forKeys: [.isUserImmutableKey]).isUserImmutable ?? false
    line("Q7 locked: flag set, read back as locked = \(seen)")
    try ns.setResourceValue(false, forKey: .isUserImmutableKey)
    fresh.removeAllCachedResourceValues()
    let after = try fresh.resourceValues(forKeys: [.isUserImmutableKey]).isUserImmutable ?? true
    line("Q7 locked: unlocked again = \(!after)")
} catch {
    line("Q7 locked: failed: \(error.localizedDescription)")
    line("  if locked.txt is still locked: Finder > Get Info > untick Locked")
}

// Q2 prep: a file for Ben to evict by hand when the probe folder is in iCloud Drive.
let evict = makeFile("evict-me.txt", String(repeating: "Mojo probe eviction test. ", count: 4000))
report(evict, title: "Q2 evict-me.txt before eviction")

// Q3/Q4: Trash.
if doTrash {
    let victim = makeFile("trash-me.txt", "trash test")
    guard insideProbe(victim) else { fail("refusing to trash outside probe folder") }
    if ask("Send \(victim.lastPathComponent) (made by the probe) to the Trash?") {
        do {
            var resulting: NSURL?
            try fm.trashItem(at: victim, resultingItemURL: &resulting)
            line("Q3 trash: ok, now at \(resulting?.path ?? "unknown")")
            line("Q4: open the Trash in Finder, right-click trash-me.txt, and note whether Put Back appears.")
        } catch {
            let e = error as NSError
            line("Q3 trash: failed, file left in place: \(e.localizedDescription) [\(e.domain) \(e.code)]")
        }
    }
}

line("")
line("Done. Probe folder left in place for you to inspect: \(probeDir.path)")
line("Q2 (online-only, only when this folder is in iCloud Drive): in Finder, right-click")
line("evict-me.txt in the probe folder > Remove Download, wait a moment, then run:")
line("  swift run --package-path Probe MojoProbe --check \"\(evict.path)\"")
line("Run --check twice. It reads metadata only; the second run must still show not downloaded.")
