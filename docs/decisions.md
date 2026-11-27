# Decisions

What we learned and chose. Newest first.

## 2026-11-27, Core design approved (Ben)

Ben approved docs/design.md with its five suggestions:
1. Undo may delete `.DS_Store` only, only inside a folder Mojo made, only to
   remove that folder when it is otherwise empty. The one exception to never
   deleting, listed in AGENTS.md.
2. Name clashes are numbered Finder-style: `report 2.pdf`.
3. When every copy of a duplicate is ticked, the oldest copy is kept.
4. Markdown (`.md`) is plain text and goes to Documents.
5. An existing folder matches when its name is the same ignoring capitals.

## 2026-11-27, Cloud folders (Ben)

Version 1 sorts iCloud and other synced folders, after asking. The plan flags
synced folders and warns that moves and trashing reach all the user's devices.
Online-only and still-uploading files stay where they are.

## 2026-11-27, T01 probe findings (unsandboxed command-line probe, Ben's Mac)

Ran twice by Ben: once in `Mac | AI Cleanup/ProbeRuns` (internal disk), once
at the top of iCloud Drive. Both runs were on Macintosh HD.

| # | Question | Finding | What Mojo does |
|---|---|---|---|
| 1 | Detect iCloud folders | `isUbiquitousItem` is `true` in iCloud Drive and nil (not false) elsewhere. | Treat nil as "not iCloud". Flag iCloud folders in the plan and ask first. |
| 2 | Detect online-only files without downloading | Partly answered. Minutes after the run, **all five** files in the iCloud probe folder were online-only (`dataless`), not just evict-me.txt. `ls -lO` and Spotlight (`mdls`) read their size and tags and they stayed online-only. The probe's own `--check` (URL resource values) has not been run on them yet. | Expect online-only files at any time in iCloud folders, even new ones. Leave them in place. Confirm with `--check` that reading `ubiquitousItemDownloadingStatus` does not download. |
| 3 | `trashItem` works and returns the new place | Yes, on both. Internal file went to `~/.Trash/`. iCloud file went to `~/Library/Mobile Documents/.Trash/`, a separate iCloud Trash. | Record the returned URL in the move log for every trashed file. Say in the plan that trashing an iCloud file affects all of the user's devices. |
| 4 | Finder offers Put Back | **iCloud Trash: no.** Finder shows Download Now and Delete Immediately, but no Put Back, for the file trashed by `trashItem`. **Mac Trash (internal disk): yes**, Put Back appears. | Do not rely on Finder's Put Back, because it is missing for iCloud files. Mojo's history must store the old place and offer its own Put back for trashed files. |
| 5 | Add a tag beside an existing one | Works: `["Red"]` became `["Red", "Blue"]` on both. `URLResourceValues.tagNames` is read-only in Swift, so set tags with `NSURL.setResourceValue(_:forKey: .tagNamesKey)`. | Add Mojo's label beside existing labels. Undo removes only the label Mojo added. |
| 6 | Case-only name clash | Volume reports case-sensitive = false, and `Report.txt` is seen as existing when `report.txt` exists. | Always compare names ignoring case. Number the new arrival. |
| 7 | Unfinished and locked files | `.crdownload` gets a dynamic `dyn.*` type, so it falls under unknown types. The `uchg` lock flag can be read, set and cleared. | Skip names ending `.crdownload`, `.download`, `.part` explicitly, and skip unknown `dyn.*` types. Skip locked files and say why. |
| 8 | Sandboxed app: bookmarks after restart, Trash access | **Not tested.** The probe is unsandboxed. | Test in T09 with a sandboxed build before choosing App Store vs direct download. |

### Design rules that follow

- Mojo never reads the contents of an online-only file, so duplicate checks and photo dates skip them.
- Online-only files do not count towards the space Mojo says it can free.
- History stores the Trash location macOS returns, because iCloud files go to their own Trash.
- Mojo adds its label beside existing labels.

### Extra finding

- A file newly created in iCloud Drive showed `uploaded = false`. Suggestion:
  skip iCloud files that have not finished uploading, the same as unfinished
  downloads, and say why.

### Still to decide (Ben)

- Distribution: App Store or direct download, after T09.

### Leftovers on Ben's Mac

Probe test folders (safe to delete by hand when done):
- `Mac | AI Cleanup/ProbeRuns/MojoProbe-2026-11-27T19-23-23Z`
- `iCloud Drive/MojoProbe-2026-11-27T19-23-39Z`
- `trash-me.txt` in the Mac Trash and the iCloud Trash
