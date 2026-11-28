Task: T08, scanner for hidden files, links, online-only files and large folders
Level: Standard, Smart review
Status: built 2026-11-27; waiting for a run on Ben's Mac

Goal: FolderScanner.scan and facts(for:) read the top level of a chosen
folder into FileFacts. Read only, never follows links, never downloads
an online-only file, and Cancel stops it.

Read: docs/design.md, docs/decisions.md (T01 Q1, Q2, Q5, Q7), AGENTS.md

May change:
- MojoCore/Sources/MojoCore/Scanner/FolderScanner.swift
- MojoCore/Sources/MojoCore/Rules/Rules.swift (iWork folders only, see below)
- MojoCore/Tests/MojoCoreTests/ScannerTests.swift (new)
- MojoCore/Tests/MojoCoreTests/RulesTests.swift (add tests only)
- MojoCore/Tests/MojoCoreTests/SampleFolder.swift (add a `many:` option only)
- docs/handoff.md, this card

Must not change: FileEngine, SafetyTests, scripts/, Mojo/

How it reads:
- contentsOfDirectory with no options: hidden items included, links listed
  as links, top level only.
- File number, size and date come from the item itself (lstat), so a link
  never reports its target.
- iCloud state comes from resource values only; no file is opened.
- Rules: `.pages`, `.numbers` and `.key` folders sort as documents even when
  the Mac doesn't mark them as packages (a Mac without iWork may not).

Done when:
- `swift test --package-path MojoCore --filter "ScannerTests|RulesTests"` passes (9 + 16)
- `swift test --package-path MojoCore` builds; SafetyTests now fail with
  notImplemented from Planner (T10 area), not from the scanner
- `bash scripts/safety-check.sh` passes

After: add three lines to docs/handoff.md
