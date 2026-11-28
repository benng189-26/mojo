#!/usr/bin/env bash
# T05: build a fresh messy sample folder full of traps for testing Mojo.
#
# Safety:
# - Creates ONE new folder, MojoSample-<time>, inside the parent you give,
#   and writes only inside it. Refuses if it already exists.
# - Refuses real user folders as the parent (home, Desktop, Documents,
#   Downloads, iCloud Drive root).
# - Never deletes, never overwrites. No network.
#
# Usage: scripts/make-sample-folder.sh <parent-folder> [--many N] [--large-mb N]

set -euo pipefail

usage() { echo "usage: $0 <parent-folder> [--many N] [--large-mb N]" >&2; exit 2; }

[[ $# -ge 1 ]] || usage
parent="$1"; shift
many=0
large_mb=200
while [[ $# -gt 0 ]]; do
  case "$1" in
    --many) many="${2:?}"; shift 2 ;;
    --large-mb) large_mb="${2:?}"; shift 2 ;;
    *) usage ;;
  esac
done
[[ "$many" =~ ^[0-9]+$ && "$large_mb" =~ ^[0-9]+$ ]] || usage

[[ -d "$parent" ]] || { echo "error: parent is not an existing folder: $parent" >&2; exit 1; }
parent="$(cd "$parent" && pwd -P)"

# Refuse real user folders as the parent.
home="$(cd "$HOME" && pwd -P)"
for bad in "$home" "$home/Desktop" "$home/Documents" "$home/Downloads" \
           "$home/Library/Mobile Documents/com~apple~CloudDocs" "/"; do
  if [[ "$parent" == "$bad" ]]; then
    echo "error: refusing to use a real user folder as the parent: $parent" >&2
    echo "Make a scratch folder first, for example: mkdir -p ~/MojoTest" >&2
    exit 1
  fi
done

stamp="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
root="$parent/MojoSample-$stamp"
[[ ! -e "$root" ]] || { echo "error: $root already exists" >&2; exit 1; }
mkdir "$root"
# The manifest sits next to the sample, not inside it, so Mojo never sorts it.
manifest="$root.manifest.txt"
[[ ! -e "$manifest" ]] || { echo "error: $manifest already exists" >&2; exit 1; }

# All writes go through these helpers, which refuse paths outside $root and
# refuse to overwrite.
inside() { case "$1" in "$root"/*) return 0 ;; *) return 1 ;; esac; }

mk() { # mk <relative path> <content> <expected outcome>
  local p="$root/$1"
  inside "$p" || { echo "error: refusing to write outside sample: $p" >&2; exit 1; }
  [[ ! -e "$p" && ! -L "$p" ]] || { echo "error: refusing to overwrite $p" >&2; exit 1; }
  mkdir -p "$(dirname "$p")"
  printf '%s' "$2" > "$p"
  note "$1" "$3"
}

mkdirp() { # mkdirp <relative dir> <expected outcome>
  local p="$root/$1"
  inside "$p" || exit 1
  mkdir -p "$p"
  note "$1/" "$2"
}

note() { printf '%-48s %s\n' "$1" "$2" >> "$manifest"; }

is_mac() { [[ "$(uname)" == "Darwin" ]]; }

{
  echo "Mojo sample folder, made $stamp"
  echo "Each line: path, then what Mojo must do with it."
  echo
} > "$manifest"

# --- 1. One of each sortable type (top level, loose) ---------------------
for ext in pdf docx xlsx pptx pages numbers key txt; do
  [[ "$ext" == pages ]] && continue   # Pages is a package, made below
  mk "sample.$ext" "sample $ext" "moves to Documents (Blue)"
done
for ext in jpg png heic; do mk "photo.$ext" "img $ext" "moves to Images (Green)"; done
for ext in mp4 mov; do mk "clip.$ext" "vid $ext" "moves to Videos (Orange)"; done
for ext in mp3 m4a wav; do mk "song.$ext" "aud $ext" "moves to Audio (Purple)"; done
for ext in dmg pkg; do mk "installer.$ext" "inst $ext" "moves to Installers (Grey)"; done
mk "archive.zip" "PK fake zip" "moves to ZIP files (Yellow), never opened"

# Document package: a folder that Finder treats as one file.
mkdir -p "$root/Essay.pages/Data"
printf 'pages index' > "$root/Essay.pages/Index.zip"
printf 'preview' > "$root/Essay.pages/Data/preview.jpg"
note "Essay.pages" "package: moves to Documents as ONE file, contents untouched"

# --- 2. Name clashes ------------------------------------------------------
mkdirp "Documents" "existing folder: files are added, nothing inside moves"
mk "Documents/report.pdf" "old report" "stays exactly as it is"
mk "Documents/invoice.pdf" "old invoice" "stays exactly as it is"
mk "invoice.pdf" "new invoice" "moves to Documents as 'invoice 2.pdf' (exact name clash)"
mk "Report.pdf" "new report" "moves to Documents with a number (clashes with report.pdf, case only)"

mkdirp "Images" "existing folder: files are added, nothing inside moves"
mk "Images/old-holiday.jpg" "old" "stays exactly as it is"
mk "Images/nested/keep.png" "nested" "stays exactly as it is"

# --- 3. Labels and locks --------------------------------------------------
mk "tagged.pdf" "tagged" "moves to Documents; keeps Red label and gains Blue"
if is_mac; then
  tmp_plist="$(mktemp -t mojotag)"
  cat > "$tmp_plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><array><string>Red
6</string></array></plist>
PLIST
  hex="$(plutil -convert binary1 -o - "$tmp_plist" | xxd -p | tr -d '\n')"
  xattr -wx com.apple.metadata:_kMDItemUserTags "$hex" "$root/tagged.pdf"
  rm -f "$tmp_plist"   # our own temp file outside the sample, not a user file
else
  echo "(not macOS: tagged.pdf has no Red label)" >> "$manifest"
fi

mk "locked.pdf" "locked" "STAYS: locked file, Mojo says why (locked below)"

# --- 4. Things that always stay -------------------------------------------
mk "movie.mp4.crdownload" "partial" "STAYS: unfinished download"
mk "setup.dmg.download" "partial" "STAYS: unfinished download"
mk "data.zip.part" "partial" "STAYS: unfinished download"
mk "script.swift" "print(1)" "STAYS: loose code file"
mk "tool.py" "print(1)" "STAYS: loose code file"
mk "notes.md" "# notes" "OPEN QUESTION: Markdown, plain text or code? (spec-review 9)"
mk "mystery.xyz" "???" "STAYS: unknown type"
mk ".secret" "hidden" "STAYS: hidden file"
ln -s /etc/hosts "$root/link-outside"
note "link-outside" "STAYS: symlink, never followed (points outside sample)"
ln -s "photo.jpg" "$root/link-inside"
note "link-inside" "STAYS: symlink, never followed"
echo "(Finder aliases are not made by this script; test those by hand)" >> "$manifest"

mkdirp "MyApp" "existing folder: never moved or rearranged"
mk "MyApp/Package.swift" "// swift-tools-version:5.9" "stays (inside a project folder)"
mk "MyApp/main.swift" "print(1)" "stays"
mkdirp "website/.git" "existing folder with .git: never moved or rearranged"
mk "website/index.html" "<html>" "stays"

# A second chosen folder whose top level IS a project: nothing in it moves.
mk "ProjectRoot/package.json" "{}" "chosen-folder test: whole folder stays"
mk "ProjectRoot/loose.pdf" "pdf" "chosen-folder test: STAYS because package.json is here"

# --- 5. Clean up candidates -----------------------------------------------
mk "dup-a.pdf" "identical duplicate content" "Clean up: duplicate of dup-b.pdf"
mk "dup-b.pdf" "identical duplicate content" "Clean up: duplicate of dup-a.pdf; one copy always kept"
mk "same-size-1.pdf" "AAAAAAAAAAAAAAAAAAAAAAAAAAA" "NOT a duplicate (same size, different bytes)"
mk "same-size-2.pdf" "BBBBBBBBBBBBBBBBBBBBBBBBBBB" "NOT a duplicate (same size, different bytes)"
mk "old-installer.pkg" "old pkg" "Clean up: old installer (date set below)"
touch -t 202301010000 "$root/old-installer.pkg"
large="$root/big-video.mov"
dd if=/dev/zero of="$large" bs=1 count=0 seek=$((large_mb * 1024 * 1024)) 2>/dev/null
note "big-video.mov" "Clean up: large file (${large_mb} MB, sparse)"

# --- 6. Optional many files -----------------------------------------------
if (( many > 0 )); then
  for ((i = 1; i <= many; i++)); do printf 'x' > "$root/many-$i.txt"; done
  note "many-1.txt ... many-$many.txt" "$many loose files for the large-folder and Cancel test"
fi

# --- 7. Dates --------------------------------------------------------------
# Mojo leaves files changed in the last 2 minutes, as they may be in use
# (T10 decision 1). Date everything a day back, keep the old installer's
# 2023 date, then add one file that was "just saved".
if is_mac; then yesterday="$(date -v-1d +%Y%m%d%H%M)"; else yesterday="$(date -d '1 day ago' +%Y%m%d%H%M)"; fi
find "$root" ! -name "old-installer.pkg" -exec touch -h -t "$yesterday" {} +
mk "just-saved.docx" "busy" "STAYS: changed in the last 2 minutes, may be in use"

# Lock last: a locked file's date cannot be changed.
if is_mac; then chflags uchg "$root/locked.pdf"; else echo "(not macOS: locked.pdf is not locked)" >> "$manifest"; fi

echo "Made $root"
echo "Manifest: $manifest"
