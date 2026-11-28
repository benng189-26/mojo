Task: T09, folder access and saved permissions
Level: Smart
Status: approved by Ben 2026-11-28; built, waiting for a run on Ben's Mac

Goal: the user picks folders in the sandboxed app, Mojo keeps access to
them after a restart, and asks again when a folder is renamed, moved or
access is lost (spec: Technical issues, Folder access). Also answers T01
Q8 for bookmarks: does a sandboxed build keep access after a restart?

Read: AGENTS.md, docs/spec.md (Technical issues), docs/decisions.md (T01 Q8),
docs/design.md

May change:
- MojoCore/Sources/MojoCore/Access/FolderAccess.swift (new)
- MojoCore/Tests/MojoCoreTests/FolderAccessTests.swift (new)
- MojoCore/Tests/MojoCoreTests/SampleFolder.swift (add a rename helper for
  sample folders only, with a safety-check allow tag)
- Mojo/App/** (a Folders screen: Choose folder, list, Remove from list)
- Mojo/Mojo.xcodeproj/project.pbxproj (add the new app files)
- docs/decisions.md (Q8 result), docs/handoff.md, this card

Must not change: FileEngine, SafetyTests, scripts/, entitlements

How it works:
- Folders are chosen only with the system Open panel (folders only, one or
  more). Desktop, Downloads and Documents are offered as shortcuts that open
  the panel already pointing there; the user still clicks Open.
- For each folder Mojo saves a security-scoped bookmark plus the path it had,
  in the app's own preferences. Nothing is written to the user's folders.
- On launch each bookmark is resolved. A folder is "ready" only if it
  resolves, is still at the saved path, and can be listed. A stale bookmark
  at the same path is quietly refreshed.
- Renamed, moved, missing or no longer allowed: shown as "Choose again"
  with the reason, and never used until the user picks it again.
- Access is opened only while Mojo reads or tidies a folder, then closed.
- Remove from list forgets the bookmark only. The folder is untouched.
- The screen shows how many items each ready folder holds (a read-only scan),
  to prove access works. No sorting yet.

Done when:
- `swift test --package-path MojoCore --filter FolderAccessTests` passes:
  save and resolve with a fresh instance (a restart), renamed folder needs
  choosing again, deleted-bookmark data needs choosing again, remove forgets
- `swift test --package-path MojoCore` builds; safety check passes
- On Ben's Mac, with a folder made by the sample script (never a real one):
  choose it in the app, quit, reopen, and it is still ready with its count;
  rename it in Finder, reopen, and it says Choose again
- codesign still shows no network entitlement

After: add three lines to docs/handoff.md, and the Q8 result to decisions.md
