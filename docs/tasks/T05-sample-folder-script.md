Task: T05, sample folder script
Level: Light (trap list checked by Smart)
Status: built; sample folder verified on Ben's Mac 2026-11-27

Goal: a script that builds a fresh messy test folder full of traps, so every
later card can be tested without touching real user folders.

Read: docs/spec.md (Sorting rules, What always stays, Technical issues,
Test before release), docs/decisions.md

May change:
- scripts/make-sample-folder.sh
- docs/handoff.md

Must not change: anything else

Rules for the script:
- Takes one argument: a parent folder. Creates a new `MojoSample-<time>`
  folder inside it and writes only there. Refuses if that folder exists.
- Refuses to run if the parent is Desktop, Documents, Downloads, iCloud Drive
  root or the home folder itself.
- Never deletes, never overwrites. No network.
- Writes a `MANIFEST.txt` listing every file and what Mojo should do with it.

Traps (each one matches a spec rule or a T01 finding):
- One of each sortable type: pdf, docx, xlsx, pptx, pages, numbers, key, txt,
  jpg, png, heic, mp4, mov, mp3, m4a, wav, dmg, pkg, zip
- `Report.pdf` and an existing `Documents/report.pdf` (case clash)
- `report.pdf` already inside an existing `Documents/` folder (name clash)
- An existing `Images/` folder with files inside (must not be rearranged)
- A file with an existing Finder tag (Red)
- A locked file (`chflags uchg`)
- Unfinished downloads: `.crdownload`, `.download`, `.part`
- A loose `.swift` and a loose `.py` file (code stays)
- Unknown type (`.xyz`), a hidden file (`.secret`), an alias and a symlink
  pointing outside the sample folder
- A Pages-style package folder (`Essay.pages/` with contents)
- A subfolder containing `Package.swift`, and a subfolder containing `.git/`
- A second sample with a top-level `package.json` (whole folder must stay)
- Two identical files with different names (duplicate) and two same-size
  files with different contents (not a duplicate)
- A large file (sparse, size set by flag) for Clean up tests
- Optional `--many N` to create N extra files for the large-folder test

Not covered by the script (needs a real location, as T01 showed):
iCloud online-only files, external drives, Trash without support.

Done when: Smart has checked the trap list against the spec, and the script
runs twice on Ben's Mac into a scratch parent folder with matching manifests.

After: add three lines to docs/handoff.md
