# Mojo core design (T03), approved by Ben 2026-11-27

One page. Covers MojoCore only: no screens. Based on docs/spec.md and the T01
findings in docs/decisions.md.

## Parts and who may change files

```
 chosen folder ──► Scanner ──► Rules ──► Planner ──► Plan ──(user approves)──► FileEngine ──► MoveLog
   (read only)     (read only)  (pure)    (pure)              Approval              (ONLY writer)   (journal)
                                                                                        │
                                                    History (read only) ◄───────────────┘
```

| Part | Job | Changes files? |
|---|---|---|
| Scanner | Lists the top level of a chosen folder and reads facts about each item. Never follows links, never downloads, can be cancelled. | No |
| Rules | Pure function: facts → a category (Documents, Images…) or Stay with a reason. | No |
| Planner | Pure: facts + rules + what is already in the folder → a Plan of moves, plus the list of files that stay and why, plus warnings (iCloud, first run). | No |
| FileEngine | Carries out an approved Plan, Clean up trashing, Undo and Put back. Writes the MoveLog. | **Yes, the only part** |
| History | Reads the MoveLog for search, Show in Finder and Put back buttons. | No |

The safety check (scripts/safety-check.sh) enforces this: only
`MojoCore/Sources/MojoCore/FileEngine/` may contain file-changing calls.

## Key types

- `FileFacts`: url, name, file ID, size, modified date, type (UTType), is
  folder / package / symlink / alias / hidden, Finder tags, locked, iCloud
  status (in iCloud, downloaded, uploaded).
- `Fingerprint`: file ID + size + modified date. Taken at scan time.
- `Plan`: id, chosen folder, list of `PlannedMove` (source, fingerprint,
  target folder name, label to add), list of `Stay` (item, reason), warnings.
- `Approval`: made only by the app when the user presses the wand. It holds
  the Plan id and a hash of its contents. FileEngine refuses a Plan whose hash
  does not match, so nothing changes without approval.
- `RunResult`: moved, skipped (with reason), failed (with error).

## How a move works (FileEngine)

For each approved move, one at a time:
1. Read the file's facts again. Skip if the fingerprint changed, or the file
   is locked, online-only, not yet uploaded, or no longer there.
2. Pick the target name. Compare names ignoring capital letters (T01 Q6). On
   a clash, number the new arrival Finder-style: `report 2.pdf`, `report 3.pdf`.
3. Write an "about to move" entry to the MoveLog and flush it to disk.
4. Create the target folder if needed, and log it as "made by Mojo".
5. Move with an exclusive rename (`renamex_np` with `RENAME_EXCL`), so an
   existing file can never be overwritten, even in a race. Same volume only;
   never copy-then-delete.
6. Add Mojo's label beside existing ones (T01 Q5). Log exactly what was added.
7. Log "done".

A crash between steps leaves a log the app checks on next launch, so it can
show what moved and what did not, and Undo still works.

## Undo and Put back

- Undo a run in reverse order. For each moved file: find it by file ID at its
  new place. If it is gone or was moved again, report it and do not guess.
  If its old place is now taken, report it and leave it.
- Remove only the label Mojo added.
- Remove a folder only if Mojo made it and it is empty (see decision 1).
- Clean up uses `trashItem` and logs the Trash location it returns (T01 Q3).
  Mojo's own Put back moves it back from there, because Finder's Put Back is
  missing for iCloud files (T01 Q4).
- Never empty the Trash. Never call a delete.

## Decisions needed with this approval (my suggestion in bold)

1. **Empty folder with only `.DS_Store`:** removing it means deleting that
   file. **Allow FileEngine to delete `.DS_Store` only, only inside a folder
   Mojo made, only during Undo**, and list it in AGENTS.md as the one exception.
   Otherwise the empty folder is left behind.
2. **Clash numbering:** **Finder style, `name 2.ext`**.
3. **Which duplicate is kept when all are ticked:** **the oldest copy**, and
   the screen says which.
4. **Markdown (`.md`):** **plain text, goes to Documents**. Other code types stay.
5. **Folder matching:** **same name, ignoring capitals** (`images` matches
   Images). `Pictures` or `Photos` do not.

## Tests written in T03 (they fail until T07 to T11 build the code)

Each test makes a fresh sample folder with scripts/make-sample-folder.sh in a
temporary folder, never a real one. One test per row of the spec's "Test
before release" table that MojoCore can check, plus: Plan hash mismatch is
refused, `renamex_np` never overwrites, log survives a simulated crash
between steps 3 and 5, online-only and not-uploaded files stay.
