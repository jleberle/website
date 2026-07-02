#!/usr/bin/env bash
# Create a single reading-ledger entry under data/reading/books/.
# Prompts for ISBN first and uses Open Library to prefill basic metadata.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [\"Book Title\"]" >&2
  echo "Creates data/reading/books/<slug>.yaml" >&2
  echo "If ISBN is provided, Open Library is queried to prefill metadata." >&2
  exit 1
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
BOOK_DIR="$REPO_ROOT/data/reading/books"

TITLE="${1:-}"
[[ $# -gt 1 ]] && usage
[[ "$TITLE" == "--help" || "$TITLE" == "-h" ]] && usage

read_optional() {
  local prompt="$1" value
  read -r -p "$prompt: " value || value=""
  printf '%s' "$value"
}

read_with_default() {
  local prompt="$1" default_value="$2" value
  if [[ -n "$default_value" ]]; then
    read -r -p "$prompt [$default_value]: " value || value=""
    value=$(trim "$value")
    [[ -z "$value" ]] && value="$default_value"
  else
    read -r -p "$prompt: " value || value=""
  fi
  printf '%s' "$value"
}

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | \
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

current_timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/'
}

normalize_isbn() {
  printf '%s' "$1" | tr -cd '[:alnum:]' | tr '[:lower:]' '[:upper:]'
}

field() {
  local key="$1" value
  value=$(trim "$2")
  [[ -z "$value" ]] && return 0
  printf '%s: "%s"\n' "$key" "$(yaml_escape "$value")"
}

numeric_field() {
  local key="$1" value
  value=$(trim "$2")
  [[ -z "$value" ]] && return 0
  printf '%s: %s\n' "$key" "$value"
}

lookup_openlibrary() {
  local isbn="$1" response lookup

  command -v curl >/dev/null 2>&1 || return 1
  command -v python3 >/dev/null 2>&1 || return 1

  response=$(curl --fail --silent --show-error --location --max-time 10 \
    "https://openlibrary.org/api/books?bibkeys=ISBN:${isbn}&format=json&jscmd=data" 2>/dev/null || true)

  [[ -n "$response" && "$response" != "{}" ]] || return 1

  lookup=$(OPENLIB_PAYLOAD="$response" python3 - "$isbn" <<'PY'
import json
import os
import re
import sys

isbn = sys.argv[1]
payload = os.environ.get("OPENLIB_PAYLOAD", "")
data = json.loads(payload or "{}")
book = data.get(f"ISBN:{isbn}", {})

def clean(value):
    if value is None:
        return ""
    if isinstance(value, list):
        value = " and ".join(str(item).strip() for item in value if str(item).strip())
    else:
        value = str(value).strip()
    return re.sub(r"\s+", " ", value).strip()

title = clean(book.get("title"))
subtitle = clean(book.get("subtitle"))
if title and subtitle:
    title = f"{title}: {subtitle}"

authors = clean([
    item.get("name", "").strip()
    for item in book.get("authors", [])
    if isinstance(item, dict) and item.get("name")
])

publisher_items = [
    item.get("name", "").strip() if isinstance(item, dict) else str(item).strip()
    for item in book.get("publishers", [])
    if item
]
publisher = clean(publisher_items[0]) if publisher_items else ""

publish_date = clean(book.get("publish_date"))
year_match = re.search(r"(1[0-9]{3}|20[0-9]{2}|2100)", publish_date)
published_year = year_match.group(1) if year_match else ""

for key, value in (
    ("title", title),
    ("author", authors),
    ("publisher", publisher),
    ("published_year", published_year),
):
    print(f"{key}\t{value}")
PY
)

  [[ -n "$lookup" ]] || return 1
  printf '%s\n' "$lookup"
}

mkdir -p "$BOOK_DIR"

LOOKUP_TITLE=""
LOOKUP_AUTHOR=""
LOOKUP_PUBLISHER=""
LOOKUP_PUBLISHED_YEAR=""

ISBN_INPUT=$(read_optional "ISBN (optional, used for Open Library lookup)")
ISBN=$(normalize_isbn "$ISBN_INPUT")
if [[ -n "$ISBN" ]]; then
  if lookup_data=$(lookup_openlibrary "$ISBN"); then
    while IFS=$'\t' read -r key value; do
      case "$key" in
        title) LOOKUP_TITLE="$value" ;;
        author) LOOKUP_AUTHOR="$value" ;;
        publisher) LOOKUP_PUBLISHER="$value" ;;
        published_year) LOOKUP_PUBLISHED_YEAR="$value" ;;
      esac
    done <<< "$lookup_data"
    echo "Prefilled basic metadata from Open Library for ISBN $ISBN." >&2
  else
    echo "No Open Library lookup data found for ISBN $ISBN; continuing with manual entry." >&2
  fi
fi

TITLE=$(read_with_default "Book title" "${LOOKUP_TITLE:-$TITLE}")
[[ -z "${TITLE// }" ]] && { echo "Book title is required." >&2; exit 1; }

slug="$(slugify "$TITLE")"
[[ -z "$slug" ]] && slug="untitled-book"

file="$BOOK_DIR/$slug.yaml"
if [[ -e "$file" ]]; then
  echo "Refusing to overwrite existing file: ${file#$REPO_ROOT/}" >&2
  exit 1
fi

AUTHOR=$(read_with_default "Author (optional)" "$LOOKUP_AUTHOR")
PUBLISHER=$(read_with_default "Publisher/press (optional)" "$LOOKUP_PUBLISHER")
PUBLISHED_YEAR=$(read_with_default "Publication year (optional)" "$LOOKUP_PUBLISHED_YEAR")
FORMAT=$(read_optional "Format (optional)")
CITE_KEY=$(read_optional "Cite key, e.g. mckenziejones2015 (optional)")
STATUS=$(read_with_default 'Status [read/current]' "read")
STATUS=$(trim "$STATUS")
[[ -z "$STATUS" ]] && STATUS="read"

READ_YEAR=""
STARTED=""
FINISHED=""
STARTED_ANNOUNCED=""
FINISHED_ANNOUNCED=""
if [[ "$STATUS" == "current" ]]; then
  STARTED=$(read_optional "Started date YYYY-MM-DD (optional)")
  [[ -n "$(trim "$STARTED")" ]] && STARTED_ANNOUNCED="$(current_timestamp)"
else
  READ_YEAR=$(read_optional "Read year (optional)")
  FINISHED=$(read_optional "Finished date YYYY-MM-DD (optional)")
  [[ -n "$(trim "$FINISHED")" ]] && FINISHED_ANNOUNCED="$(current_timestamp)"
fi
NOTES=$(read_optional "Notes (optional)")

{
  field "title" "$TITLE"
  field "author" "$AUTHOR"
  field "cite_key" "$CITE_KEY"
  field "status" "$STATUS"
  numeric_field "published_year" "$PUBLISHED_YEAR"
  numeric_field "read_year" "$READ_YEAR"
  field "publisher" "$PUBLISHER"
  field "isbn" "$ISBN"
  field "format" "$FORMAT"
  field "started" "$STARTED"
  field "started_announced" "$STARTED_ANNOUNCED"
  field "finished" "$FINISHED"
  field "finished_announced" "$FINISHED_ANNOUNCED"
  field "notes" "$NOTES"
} > "$file"

echo "Created ${file#$REPO_ROOT/}" >&2
${VISUAL:-${EDITOR:-vi}} "$file"
