Task: T11, Undo and Put back
Level: Smart
Status: card written 2026-11-28, waiting for Ben's approval. No code yet.

Goal: undo a whole tidy, or put back one moved file, using the move log.
Files go back to their old places with their old labels, Mojo's own empty
folders are removed, and anything that changed since is reported, never
guessed (spec: Undo; design: Undo and Put back).

Read: AGENTS.md, docs/spec.md (Undo), docs/design.md (Undo and Put back,
decision 1), T10 card and code (MoveLog, FileEngine.apply)

May change:
- MojoCore/Sources/MojoCore/FileEngine/** (undo, putBack)
- MojoCore/Sources/MojoCore/Model/** (small additions, e.g. log kinds,
  stay reasons for undo such as "moved since" or "old place taken")
- MojoCore/Tests/MojoCoreTests/UndoTests.swift (new)
- MojoCore/Tests/MojoCoreTests/SampleFolder.swift (helpers, with allow tags)
- docs/handoff.md, this card

Must not change: SafetyTests.swift, scripts/, the app, entitlements

How it works:
- Undo reads the run's log and works in reverse order. Only files the log
  says were moved (or were about to move, after a crash) are touched.
- For each file: look at its new place. It goes back only if the item there
  has the same file ID as the one Mojo moved. If it is gone or has been
  moved or renamed, it is reported as "moved since" and left alone.
- It goes back to its exact old name with the same exclusive rename as T10.
  If something now has that name (ignoring capitals), it is reported as
  "old place taken" and left where it is. Nothing is ever overwritten.
- Labels: only the tag entry Mojo added is removed. Tags the user added or
  removed since are left as they are.
- Folders: a folder is removed only if this run's log says Mojo made it and
  it is now empty. If the only thing in it is `.DS_Store`, that file is
  deleted and then the folder removed (the one exception Ben approved
  2026-11-27). A folder with anything else in it stays.
- Each step is logged before it happens, like T10, and the run gets an
  "undone" line, so undoing twice does nothing the second time and an
  undone run is no longer listed as interrupted.
- Put back: the same steps for one logged move, picked by its log entry.
  Putting back a trashed file is T16.
- Confirmation: the app asks "Undo this tidy?" before calling undo (T12).
  MojoCore keeps the undo(runID:) call the T03 safety tests already use.

Decisions for Ben (my suggestion in bold):
1. A file edited since the tidy but still in Mojo's folder (same file ID,
   newer date). **Put it back anyway**: it is still the user's file in
   Mojo's folder, and leaving it would be more surprising.
2. Part of a run cannot be undone (one file was moved since). **Undo the
   rest, and list the ones left with the reason.**
3. A Mojo folder that the user has renamed since. **Treat it as the user's
   folder: leave it and its files, and report them.**

Done when:
- New UndoTests pass, including: undo restores every file and label, a file
  moved since is reported and not guessed, an old place that is now taken
  is not overwritten, a folder with a new file stays, a folder holding only
  .DS_Store is removed, undo after a crash halfway works, undoing twice
  changes nothing, put back returns one file
- The four undo SafetyTests pass. Only the history one still fails (T18)
- `swift test --package-path MojoCore` builds and the safety check passes
- Every test uses a folder made by the sample script, never a real one

After: add three lines to docs/handoff.md
