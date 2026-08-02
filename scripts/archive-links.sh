#!/usr/bin/env bash
# Check URLs in markdown files and replace dead ones with Wayback Machine snapshots.
#
# Usage:
#   scripts/archive-links.sh [file ...]       # check specific files
#   scripts/archive-links.sh --all            # check all content markdown files
#   scripts/archive-links.sh --dry-run [...]  # report only, no rewrites
#
# The same external URL is often cited from more than one file (a source page
# and the post that cites it, say), and --all runs against every markdown file
# in content/. Checking it once per FILE rather than once per unique URL, and
# checking sequentially, meant a full --all run's wall-clock time grew with
# total citation count rather than unique URL count, and grew again every time
# a slow host was in the mix. Both are fixed here: every URL is checked at most
# once regardless of how many files cite it, and checks run PARALLEL_JOBS at a
# time (override with ARCHIVE_LINKS_PARALLEL) instead of one after another. A
# dead URL that resolves to a Wayback snapshot still gets rewritten in every
# file that cited it, not just the first.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DRY_RUN=false
FILES=()
ALL=false
PARALLEL_JOBS="${ARCHIVE_LINKS_PARALLEL:-8}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    --all) ALL=true; shift ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

if $ALL; then
  # Read without mapfile/readarray so this runs on bash 3.2 (stock macOS) too.
  FILES=()
  while IFS= read -r f; do FILES+=("$f"); done \
    < <(find "$REPO_ROOT/content" -name "*.md")
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Usage: $(basename "$0") [--dry-run] [--all | file ...]" >&2
  exit 1
fi

# Portable in-place sed (BSD/macOS and GNU/Linux differ on `sed -i`): edit
# through a temp file and write back into the original, which preserves its
# permissions and inode.
sed_inplace() {
  local script="$1" file="$2" tmp
  tmp=$(mktemp)
  sed "$script" "$file" > "$tmp" && cat "$tmp" > "$file"
  rm -f "$tmp"
}

# Check if a URL is live. Returns 0 if alive, 1 if dead.
# 403/429 = bot-blocked but server exists → treat as live
# 404/410/000 = genuinely dead
check_url() {
  local url="$1"
  local code
  # curl's own -w already prints "000" on a connection-level failure (DNS,
  # refused, timeout) even though it also exits non-zero for that same
  # failure — appending a second "000" via `|| echo "000"` produced "000000",
  # which matches no case pattern below and silently fell through to "assume
  # live". Overwriting on failure, instead of appending, is what makes the
  # unreachable-domain case actually register as 000 rather than a typo'd
  # unknown code that this function then treats as live by default.
  if ! code=$(curl -o /dev/null -s -w "%{http_code}" \
    --max-time 10 --connect-timeout 5 \
    -L --max-redirs 5 \
    -A "Mozilla/5.0 (compatible; archive-links/1.0)" \
    "$url" 2>/dev/null); then
    code="000"
  fi
  case "$code" in
    2*|3*|403|429) return 0 ;;  # live (or bot-blocked but server exists)
    404|410|000)   return 1 ;;  # genuinely dead
    *)             return 0 ;;  # unknown — assume live to avoid false positives
  esac
}
export -f check_url

# Fetch the best available Wayback Machine snapshot URL for a given URL.
# Prints the archive URL, or nothing if no snapshot exists.
wayback_url() {
  local url="$1"
  local api="https://archive.org/wayback/available?url=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$url")"
  local result
  result=$(curl -fsSL --max-time 10 "$api" 2>/dev/null || true)
  python3 - "$result" <<'EOF'
import sys, json
try:
    data = json.loads(sys.argv[1])
    url = data["archived_snapshots"]["closest"]["url"]
    # Prefer https
    print(url.replace("http://web.archive.org", "https://web.archive.org"))
except (KeyError, IndexError, json.JSONDecodeError):
    pass
EOF
}

PAIRS_FILE=$(mktemp)
UNIQUE_FILE=$(mktemp)
RESULTS_FILE=$(mktemp)
trap 'rm -f "$PAIRS_FILE" "$UNIQUE_FILE" "$RESULTS_FILE"' EXIT

# One "URL<TAB>FILE" line per (url, file) occurrence, across every input file —
# the join this script uses later to find every file a given URL appears in.
for file in "${FILES[@]}"; do
  grep -oE 'https?://[^[:space:])<>"]+' "$file" 2>/dev/null \
    | sed 's/[.,;:!?)]*$//' \
    | grep -v 'web\.archive\.org' \
    | sort -u \
    | while IFS= read -r u; do printf '%s\t%s\n' "$u" "$file"; done \
    >> "$PAIRS_FILE" || true
done

if [[ ! -s "$PAIRS_FILE" ]]; then
  echo "No URLs found."
  exit 0
fi

cut -f1 "$PAIRS_FILE" | sort -u > "$UNIQUE_FILE"
TOTAL_URLS=$(wc -l < "$UNIQUE_FILE" | tr -d ' ')

echo "Checking $TOTAL_URLS unique URL(s) from ${#FILES[@]} file(s), $PARALLEL_JOBS at a time..."

# -n 1, no -I: xargs appends each URL as a genuine argv element ($0 inside the
# bash -c script) rather than substituting it as text into the command line,
# so a URL containing a shell metacharacter (quotes, $, backticks) can't break
# out of the command. check_url is exported above, so child bash processes
# xargs spawns inherit it the same way any exported bash function is passed
# through the environment.
xargs -P "$PARALLEL_JOBS" -n 1 bash -c '
  url="$0"
  if check_url "$url"; then
    printf "%s\tLIVE\n" "$url"
  else
    printf "%s\tDEAD\n" "$url"
  fi
' < "$UNIQUE_FILE" > "$RESULTS_FILE"

TOTAL_DEAD=0
TOTAL_ARCHIVED=0
TOTAL_MISSING=0
TOTAL_FILES_UPDATED=0

while IFS=$'\t' read -r url status; do
  [[ "$status" == "DEAD" ]] || continue
  TOTAL_DEAD=$((TOTAL_DEAD + 1))

  citing_files=()
  while IFS= read -r f; do citing_files+=("$f"); done \
    < <(awk -F'\t' -v u="$url" '$1 == u { print $2 }' "$PAIRS_FILE")

  echo "  DEAD: $url"
  printf '        in %s\n' "${citing_files[@]}"

  archive=$(wayback_url "$url")

  if [[ -z "$archive" ]]; then
    echo "        no Wayback snapshot found — skipping"
    TOTAL_MISSING=$((TOTAL_MISSING + 1))
    continue
  fi

  echo "        → $archive"
  TOTAL_ARCHIVED=$((TOTAL_ARCHIVED + 1))

  if ! $DRY_RUN; then
    escaped_url=$(printf '%s' "$url" | sed 's/[[\.*^$()+?{|]/\\&/g')
    escaped_archive=$(printf '%s' "$archive" | sed 's/[[\.*^$()+?{|]/\\&/g; s/&/\\\&/g')
    for f in "${citing_files[@]}"; do
      sed_inplace "s|$escaped_url|$escaped_archive|g" "$f"
      TOTAL_FILES_UPDATED=$((TOTAL_FILES_UPDATED + 1))
    done
  fi
done < "$RESULTS_FILE"

echo ""
echo "Summary: $TOTAL_DEAD dead unique URL(s) found — $TOTAL_ARCHIVED archived across $TOTAL_FILES_UPDATED file update(s), $TOTAL_MISSING had no snapshot"
if $DRY_RUN && [[ $TOTAL_ARCHIVED -gt 0 ]]; then
  echo "(dry-run: no files were modified)"
fi
