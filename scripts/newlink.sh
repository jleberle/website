#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <url> [title]" >&2
  exit 1
}

[ $# -lt 1 ] && usage
URL="$1"
PROVIDED_TITLE="${2:-}"

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
LINKS_DIR="$REPO_ROOT/content/links"

fetch_title() {
  local url="$1"
  curl -fsSL --max-time 10 \
    -A "Mozilla/5.0 (compatible; newlink/1.0)" \
    "$url" 2>/dev/null | python3 -c '
import re, sys, html
data = sys.stdin.read()
m = re.search(r"<title[^>]*>(.*?)</title>", data, re.I | re.S)
if not m:
    sys.exit(1)
print(html.unescape(m.group(1)).strip())
'
}

if [ -n "$PROVIDED_TITLE" ]; then
  TITLE="$PROVIDED_TITLE"
else
  echo "Fetching title from $URL..." >&2
  if TITLE=$(fetch_title "$URL") && [ -n "$TITLE" ]; then
    echo "  Title: $TITLE" >&2
    read -r -p "Use this title? [Y/n] " ans || ans="n"
    if [[ "$ans" =~ ^[nN] ]]; then
      read -r -p "Title: " TITLE || TITLE=""
    fi
  else
    echo "  Could not fetch title." >&2
    read -r -p "Title: " TITLE || TITLE=""
  fi
fi

[ -z "${TITLE:-}" ] && { echo "Title is required." >&2; exit 1; }

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | \
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}
SLUG=$(slugify "$TITLE")
[ -z "$SLUG" ] && SLUG="untitled"

TODAY=$(date +%Y-%m-%d)
DATE_FULL=$(date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([+-][0-9]{2})([0-9]{2})$/\1:\2/')

BASE="$TODAY-$SLUG"
FILE="$LINKS_DIR/$BASE.md"
N=2
while [ -e "$FILE" ]; do
  FILE="$LINKS_DIR/$BASE-$N.md"
  N=$((N+1))
done

yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

mkdir -p "$LINKS_DIR"
cat > "$FILE" <<EOF
---
title: "$(yaml_escape "$TITLE")"
date: $DATE_FULL
external_url: "$(yaml_escape "$URL")"
---

EOF

echo "Created $FILE" >&2
EDITOR_CMD="${VISUAL:-${EDITOR:-vi}}"
exec $EDITOR_CMD "$FILE"
