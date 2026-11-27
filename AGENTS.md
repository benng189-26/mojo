# Mojo
Mac app that sorts loose files and suggests clean-up. Rules: docs/spec.md

## Safety
- Only MojoCore FileEngine may move, rename, label, trash or remove
  files, or create or remove folders.
- Nothing changes without the user's approval.
- Never overwrite or permanently delete a file. Never empty the Trash.
  One exception (approved 2026-11-27): during Undo, FileEngine may delete
  `.DS_Store` inside a folder Mojo made, only to remove that empty folder.
- When unsure, leave the file where it is and say why.
- Test only on folders made by the sample folder script.
  Never use real user folders.
- Never weaken or skip a safety test. Stop and ask.
- No network access in the app.

## Work
- Do one card from docs/tasks at a time.
- Change only the files the card lists.
- Before finishing: swift test --package-path MojoCore
  and run the safety check in scripts/
- After two failed attempts, stop and write in docs/handoff.md
