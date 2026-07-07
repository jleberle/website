#!/usr/bin/env bash
# Create a reading-ledger entry under data/reading/<type>s/.
# Books can prefill from Open Library via ISBN. Articles can prefill from Crossref via DOI.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [book|article] [\"Title\"]" >&2
  echo "Creates data/reading/books/<slug>.yaml or data/reading/articles/<slug>.yaml" >&2
  echo "If type is omitted, the script prompts for it." >&2
  exit 1
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
READING_ROOT="$REPO_ROOT/data/reading"

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
  book) SOURCE_DIR="$READING_ROOT/books" ;;
  article) SOURCE_DIR="$READING_ROOT/articles" ;;
  *) echo "Unsupported source type: $SOURCE_TYPE" >&2; exit 1 ;;
esac

mkdir -p "$SOURCE_DIR"

AUTHOR=""
CITE_KEY=""
STATUS="read"
PUBLISHED_YEAR=""
READ_YEAR=""
STARTED=""
STARTED_ANNOUNCED=""
FINISHED=""
FINISHED_ANNOUNCED=""
NOTES=""
PUBLISHER=""
ISBN=""
FORMAT=""
CONTAINER_TITLE=""
VOLUME=""
ISSUE=""
PAGES=""
DOI=""
URL=""

if [[ "$SOURCE_TYPE" == "book" ]]; then
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

  AUTHOR=$(read_with_default "Author (optional)" "$LOOKUP_AUTHOR")
  PUBLISHER=$(read_with_default "Publisher/press (optional)" "$LOOKUP_PUBLISHER")
  PUBLISHED_YEAR=$(read_with_default "Publication year (optional)" "$LOOKUP_PUBLISHED_YEAR")
  FORMAT=$(read_optional "Format (optional)")
else
  LOOKUP_TITLE=""
  LOOKUP_AUTHOR=""
  LOOKUP_CONTAINER_TITLE=""
  LOOKUP_PUBLISHED_YEAR=""
  LOOKUP_VOLUME=""
  LOOKUP_ISSUE=""
  LOOKUP_PAGES=""
  LOOKUP_URL=""

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
          volume) LOOKUP_VOLUME="$value" ;;
          issue) LOOKUP_ISSUE="$value" ;;
          pages) LOOKUP_PAGES="$value" ;;
          url) LOOKUP_URL="$value" ;;
        esac
      done <<< "$lookup_data"
      echo "Prefilled basic metadata from Crossref for DOI $DOI." >&2
    else
      echo "No Crossref lookup data found for DOI $DOI; continuing with manual entry." >&2
    fi
  fi

  TITLE=$(read_with_default "Article title" "${LOOKUP_TITLE:-$TITLE}")
  [[ -z "${TITLE// }" ]] && { echo "Article title is required." >&2; exit 1; }

  AUTHOR=$(read_with_default "Author (optional)" "$LOOKUP_AUTHOR")
  CONTAINER_TITLE=$(read_with_default "Journal/publication (optional)" "$LOOKUP_CONTAINER_TITLE")
  PUBLISHED_YEAR=$(read_with_default "Publication year (optional)" "$LOOKUP_PUBLISHED_YEAR")
  VOLUME=$(read_with_default "Volume (optional)" "$LOOKUP_VOLUME")
  ISSUE=$(read_with_default "Issue (optional)" "$LOOKUP_ISSUE")
  PAGES=$(read_with_default "Pages (optional)" "$LOOKUP_PAGES")
  if [[ -n "$DOI" && -z "$LOOKUP_URL" ]]; then
    LOOKUP_URL="https://doi.org/$DOI"
  fi
  URL=$(read_with_default "Access URL (optional)" "$LOOKUP_URL")
fi

slug="$(slugify "$TITLE")"
[[ -z "$slug" ]] && slug="untitled-$SOURCE_TYPE"

file="$SOURCE_DIR/$slug.yaml"
if [[ -e "$file" ]]; then
  echo "Refusing to overwrite existing file: ${file#$REPO_ROOT/}" >&2
  exit 1
fi

CITE_KEY=$(read_optional "Cite key, e.g. mckenziejones2015 (optional)")
STATUS=$(read_with_default 'Status [read/current]' "read")
STATUS=$(trim "$STATUS")
[[ -z "$STATUS" ]] && STATUS="read"
[[ "$STATUS" == "read" || "$STATUS" == "current" ]] || {
  echo "Status must be read or current." >&2
  exit 1
}

if [[ "$STATUS" == "current" ]]; then
  STARTED=$(read_optional "Started date YYYY-MM-DD (optional)")
  [[ -n "$(trim "$STARTED")" ]] && STARTED_ANNOUNCED="$(rfc3339_now)"
else
  FINISHED=$(read_optional "Finished date YYYY-MM-DD (optional)")
  READ_YEAR_DEFAULT=""
  if [[ "$FINISHED" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    READ_YEAR_DEFAULT="${FINISHED%%-*}"
  fi
  READ_YEAR=$(read_with_default "Read year (optional)" "$READ_YEAR_DEFAULT")
  [[ -n "$(trim "$FINISHED")" ]] && FINISHED_ANNOUNCED="$(rfc3339_now)"
fi

NOTES=$(read_optional "Notes (optional)")

{
  field "title" "$TITLE"
  field "author" "$AUTHOR"
  field "type" "$SOURCE_TYPE"
  field "cite_key" "$CITE_KEY"
  field "status" "$STATUS"
  numeric_field "published_year" "$PUBLISHED_YEAR"
  numeric_field "read_year" "$READ_YEAR"
  if [[ "$SOURCE_TYPE" == "book" ]]; then
    field "publisher" "$PUBLISHER"
    field "isbn" "$ISBN"
    field "format" "$FORMAT"
  else
    field "container_title" "$CONTAINER_TITLE"
    field "volume" "$VOLUME"
    field "issue" "$ISSUE"
    field "pages" "$PAGES"
    field "doi" "$DOI"
    field "url" "$URL"
  fi
  field "started" "$STARTED"
  field "started_announced" "$STARTED_ANNOUNCED"
  field "finished" "$FINISHED"
  field "finished_announced" "$FINISHED_ANNOUNCED"
  field "notes" "$NOTES"
} > "$file"

echo "Created ${file#$REPO_ROOT/}" >&2
${VISUAL:-${EDITOR:-vi}} "$file"
