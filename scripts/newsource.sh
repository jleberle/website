#!/usr/bin/env bash
# Create a source page under content/sources/<slug>/_index.md.
#
# A source is one cited work. Its page is the single record for that work: it
# is listed on /reading/, published at /sources/<slug>/, and collects every post
# that names it in `sources:`. See docs/reading.md.
#
# Books prefill from Open Library via ISBN; articles prefill from Crossref via
# DOI. Both lookups are best-effort — if the network or the record is missing,
# the script says so and falls through to manual entry with no fields lost.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [book|article] [\"Title\"]" >&2
  echo "Creates content/sources/<slug>/_index.md." >&2
  echo "If type is omitted, the script prompts for it." >&2
  exit 1
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
SOURCES_ROOT="$REPO_ROOT/content/sources"

SOURCE_TYPE=""
TITLE=""

if [[ $# -gt 0 ]]; then
  case "${1:-}" in
    book|article)
      SOURCE_TYPE="$1"
      TITLE="${2:-}"
      [[ $# -le 2 ]] || usage
      ;;
    --help|-h)
      usage
      ;;
    *)
      TITLE="$1"
      [[ $# -le 1 ]] || usage
      ;;
  esac
fi

source "$SCRIPT_DIR/lib.sh"

normalize_isbn() {
  printf '%s' "$1" | tr -cd '[:alnum:]' | tr '[:lower:]' '[:upper:]'
}

normalize_doi() {
  local doi
  doi=$(trim "$1")
  doi="${doi#https://doi.org/}"
  doi="${doi#http://doi.org/}"
  doi="${doi#doi:}"
  printf '%s' "$doi"
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

lookup_crossref() {
  local doi="$1" encoded_doi response lookup

  command -v curl >/dev/null 2>&1 || return 1
  command -v python3 >/dev/null 2>&1 || return 1

  encoded_doi=$(python3 - "$doi" <<'PY'
import sys
from urllib.parse import quote

print(quote(sys.argv[1], safe=""))
PY
)

  response=$(curl --fail --silent --show-error --location --max-time 10 \
    "https://api.crossref.org/works/${encoded_doi}" 2>/dev/null || true)

  [[ -n "$response" && "$response" != "{}" ]] || return 1

  lookup=$(CROSSREF_PAYLOAD="$response" python3 - <<'PY'
import json
import os
import re

payload = os.environ.get("CROSSREF_PAYLOAD", "")
message = json.loads(payload or "{}").get("message", {})

def clean(value):
    if value is None:
        return ""
    if isinstance(value, list):
        value = " and ".join(str(item).strip() for item in value if str(item).strip())
    else:
        value = str(value).strip()
    return re.sub(r"\s+", " ", value).strip()

title = clean(message.get("title", []))
authors = []
for author in message.get("author", []):
    if not isinstance(author, dict):
        continue
    given = clean(author.get("given", ""))
    family = clean(author.get("family", ""))
    name = " ".join(part for part in (given, family) if part).strip()
    if name:
        authors.append(name)
author_text = clean(authors)

container_title = clean(message.get("container-title", []))
volume = clean(message.get("volume"))
issue = clean(message.get("issue"))
pages = clean(message.get("page"))
url = clean(message.get("URL"))

published_year = ""
for key in ("published-print", "published-online", "issued"):
    parts = message.get(key, {}).get("date-parts", [])
    if parts and parts[0]:
        published_year = str(parts[0][0])
        break

for key, value in (
    ("title", title),
    ("author", author_text),
    ("container_title", container_title),
    ("published_year", published_year),
    ("volume", volume),
    ("issue", issue),
    ("pages", pages),
    ("url", url),
):
    print(f"{key}\t{value}")
PY
)

  [[ -n "$lookup" ]] || return 1
  printf '%s\n' "$lookup"
}

if [[ -z "$SOURCE_TYPE" ]]; then
  SOURCE_TYPE=$(read_with_default "Source type [book/article]" "book")
fi
SOURCE_TYPE=$(trim "$SOURCE_TYPE")
case "$SOURCE_TYPE" in
  book|article) ;;
  *) echo "Unsupported source type: $SOURCE_TYPE" >&2; exit 1 ;;
esac

AUTHOR=""; PUBLISHER=""; PUBLISHED_YEAR=""; FORMAT=""
ISBN=""; DOI=""; ACCESS_URL=""

if [[ "$SOURCE_TYPE" == "book" ]]; then
  LOOKUP_TITLE=""; LOOKUP_AUTHOR=""; LOOKUP_PUBLISHER=""; LOOKUP_PUBLISHED_YEAR=""

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
      echo "Prefilled metadata from Open Library for ISBN $ISBN." >&2
    else
      echo "No Open Library data for ISBN $ISBN; continuing with manual entry." >&2
    fi
  fi

  TITLE=$(read_with_default "Book title" "${LOOKUP_TITLE:-$TITLE}")
  [[ -z "${TITLE// }" ]] && { echo "Book title is required." >&2; exit 1; }
  AUTHOR=$(read_with_default "Author (optional)" "$LOOKUP_AUTHOR")
  PUBLISHER=$(read_with_default "Publisher/press (optional)" "$LOOKUP_PUBLISHER")
  PUBLISHED_YEAR=$(read_with_default "Publication year (optional)" "$LOOKUP_PUBLISHED_YEAR")
  FORMAT=$(read_optional "Format (optional)")
else
  LOOKUP_TITLE=""; LOOKUP_AUTHOR=""; LOOKUP_CONTAINER_TITLE=""
  LOOKUP_PUBLISHED_YEAR=""; LOOKUP_URL=""

  DOI_INPUT=$(read_optional "DOI (optional, used for Crossref lookup)")
  DOI=$(normalize_doi "$DOI_INPUT")
  if [[ -n "$DOI" ]]; then
    if lookup_data=$(lookup_crossref "$DOI"); then
      while IFS=$'\t' read -r key value; do
        case "$key" in
          title) LOOKUP_TITLE="$value" ;;
          author) LOOKUP_AUTHOR="$value" ;;
          container_title) LOOKUP_CONTAINER_TITLE="$value" ;;
          published_year) LOOKUP_PUBLISHED_YEAR="$value" ;;
          url) LOOKUP_URL="$value" ;;
        esac
      done <<< "$lookup_data"
      echo "Prefilled metadata from Crossref for DOI $DOI." >&2
    else
      echo "No Crossref data for DOI $DOI; continuing with manual entry." >&2
    fi
  fi

  TITLE=$(read_with_default "Article title" "${LOOKUP_TITLE:-$TITLE}")
  [[ -z "${TITLE// }" ]] && { echo "Article title is required." >&2; exit 1; }
  AUTHOR=$(read_with_default "Author (optional)" "$LOOKUP_AUTHOR")
  PUBLISHER=$(read_with_default "Journal/publication (optional)" "$LOOKUP_CONTAINER_TITLE")
  PUBLISHED_YEAR=$(read_with_default "Publication year (optional)" "$LOOKUP_PUBLISHED_YEAR")
  ACCESS_URL=$(read_with_default "Access URL (optional)" "$LOOKUP_URL")
