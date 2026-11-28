Task: T10, FileEngine moves, labels, name clashes, move log
Level: Smart
Status: approved by Ben 2026-11-28 as written; built, waiting for a run on Ben's Mac

Goal: turn an approved plan into real moves on a sample folder, safely.
Mojo builds the plan (Planner), and FileEngine carries it out one file at a
time, logging each step first, never overwriting, and skipping anything that
changed or is busy. Undo is T11, so this card stops at "moved and logged".

Read: AGENTS.md, docs/spec.md (Moving files, Technical issues, Test before
release), docs/design.md (How a move works), docs/decisions.md (T01 Q5, Q6)

May change:
- MojoCore/Sources/MojoCore/Planner/Planner.swift (build the plan)
- MojoCore/Sources/MojoCore/FileEngine/** (apply, move log, interruptedRuns)
- MojoCore/Sources/MojoCore/Model/** (small additions only, e.g. a label
  field on PlannedMove, new MojoError cases)
- MojoCore/Tests/MojoCoreTests/PlannerTests.swift, FileEngineTests.swift (new)
- MojoCore/Tests/MojoCoreTests/SampleFolder.swift (helpers to change a file
  after the plan, sample folders only, with allow tags)
- scripts/make-sample-folder.sh (date the sample a day back and add one
  just-saved file; approved by Ben 2026-11-28)
- docs/handoff.md, docs/decisions.md, this card

Must not change: SafetyTests.swift, scripts/safety-check.sh, the app, entitlements

How it works:
- Planner: each scanned item goes through Rules. A category becomes a
  PlannedMove into its folder. An existing folder with the same name,
  ignoring capitals, is used as is. If the chosen folder is a project
  (.git, Package.swift, package.json, .xcodeproj, .xcworkspace), nothing
  moves and everything stays with that reason. Warnings: synced folder,
  first run. Building a plan changes nothing.
- FileEngine.apply, for each move in order:
  1. Read the file again. Skip and list it if its fingerprint changed, it is
     gone, locked, online-only, not uploaded, or busy (see decision 1).
  2. Pick the target name, ignoring capitals. On a clash, number the new
     arrival: "report 2.pdf", "report 3.pdf".
  3. Write "about to move" to the log and flush it to disk.
  4. Make the target folder if needed and log it as made by Mojo.
  5. Move with renamex_np(RENAME_EXCL): an existing file is never
     overwritten, even in a race. Same disk only, never copy and delete.
  6. Add Mojo's label beside existing labels. Log exactly what was added.
  7. Log "moved".
- The log is one JSON line per entry in a file per run, in the app's own
  folder (tests use a folder inside the sample). Nothing is written to the
  user's folders except the moved files and new folders.
- interruptedRuns: a run with "about to move" but no "moved" for some file is
  reported on next launch, with which file was in progress.
- If anything is unclear for a file, it stays and the reason is listed.

Decisions for Ben (my suggestion in bold):
1. Busy files. A sandboxed app cannot ask which app has a file open.
   **Treat a file changed in the last 2 minutes as busy and leave it.**
2. The label. Finder's colour labels have names in the Mac's language.
   **Add the colour by Finder's standard colour name (e.g. Blue), which
   Finder shows in the user's language.** Undo removes only that one.
3. A file that is still in the log as "about to move" after a crash:
   **check where it really is by its file ID and report it; never move it
   again automatically.**

Done when:
- New PlannerTests and FileEngineTests pass, including: exact and
  capital-only clashes keep both, a file changed after the plan is skipped,
  a changed plan is refused, existing labels are kept, a crash after N moves
  leaves a log that interruptedRuns finds, renamex_np never overwrites
- The SafetyTests for staying, sorting, clashes and approval pass. The undo
  and history ones still fail until T11 and T18; that is expected
- `swift test --package-path MojoCore` builds and the safety check passes
- Every test uses a folder made by the sample script, never a real one

After: add three lines to docs/handoff.md
