# Spec review: gaps and contradictions (2026-11-27)

Review of docs/spec.md and the build plan before any code is written.
Items marked **Blocks** stop a card from starting until Ben decides.

## Contradictions

1. **Safety tools are built after the cards that need them.** AGENTS.md says
   every card must test only on sample-script folders and must pass the safety
   check in scripts/. But the sample folder script is T05 and the safety check
   is T06, both after T01 and T03. **Blocks T01 and T03.**
   Suggestion: build T05 and T06 first (they are Light and small), or state
   that they are exempt until they exist.

2. **T01 cannot run on a sample folder alone.** T01 must test iCloud Desktop
   and Documents, online-only files, the Trash and Finder Put Back. A script
   cannot fake an iCloud-synced or evicted file, and Trash behaviour depends on
   the real volume. **Blocks T01.**
   Suggestion: the probe creates its own `MojoProbe-<date>` folder inside a
   location Ben picks (including one inside iCloud Drive), creates its own
   test files there, and only ever acts on files it made. Ben runs it by hand.

3. **Undo vs never permanently delete.** Undo removes an empty folder Mojo made
   and says `.DS_Store` "does not count". Removing such a folder means
   permanently deleting the `.DS_Store` file. Suggestion: allow FileEngine to
   delete only a `.DS_Store` file, only inside a folder Mojo created, only
   during undo, and list it as the one exception in AGENTS.md. Or move the
   folder to the Trash instead of removing it.

4. **"Only cleanup sends files to the Trash" vs undo.** If undo trashes an
   empty folder (option above), that is a second Trash path. Decide which.

5. **Project rule wording.** "If a chosen folder contains `.git` or
   `package.json`, nothing in it moves." If Desktop itself has a stray
   `package.json`, the whole Desktop is skipped. The test "Desktop holds a
   Swift project folder" is about a subfolder, which is already safe because
   existing folders never move. Confirm the rule means the chosen folder's own
   top level, and that the plan says why a folder was skipped.

## Gaps

6. **Labels.** The table gives each folder a colour, and "existing labels are
   kept". Finder allows several tags, so: does Mojo add its tag beside an
   existing one, or skip labelling that file? Is the label on the file, the
   folder, or both? Undo must remove only the tag Mojo added.

7. **Folder name clashes.** Sorting Documents creates `Documents/Documents`.
   Sorting Downloads with an existing `images` folder: does "matching" ignore
   capital letters? Does `Pictures` or `Photos` count as matching Images?
   Suggestion: exact name, ignoring case, only.

8. **Numbering format.** "A file with a clashing name gets a number." Suggest
   Finder's style: `report 2.pdf`, `report 3.pdf`.

9. **Missing common types.** GIF, WebP, TIFF, RAW, SVG, MKV/AVI, AAC/FLAC, CSV,
   RTF and Markdown are not listed, so they would stay as unknown. Confirm that
   is intended, or extend the table. Is Markdown plain text or code?

10. **Which duplicate is kept.** "One copy is always kept" but not which one
    when the user ticks all. Suggest: the oldest, or the one outside Downloads,
    and the screen says which.

11. **Undo for Clean up.** History lists "every move". Does it include files
    sent to the Trash, and does Put back work on them? T01 must answer whether
    the app can reach the Trash at all when sandboxed.

12. **Distribution.** App Store (sandboxed) or direct download (notarised)
    changes folder access (T09), Trash access and the Downloads permission.
    Needs deciding after T01.

13. **Subfolders.** "Camera type" is vague: camera make, model, or
    phone vs camera? And what happens to an image that has a date but the user
    picked camera grouping and it has no camera info?

14. **Clean-up limits** (already listed as open): installer age and large
    file size. **Blocks T16.**

15. **Cloud folders** (already listed as open). Decided after T01.

16. **Plan expiry.** "Check each file again just before moving" is clear, but
    how long can a plan sit before Mojo rescans? Suggest: rescan if older than
    a few minutes, or always re-check each file (already required).

## Environment notes

- No Mojo repository exists on GitHub yet, so there is nowhere to open a PR.
- Swift does not run in the cloud or in the Linux workspace. `swift test`
  must run on Ben's Mac (via Remote Control) or in GitHub Actions on a macOS
  runner.
