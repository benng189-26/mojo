Task: T03, core design, interfaces and safety tests
Level: Smart
Status: done 2026-11-27. Builds clean; 4 tests pass, 24 fail with notImplemented as expected

Goal: agree how MojoCore is split and how FileEngine changes files safely,
then write the interfaces and the safety tests that later cards must pass.

Read: AGENTS.md, docs/spec.md, docs/decisions.md, docs/design.md

May change:
- docs/design.md
- MojoCore/Package.swift
- MojoCore/Sources/MojoCore/** (types and protocols only, no file changes;
  FileEngine methods are stubs that throw `notImplemented`)
- MojoCore/Tests/MojoCoreTests/**
- AGENTS.md (only if Ben approves design decision 1)
- docs/handoff.md

Must not change: scripts/, Probe/

Done when:
- Ben approves docs/design.md and its five decisions
- `swift test --package-path MojoCore` builds, and the new safety tests fail
  with `notImplemented` (not with crashes or build errors)
- `bash scripts/safety-check.sh` passes

After: add three lines to docs/handoff.md
