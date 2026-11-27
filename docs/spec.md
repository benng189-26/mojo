# Mojo: rules spec for version 1

Exported from the Claude Doc "Moji: rules spec for version 1" on 2026-11-27
(https://claude.ai/artifact/WciRbhnM7bJdXA77dZvy87). The doc is the source of
truth; update this copy whenever the rules change. Wireframes live in the doc
and in the clickable wireframe: https://claude.ai/artifact/8y2rFwzh7gWpfGsWjWFBoQ

## Purpose

Mojo (project code) sorts loose files on a Mac by type and suggests junk files
to help free storage. It shows the plan first and changes nothing without
permission. It is for students and office workers who want to clean up after a
busy period.

Its two main functions are **Sort** and **Clean up**. It should be fun but not
childish. The sorting, moving, undo and clean-up rules are agreed for version 1.
The wireframes, animation ideas and technical handling are proposals to test,
and open decisions are under Still open.

## Sorting rules

Mojo sorts only loose files at the top level of the folders the user chooses.
Version 1 offers Desktop, Downloads, Documents and folders the user adds.

| New folder | File types | Label colour |
|---|---|---|
| Documents | PDF, Word, Excel, PowerPoint, Pages, Numbers, Keynote, plain text | Blue |
| Images | JPG, PNG, HEIC | Green |
| Videos | MP4, MOV | Orange |
| Audio | MP3, M4A, WAV | Purple |
| Installers | DMG, PKG | Grey |
| ZIP files | ZIP | Yellow |

### What always stays

- System files, apps and hidden files.
- Project files. If a chosen folder contains `.xcodeproj`, `.xcworkspace`,
  `Package.swift`, `.git` or `package.json`, nothing in it moves.
- Existing folders, which Mojo never moves or rearranges, though it may add
  files to a matching one after approval. This also protects projects it does
  not recognise.
- Libraries such as the Photos library.
- Loose code files, unfinished downloads and unknown types.

## Moving, undo and clean-up rules

### Moving files

- New folders are made inside the folder being sorted. If a matching folder is
  already there, files go into it.
- No file is overwritten or permanently deleted. Only cleanup sends files to
  the Trash, after confirmation. A file with a clashing name gets a number.
- Folders and labels are created automatically, but only after approval.
  Existing labels are kept.
- The animation makes at most five trips. Extra files travel in groups, and it
  can be switched off.
- Optional subfolders, shown in the plan, group images by year and month taken,
  or by camera type. An image without that information stays in the main
  Images folder.
- A searchable history lists every move, with Show in Finder and Put back.
- The wand is the default look. Users can choose a fairy or an elderly wizard
  instead, both original designs. They appear only during a tidy and never
  interrupt. Version 1 includes the wand and fairy, and the wizard follows.

### Undo

- Mojo asks for confirmation first, then returns files to their old places with
  their old labels.
- It removes only folders it created, and only if they are empty. Finder's
  hidden `.DS_Store` file does not count.
- A folder with anything new inside stays. A file the user has since moved is
  reported, not guessed.

### Clean up storage

Mojo suggests old installers, exact duplicates and large files, each with its
size and the reason.

- It looks at loose files in the chosen folders and in folders it created.
  Anything under What always stays is left out.
- Nothing is ticked in advance. Ticked files move to the Trash only after
  confirmation.
- It never empties the Trash, so space is freed only when the user does. Until
  then, files can be dragged back.
- At least one copy of every duplicate is always kept.
- The last opened date alone is not reliable enough to judge junk.

## Animation and fun

The fun comes from watching a mess turn into order, and from feeling safe while
it happens.

### Animation rules

- The whole wave should feel short. The first target to test is about three
  seconds.
- Skip, or the Escape key, jumps straight to the summary.
- The animation only shows the work. Files move and are logged whether or not
  it plays, and counts and errors are real.
- When macOS Reduce Motion is on, nothing flies. Folders fade in with a tick
  and a count.
- Sound is off by default.
- In Clean up, ticked files drift into the Trash, and the bar says ready to free
  until the user empties it.

### Making it fun, not childish

Version 1:
- A before and after count, such as 86 loose files down to 3 that need you.
- A calm summary card with each folder and its count.
- The wand or fairy reacts briefly at the end, with one plain line of text.
- No streaks, scores, nagging reminders or alarming warnings.

Ideas to test later: a soft chime and light trackpad tap; a rare second
flourish; a shareable summary picture with counts only and no file names.

## Build notes

- Sorting by type needs no AI. macOS can identify common file types, so it
  should work without Apple Intelligence.
- Check for source code before plain text, because code files are also text.
- Treat document packages, such as some Pages files, as files rather than
  folders.
- A Mac App Store build needs the user to select folders such as Desktop. There
  is a Downloads permission but none for Desktop.
- Save the move log before moving, so undo works after a restart or crash.
- Request no network permission. Apple's on-device AI can come later for names
  and for grouping documents by topic.
- Read the date taken and camera type from the information inside each image
  file, with no online lookup.
- Find exact duplicates by comparing file contents, not names.

## Technical issues

One rule covers them all: when Mojo is unsure, the file stays where it is and
the user is told why.

### While sorting

| Issue | What could go wrong | How Mojo handles it |
|---|---|---|
| Apps that link to files | A video project can report a moved file as missing. | Warn on the first run, let the user untick files, and offer Put back. |
| Files in use or unfinished | A move could disturb work being saved. | Skip them and list them. |
| Changes after the plan | A file is renamed, edited or removed before it moves. | Check each file again just before moving it, and skip any that changed. |
| Quit, crash or unplugged drive | A tidy stops halfway. | Log each move before making it, then show what moved and what did not. |
| Same name | On a standard Mac disk, `Report.pdf` and `report.pdf` count as one name. | Ignore capital letters when checking, and number the new arrival. |
| Locked, read-only or shared files | The move fails or affects other people. | Leave them and say why. |
| Aliases and links | Following one could reach outside the chosen folder. | Never follow them. Leave them in place. |
| Very large folders | The app seems frozen. | Scan in the background, with progress and Cancel. |

### While cleaning up

| Issue | What could go wrong | How Mojo handles it |
|---|---|---|
| No Trash on a drive | Some drives may not support the Trash. | Leave the file and explain. Never delete it directly. |
| Getting files back | Finder's Put Back may not always appear, and the app's access to the Trash may be limited. | History shows the old place. Test this early. |
| Space freed | Duplicates can share the same storage, and Time Machine snapshots can hold deleted files for a while. | Say "up to" and never promise an exact amount. |
| Slow duplicate checks | Comparing large files takes time and battery. | Compare sizes first, then contents, only during Clean up. |

### Mac, cloud and access

| Issue | What could go wrong | How Mojo handles it |
|---|---|---|
| iCloud Desktop and Documents | These folders stay in step across devices, so a move shows up everywhere. | Say so in the plan and ask first. |
| Files stored online only | With Optimise Mac Storage, older documents may be only in iCloud. | Leave them in place, and do not download them to inspect them. Treat other cloud services the same way. |
| Folder access | A folder is renamed, or access is removed. | Ask the user to choose the folder again. |
| Macs without Apple Intelligence | Apple's on-device models need a supported device. | Sorting and Clean up work without AI. |
| History privacy | The history holds file names. | Keep it on the Mac. Before clearing it, warn that Put back will be lost. |
| Accessibility | Motion, or colour used alone, can shut people out. | Support Reduce Motion, VoiceOver and the keyboard. Show label names as well as colours. |

## Test before release

| Test | Expected result |
|---|---|
| Desktop holds a Swift project folder | The folder is unchanged |
| The chosen folder contains `.git` | Nothing in it moves |
| A loose `.swift` file | It stays |
| A Pages document | It goes to Documents |
| An unfinished download | It stays |
| Two files named `report.pdf` meet | Both are kept, one gets a number |
| A file already has a label | The label is kept, and undo restores the original state |
| User adds a file to a new folder, then undoes | That folder and the new file stay |
| The app quits halfway through | Undo still restores moved files |
| Nothing is ticked | The wand button is off |
| An Images folder already exists | Files are added and nothing inside is rearranged |
| A ticked junk file is confirmed | It moves to the Trash, which is not emptied |
| Every copy of a duplicate is ticked | One copy is still kept |
| A ZIP file is sorted | It moves to ZIP files and stays unopened |
| Image subfolders are on and a photo has no date | It stays in the main Images folder |
| User searches the history for a moved file | Show in Finder opens its new place |
| A file is stored only in iCloud | It stays and is not downloaded |
| A file changes after the plan is shown | It is skipped and listed |
| Two names differ only in capital letters | Both are kept, one gets a number |
| A drive does not support the Trash | The file stays and Mojo explains why |
| An external drive is unplugged during a tidy | Mojo shows what moved and what did not |
| Reduce Motion is on, or Skip is pressed | The summary appears with the real result |
| The Mac has no Apple Intelligence | Sorting and Clean up still work |

## Later versions

- The elderly wizard.
- Unzipping, chosen for each file, with the original ZIP kept.
- Place names for photos.
- Grouping documents by topic with on-device AI.
- A report on the rest of the home folder, without moving anything.

## Still open

- **Name:** Mojo is a temporary project code. The final name will be considered
  when the app is done, with a trademark check.
- **Clean-up limits:** how old an installer must be, and how large a file must
  be, before Mojo suggests it.
- **Cloud folders:** whether version 1 sorts folders synced with iCloud or other
  services after asking (suggested), or leaves them alone.
