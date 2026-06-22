#!/usr/bin/env bash
# Check URLs in markdown files and replace dead ones with Wayback Machine snapshots.
#
# Usage:
#   scripts/archive-links.sh [file ...]       # check specific files
#   scripts/archive-links.sh --all            # check all content markdown files
#   scripts/archive-links.sh --dry-run [...]  # report only, no rewrites

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
DRY_RUN=false
FILES=()
ALL=false

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
  code=$(curl -o /dev/null -s -w "%{http_code}" \
    --max-time 10 --connect-timeout 5 \
    -L --max-redirs 5 \
    -A "Mozilla/5.0 (compatible; archive-links/1.0)" \
    "$url" 2>/dev/null || echo "000")
  case "$code" in
    2*|3*|403|429) return 0 ;;  # live (or bot-blocked but server exists)
    404|410|000)   return 1 ;;  # genuinely dead
    *)             return 0 ;;  # unknown — assume live to avoid false positives
  esac
}

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

TOTAL_DEAD=0
TOTAL_ARCHIVED=0
TOTAL_MISSING=0

for file in "${FILES[@]}"; do
  # Extract all https?:// URLs — markdown links, bare footnote URLs, and inline prose URLs
  # Strip trailing punctuation that isn't part of the URL, skip already-archived links
  urls=()
  while IFS= read -r u; do urls+=("$u"); done < <(
    grep -oE 'https?://[^[:space:])<>"]+' "$file" 2>/dev/null \
    | sed 's/[.,;:!?)]*$//' \
    | grep -v 'web\.archive\.org' \
    | sort -u \
    || true
  )

  [[ ${#urls[@]} -eq 0 ]] && continue

  for url in "${urls[@]}"; do
    if check_url "$url"; then
      continue
    fi

    TOTAL_DEAD=$((TOTAL_DEAD + 1))
    echo "  DEAD: $url"
    echo "        in $file"

    archive=$(wayback_url "$url")

    if [[ -z "$archive" ]]; then
      echo "        no Wayback snapshot found — skipping"
      TOTAL_MISSING=$((TOTAL_MISSING + 1))
      continue
    fi

    echo "        → $archive"
    TOTAL_ARCHIVED=$((TOTAL_ARCHIVED + 1))

    if ! $DRY_RUN; then
      # Escape URL for use in sed
      escaped_url=$(printf '%s' "$url" | sed 's/[[\.*^$()+?{|]/\\&/g')
      escaped_archive=$(printf '%s' "$archive" | sed 's/[[\.*^$()+?{|]/\\&/g; s/&/\\\&/g')
      sed_inplace "s|$escaped_url|$escaped_archive|g" "$file"
    fi
  done
done

echo ""
echo "Summary: $TOTAL_DEAD dead link(s) found — $TOTAL_ARCHIVED replaced, $TOTAL_MISSING had no snapshot"
if $DRY_RUN && [[ $TOTAL_ARCHIVED -gt 0 ]]; then
  echo "(dry-run: no files were modified)"
fi
