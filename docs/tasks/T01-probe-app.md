Task: T01, probe the risky parts
Level: Smart
Status: approved 2026-11-27 (probe uses only its own test folder)

Goal: a small throwaway command-line probe that answers how macOS behaves for
folder access, iCloud folders, online-only files, the Trash and Put Back,
before any real Mojo code is written.

Read: docs/spec.md (Technical issues, Mac, cloud and access), docs/spec-review.md

May change:
- Probe/Package.swift
- Probe/Sources/MojoProbe/*.swift
- docs/decisions.md
- docs/handoff.md

Must not change: MojoCore, FileEngine and safety tests (none exist yet)

Safety for this card (needs Ben's OK, see spec-review item 2):
- The probe only touches a folder it creates itself, named
  `MojoProbe-<date-time>`, inside a location Ben passes on the command line.
- It refuses to run if that path is not inside the folder it just created,
  and never lists, reads or changes anything outside it.
- It never deletes; trash tests use files it made. It never empties the Trash.
- It never downloads an online-only file. It reads metadata only.
- No network calls.
- Ben runs it on his Mac. It prints a report and writes nothing else.

Questions it answers:
1. Is the test folder inside iCloud Drive? (`isUbiquitousItem`)
2. For a file Ben has evicted ("Remove Download"), can we tell it is
   online-only without downloading it? (`ubiquitousItemDownloadingStatus`)
3. Does `FileManager.trashItem` work, and return the Trash URL, on the
   internal disk, in iCloud Drive and on an external drive (if plugged in)?
4. After `trashItem`, does Finder offer Put Back? (Ben checks by hand.)
5. Can we read and write Finder tags without changing existing ones?
   (`URLResourceValues.tagNames`)
6. Does a case-only name clash get detected on this volume?
   (`volumeSupportsCaseSensitiveNames`)
7. Can we detect a file that is still being written or is locked?
   (`isUserImmutable`, `.download`/`.crdownload`/`.part` names)
8. Sandboxed build: do security-scoped bookmarks to a chosen folder survive a
   restart, and can the sandboxed app call `trashItem`? (second run, later)

Done when:
- Findings for each question are written in docs/decisions.md
- Ben confirms the Put Back check by hand
- Ben decides on cloud folders (Phase 0 check)

After: add three lines to docs/handoff.md
