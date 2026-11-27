Task: T04, Xcode project, folder layout and AGENTS.md
Level: Standard
Status: done 2026-11-27. Builds on Ben's Mac; entitlements are sandbox + user-selected read-write only

Goal: an empty Mojo app that opens a window, uses MojoCore, runs in the
App Sandbox and has no network permission. No features yet.

Read: AGENTS.md, docs/design.md, docs/decisions.md (T01 Q8)

May change:
- Mojo/** (new: Xcode project, app sources, entitlements)
- .gitignore
- AGENTS.md (layout and build commands only; Safety rules unchanged)
- docs/handoff.md, this card

Must not change: MojoCore/, scripts/, Probe/

Rules:
- Entitlements: App Sandbox on, user-selected files read/write. No
  network.client, no network.server, no other entitlements.
- The app links MojoCore as a local package (../MojoCore).
- The window only shows text and the list of folders Mojo sorts into. It
  reads no folder and changes no file.
- Signed to run locally ("-"); no team needed until T23.

Done when (on Ben's Mac):
- `xcodebuild -project Mojo/Mojo.xcodeproj -scheme Mojo -configuration Debug -derivedDataPath /tmp/MojoBuild build` succeeds
- `open /tmp/MojoBuild/Build/Products/Debug/Mojo.app` shows the Mojo window
- `codesign -d --entitlements - /tmp/MojoBuild/Build/Products/Debug/Mojo.app`
  shows app-sandbox and user-selected read-write, and no network key
- `swift test --package-path MojoCore` still builds (4 pass, 24 notImplemented)
- `bash scripts/safety-check.sh` passes

After: add three lines to docs/handoff.md