fi

STATUS=$(read_with_default "Status [read/reading]" "read")
STATUS=$(trim "$STATUS")
TODAY=$(date +%Y-%m-%d)

STARTED=""; FINISHED=""; READ_YEAR=""
if [[ "$STATUS" == "reading" ]]; then
  STARTED=$(read_with_default "Started (YYYY-MM-DD)" "$TODAY")
else
  STATUS="read"
  FINISHED=$(read_with_default "Finished (YYYY-MM-DD, blank if unknown)" "$TODAY")
  READ_YEAR="${FINISHED%%-*}"
  READ_YEAR=$(read_with_default "Read year (optional)" "$READ_YEAR")
fi

NOTES=$(read_optional "Short note (optional)")

# The folder name IS the key a post references in `sources:`, so it defaults to
# a citation-style lastname+year rather than a title slug — short enough to type
# from memory and stable when a subtitle changes. Anything is accepted as long
# as it urlizes to itself (lowercase, no spaces or underscores).
KEY_AUTHOR=$(printf '%s' "$AUTHOR" \
  | sed 's/ and .*//; s/,.*//' \
  | awk '{ for (i = NF; i > 0; i--) if (length($i) > 2 || $i !~ /^[A-Z]\.?$/) { print $i; exit } }' \
  | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z')
SLUG="${KEY_AUTHOR}${PUBLISHED_YEAR}"
[[ -z "$SLUG" ]] && SLUG=$(slugify "$TITLE")
[[ -z "$SLUG" ]] && SLUG="untitled-source"
SLUG=$(read_with_default "Key (folder name, referenced as sources: [\"...\"])" "$SLUG")

DEST="$SOURCES_ROOT/$SLUG"
if [[ -e "$DEST/_index.md" ]]; then
  echo "A source already exists at content/sources/$SLUG/_index.md" >&2
  exit 1
fi
mkdir -p "$DEST"

{
  printf -- '---\n'
  printf 'title: "%s"\n' "$(yaml_escape "$TITLE")"
  field "author" "$AUTHOR"
  [[ "$SOURCE_TYPE" != "book" ]] && printf 'type: "%s"\n' "$SOURCE_TYPE"
  printf 'status: "%s"\n' "$STATUS"
  [[ -n "$PUBLISHED_YEAR" ]] && printf 'published_year: %s\n' "$PUBLISHED_YEAR"
  [[ -n "$READ_YEAR" ]] && printf 'read_year: %s\n' "$READ_YEAR"
  field "publisher" "$PUBLISHER"
  field "format" "$FORMAT"
  field "isbn" "$ISBN"
  field "doi" "$DOI"
  field "access_url" "$ACCESS_URL"
  field "started" "$STARTED"
  field "finished" "$FINISHED"
  printf -- '---\n\n'
  [[ -n "$NOTES" ]] && printf '%s\n' "$NOTES"
} > "$DEST/_index.md"

echo "Created content/sources/$SLUG/_index.md" >&2
echo "Connect writing to it with: sources: [\"$SLUG\"]" >&2
EDITOR_CMD="${VISUAL:-${EDITOR:-vi}}"
exec $EDITOR_CMD "$DEST/_index.md"
