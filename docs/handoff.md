# Handoff

## 2026-11-27, set-up
- Done: AGENTS.md, docs/spec.md export, docs/spec-review.md, T01 card draft.
- Not done: no code yet. T01 waits for Ben's approval of its safety exception.
- Blocked: no GitHub repo for Mojo; swift test can only run on Ben's Mac or a macOS CI runner.

## 2026-11-27, T01 probe
- Done: reviewed the probe against the T01 card; --check now reads only files inside a MojoProbe-* folder; added a locked-file test (locks, reads back, unlocks), an evict-me.txt file for the iCloud online-only test, iCloud upload status and Trash error codes. Builds with no errors or warnings.
- Not done: the probe has not been run. Ben runs it by hand on each location; findings then go in docs/decisions.md. Q8 (sandboxed build) is a later second run.
- Note: no MojoCore or scripts/ yet, so swift test and the safety check could not run (spec-review item 1).

## 2026-11-27, T01 run (stopped after two attempts)
- Done: probe built cleanly on Ben's Mac (swift build, 0 errors, 0 warnings).
- Failed twice: running the probe via Remote Control was blocked by the Mac's Claude Code permission check (piped "y" answers skip the probe's own confirmation prompts). Nothing ran, nothing changed.
- Next: Ben runs the two probe commands by hand and pastes the output; then findings go in decisions.md. No GitHub repo yet; T06 safety check not built yet.

## 2026-11-27, T01 findings
- Done: Ben ran the probe on the internal disk and in iCloud Drive. Q1, Q3, Q4, Q5, Q6, Q7 answered in decisions.md. Ben chose: sort synced folders after asking.
- Not done: Q2 --check on the online-only iCloud files (Spotlight shows they stay online-only when read); Q8 sandboxed build moved to T09.
- Next: T03 core design, after Ben decides spec-review item 1 (build T05/T06 first or not). Still no GitHub repo.

## 2026-11-27, T05 and T06 (Ben chose safety tools before T03)
- Done: scripts/make-sample-folder.sh (traps + manifest next to the sample, refuses real user folders, never overwrites) and scripts/safety-check.sh (+ --self-test fixtures). Both tested on Linux: self-test catches all 7 planted lines; FileEngine folder is exempt; allow tags are listed.
- Not tested: macOS-only parts of T05 (Red tag via xattr/plutil, chflags lock). Needs one run on Ben's Mac. swift test still can't run: no MojoCore yet (T03).
- Known strictness: safety-check also flags a call name inside a string literal; use an allow tag if that ever matters.

## 2026-11-27, T05/T06 Mac run
- Done: sample folder script ran on Ben's Mac (~/MojoTest/MojoSample-2026-11-27T22-39-31Z). Safety check self-test on the Mac caught only 6 of 7: BSD grep ignores ^/$ inside a group, so a match at the very end of a line (`import Network`) was missed. Fixed: lines are padded with spaces and word edges are one non-word character; self-test now requires an exact count (7) and fails if any planted line is missed.
- Done: fixed self-test re-run on the Mac caught 7 of 7. T05 and T06 complete.

## 2026-11-27, T03 core design
- Done: docs/design.md approved with 5 decisions (in decisions.md); AGENTS.md lists the .DS_Store exception. MojoCore package: models, Approval with plan hash, stubs for Rules, FolderScanner, Planner, FileEngine, History; 28 tests.
- Results on Ben's Mac: build 0 errors 0 warnings; swift test ran 28: 4 pass (approval checks), 24 fail with notImplemented (38 assertion failures), no crashes. safety-check passes (4 allowed lines in the test helper).
- Next: T04 (app project, no network permission), then T07 rules. Still no GitHub repo.

## 2026-11-27, T04 app project
- Done: GitHub repo benng189-26/mojo with the work so far on main. Mojo/Mojo.xcodeproj (written by hand, not yet opened in Xcode): SwiftUI window listing MojoCore's folders, App Sandbox, user-selected files read/write, no network entitlements, signed to run locally. AGENTS.md gains Layout and Build.
- Checked here: safety check passes; project file references all resolve. Swift and Xcode can't run in the cloud, so nothing is built yet.
- Next: Ben runs the T04 Done-when commands on the Mac; if the project won't open, fix it (two tries) before T07.
- Mac run 2026-11-27: xcodebuild built Mojo.app; it opens. codesign shows app-sandbox, user-selected read-write and get-task-allow (Debug builds only, for the debugger), no network key. T04 done (Ben saw the window); next T07.

## 2026-11-27, T07 sorting rules
- Done: Rules.classify and isProjectFolder written as pure tables in a fixed order (see the card). RulesTests grows from 7 to 15, covering packages (Pages, pkg, app, library, xcodeproj), Safari downloads, links, locked, capitals.
- Checked here: safety check passes. Swift can't run in the cloud, so not yet compiled.
- Next: Ben runs the RulesTests on the Mac, then T08 scanner.
- Mac run 2026-11-27: RulesTests 15 of 15 pass. T07 done; next T08 scanner.

## 2026-11-27, T08 scanner
- Done: FolderScanner reads the top level only (hidden included, links not followed, lstat file numbers), iCloud state from resource values, Cancel checked per item. New ScannerTests (9) on sample folders, including a 2000-file Cancel test. Rules: iWork folders sort even if not marked as packages; RulesTests 16.
- Checked here: safety check passes. Not yet compiled (no Swift in the cloud).
- Next: Ben runs ScannerTests and RulesTests on the Mac. Then the Planner, which T10 needs.
- Mac run 1 (2026-11-28): 24 of 25 pass. ScannerTests.testTagsAreRead fails: tags read as [] on tagged.pdf. Unknown yet whether the sample script's xattr didn't stick or the scanner misses it; asked Ben for xattr -l / mdls on a fresh sample. Attempt 1 of 2.
- Diagnosis: xattr -l shows the Red tag on tagged.pdf, so the script is fine and the tagNames resource value is what came back empty. Attempt 2: the scanner falls back to reading com.apple.metadata:_kMDItemUserTags with getxattr (read only). Note for T10: SampleFolder.tags() uses tagNames too and may need the same fallback.
