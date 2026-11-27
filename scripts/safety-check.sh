#!/usr/bin/env bash
# T06: fail if code outside MojoCore's FileEngine can change files, or if the
# app can reach the network. Read only: this script never changes a file.
#
# Usage:
#   scripts/safety-check.sh              check MojoCore/ and Mojo/
#   scripts/safety-check.sh --self-test  must FAIL on the planted fixture
#
# Exceptions: a line may end with `// safety-check: allow <reason>`.
# Every allowed line is printed so a reviewer sees each one.

set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd -P)"
repo="$(cd "$here/.." && pwd -P)"
engine_dir="MojoCore/Sources/MojoCore/FileEngine/"

# File-changing calls (extended regex, matched per line).
file_patterns=(
  '\bmoveItem\b' '\bcopyItem\b' '\bremoveItem\b' '\btrashItem\b' '\breplaceItem(At)?\b'
  '\bcreateDirectory\b' '\bcreateFile\b' '\blinkItem\b' '\bcreateSymbolicLink\b'
  '\bsetAttributes\b' '\bsetResourceValues?\b' '\btagNames[[:space:]]*='
  '\.write[[:space:]]*\([[:space:]]*to(File)?:' '\bwrite\(toFile:' '\bwriteToURL\b'
  'FileHandle\([[:space:]]*forWriting' 'FileHandle\([[:space:]]*forUpdating'
  '\brename\(' '\brenameat\(' '\bunlink\(' '\bunlinkat\(' '\brmdir\(' '\bmkdir\('
  '\bchflags\(' '\bchmod\(' '\btruncate\(' '\bfopen\(' '\bopen\([^)]*O_(WRONLY|RDWR|CREAT)'
  '\bremove\([[:space:]]*"' '\bProcess\(' '\bNSTask\b' '\bposix_spawn'
  '\brecycle\(' '\bemptyTrash\b' '\bNSAppleScript\b' '\bOSAScript\b'
)
# Network use.
net_patterns=(
  '\bURLSession\b' '\bNSURLConnection\b' '\bNWConnection\b' '\bNWListener\b'
  '\bNWBrowser\b' '^[[:space:]]*import[[:space:]]+Network\b' '\bCFSocket' '\bURLSessionTask\b'
)
net_entitlements=(
  'com.apple.security.network.client'
  'com.apple.security.network.server'
)

# macOS grep has no reliable \b, and BSD grep ignores ^ and $ inside a group,
# so each \b becomes one non-word character and every line is padded with a
# space at both ends before matching (see pad below).
edge='[^A-Za-z0-9_]'
for i in "${!file_patterns[@]}"; do file_patterns[$i]="${file_patterns[$i]//\\b/$edge}"; done
for i in "${!net_patterns[@]}"; do net_patterns[$i]="${net_patterns[$i]//\\b/$edge}"; done

fail=0
report() { echo "FAIL  $1:$2  $3"; echo "      $4"; fail=1; }

check_swift() { # check_swift <file> <relative name> <in_engine 0|1>
  local f="$1" rel="$2" in_engine="$3" n=0 line code
  while IFS= read -r line || [[ -n "$line" ]]; do
    n=$((n + 1))
    # Strip a trailing // comment for matching, but keep it to read allow tags.
    code="${line%%//*}"
    local pad=" $code "
    [[ "$code" =~ ^[[:space:]]*$ ]] && continue
    local allowed=0
    [[ "$line" == *"// safety-check: allow "* ]] && allowed=1
    for p in "${net_patterns[@]}"; do
      if grep -Eq -- "$p" <<<"$pad"; then
        if (( allowed )); then echo "ALLOW $rel:$n  network: $line"
        else report "$rel" "$n" "network access is not allowed in the app" "$line"; fi
        continue 2
      fi
    done
    (( in_engine )) && continue
    for p in "${file_patterns[@]}"; do
      if grep -Eq -- "$p" <<<"$pad"; then
        if (( allowed )); then echo "ALLOW $rel:$n  file change: $line"
        else report "$rel" "$n" "file-changing call outside FileEngine" "$line"; fi
        continue 2
      fi
    done
  done < "$f"
}

check_entitlements() { # check_entitlements <file> <relative name>
  local f="$1" rel="$2" e
  for e in "${net_entitlements[@]}"; do
    if grep -Fq "$e" "$f"; then
      report "$rel" "-" "network entitlement must not be requested" "$e"
    fi
  done
}

scan() { # scan <root> <dir>...
  local root="$1"; shift
  local found=0 f rel
  while IFS= read -r -d '' f; do
    found=1
    rel="${f#"$root"/}"
    case "$f" in
      *.swift)
        if [[ "$rel" == "$engine_dir"* ]]; then check_swift "$f" "$rel" 1
        else check_swift "$f" "$rel" 0; fi ;;
      *.entitlements|*Info.plist) check_entitlements "$f" "$rel" ;;
    esac
  done < <(find "$@" \( -name .build -o -name .git -o -name DerivedData \) -prune -o \
             -type f \( -name '*.swift' -o -name '*.entitlements' -o -name 'Info.plist' \) -print0 2>/dev/null)
  return 0
}

if [[ "${1:-}" == "--self-test" ]]; then
  fixture="$here/safety-check-fixtures"
  [[ -d "$fixture" ]] || { echo "error: missing $fixture" >&2; exit 2; }
  expected=7   # planted.swift: 6 lines, planted.entitlements: 1
  out="$(scan "$fixture" "$fixture"; echo "fail=$fail")"
  echo "$out" | grep -v '^fail='
  caught="$(echo "$out" | grep -c '^FAIL ')"
  if [[ "$caught" -eq "$expected" ]]; then
    echo "SELF-TEST PASSED: all $expected planted lines were caught."
    exit 0
  fi
  echo "SELF-TEST FAILED: caught $caught of $expected planted lines." >&2
  exit 1
fi

dirs=()
for d in MojoCore Mojo; do [[ -d "$repo/$d" ]] && dirs+=("$repo/$d"); done
if (( ${#dirs[@]} == 0 )); then
  echo "safety-check: no MojoCore/ or Mojo/ yet, nothing to scan."
  exit 0
fi
scan "$repo" "${dirs[@]}"
if (( fail )); then
  echo "safety-check: FAILED"
  exit 1
fi
echo "safety-check: passed"
