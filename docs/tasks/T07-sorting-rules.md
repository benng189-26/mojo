Task: T07, file type rules and what always stays
Level: Standard, Smart review
Status: done 2026-11-27. 15 of 15 RulesTests pass on Ben's Mac

Goal: make Rules.classify and Rules.isProjectFolder real, so every item
gets a folder or a reason to stay. Pure code: no disk access.

Read: docs/spec.md (Sorting rules, What always stays), docs/design.md,
docs/decisions.md (T01 findings, design decisions 4 and 5)

May change:
- MojoCore/Sources/MojoCore/Rules/Rules.swift
- MojoCore/Tests/MojoCoreTests/RulesTests.swift (add tests only; keep every existing one)
- docs/handoff.md, this card

Must not change: FileEngine, SafetyTests, scripts/, Mojo/

Order of checks (first match wins; anything unclear stays):
1. link or alias  2. hidden or system file  3. unfinished download (by
extension, before type: browsers use dyn.* types and Safari's are packages)
4. app or library  5. plain folder  6. .xcodeproj/.xcworkspace  7. iCloud
online-only or still uploading  8. locked or read-only  9. source code
(before plain text; Markdown is not code)  10. the six categories, by
extension then type, ignoring capitals  11. everything else: unknown type

Done when:
- `swift test --package-path MojoCore --filter RulesTests` passes (15 tests)
- `swift test --package-path MojoCore` builds; only SafetyTests still fail,
  with notImplemented (they need the scanner, T08)
- `bash scripts/safety-check.sh` passes

After: add three lines to docs/handoff.md
