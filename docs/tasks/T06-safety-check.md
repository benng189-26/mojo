Task: T06, safety check script
Level: Light (Smart approves)
Status: done 2026-11-27, self-test 7 of 7 on Ben's Mac

Goal: a script that fails if any code outside MojoCore's FileEngine can
change files, so the rule in AGENTS.md is checked on every card.

Read: AGENTS.md, docs/spec.md (Build notes)

May change:
- scripts/safety-check.sh
- scripts/safety-check-fixtures/planted.swift, planted.entitlements (test only)
- docs/handoff.md

Must not change: anything else

What it does:
- Scans every `.swift` file under `MojoCore/` and `Mojo/`, except
  `MojoCore/Sources/MojoCore/FileEngine/`.
- Fails (exit 1, lists file and line) on any file-changing call, including:
  `moveItem`, `copyItem`, `removeItem`, `trashItem`, `replaceItem`,
  `createDirectory`, `createFile`, `linkItem`, `createSymbolicLink`,
  `setAttributes`, `setResourceValue`, `setResourceValues`, `tagNames`
  writes, `write(to:`, `Data.write`, `String.write`, `FileHandle(forWriting`,
  `rename(`, `unlink(`, `remove(`, `rmdir(`, `chflags(`, `Process(`,
  `NSWorkspace.shared.recycle`, `emptyTrash`.
- Fails if the app asks for network access: the
  `com.apple.security.network.client` or `.server` entitlement, or any use of
  `URLSession`, `Network` framework or `NWConnection`.
- Allows a line only with an inline `// safety-check: allow <reason>` comment,
  and prints every allowed line, so Smart sees each exception.
- `--self-test` runs it against `safety-check-fixtures/planted.swift` and
  must fail there.

Done when: `--self-test` catches the planted example, a clean run passes, and
Smart approves the pattern list.

After: add three lines to docs/handoff.md
