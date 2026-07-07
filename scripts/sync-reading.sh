#!/usr/bin/env bash
# Scaffold a reading-ledger entry from an existing Obsidian reading note + Zotero.
#
# Given a cite key, this pulls the bibliographic identity from the Zotero-exported
# CSL-JSON library (title, author, year, publisher/ISBN or journal/volume/issue/
# pages/DOI/URL) so academic sources are not re-typed into data/reading/ by hand.
# It requires a matching reading note in the vault, keeping the ledger aligned with
# the research library (the same contract scripts/checks/citekey-lint.py enforces).
#
# Reading-specific fields (status, dates, notes, format) are prompted, then the
# entry opens in your editor for a final pass.
#
# Config (env overrides):
#   WEBSITE_VAULT_DIR          Obsidian vault           (default ~/Notes)
#   WEBSITE_READING_NOTES_DIR  reading-notes subfolder  (default "02 Notes/01 Reading Notes")
#   WEBSITE_BIBLIOGRAPHY       CSL-JSON library         (default ~/Documents/Library/Library.json)
#
# Usage: sync-reading.sh <citekey> [book|article]

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <citekey> [book|article]" >&2
  echo "Scaffolds data/reading/<type>s/<slug>.yaml from the Zotero library + vault note." >&2
  exit 1
}

[[ $# -ge 1 && $# -le 2 ]] || usage
CITEKEY="$1"
TYPE_OVERRIDE="${2:-}"
case "$TYPE_OVERRIDE" in ""|book|article) ;; *) usage ;; esac

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
READING_ROOT="$REPO_ROOT/data/reading"

VAULT="${WEBSITE_VAULT_DIR:-$HOME/Notes}"
NOTES_SUB="${WEBSITE_READING_NOTES_DIR:-02 Notes/01 Reading Notes}"
NOTE="$VAULT/$NOTES_SUB/$CITEKEY.md"
BIB="${WEBSITE_BIBLIOGRAPHY:-$HOME/Documents/Library/Library.json}"

[[ -f "$NOTE" ]] || { echo "Reading note not found: $NOTE" >&2; exit 1; }

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

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

current_timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/'
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

# Pull bibliographic identity from the Zotero library (preferred) or the vault
# note front matter (fallback). Emits key<TAB>value lines.
LOOKUP="$(CITEKEY="$CITEKEY" BIB="$BIB" NOTE="$NOTE" python3 <<'PY'
import json, os, re
from pathlib import Path

citekey = os.environ["CITEKEY"]
bib_path = Path(os.environ["BIB"])
note_path = Path(os.environ["NOTE"])

out = {}

def clean(v):
    if v is None:
        return ""
    if isinstance(v, list):
        v = " and ".join(str(x).strip() for x in v if str(x).strip())
    return re.sub(r"\s+", " ", str(v)).strip()

entry = None
if bib_path.is_file():
    try:
        data = json.loads(bib_path.read_text(encoding="utf-8"))
    except Exception:
        data = []
    for item in data if isinstance(data, list) else []:
        if str(item.get("citation-key") or item.get("id")) == citekey:
            entry = item
            break

BOOKISH = {"book", "chapter", "entry-encyclopedia", "entry-dictionary"}
ARTICLEISH = {"article-journal", "article-magazine", "article-newspaper",
              "article", "paper-conference", "review"}

if entry:
    csl_type = entry.get("type", "")
    out["type"] = "book" if csl_type in BOOKISH else ("article" if csl_type in ARTICLEISH else "")
    out["title"] = clean(entry.get("title"))
    authors = []
    for a in entry.get("author", []) or []:
        if not isinstance(a, dict):
            continue
        if a.get("literal"):
            authors.append(clean(a["literal"]))
        else:
            name = " ".join(p for p in (clean(a.get("given")), clean(a.get("family"))) if p)
            if name:
                authors.append(name)
    out["author"] = " and ".join(authors)
    issued = entry.get("issued", {}).get("date-parts", [])
    if issued and issued[0]:
        out["published_year"] = str(issued[0][0])
    out["publisher"] = clean(entry.get("publisher"))
    isbn = clean(entry.get("ISBN"))
    out["isbn"] = re.sub(r"[^0-9Xx]", "", isbn) if isbn else ""
    out["container_title"] = clean(entry.get("container-title"))
    out["volume"] = clean(entry.get("volume"))
    out["issue"] = clean(entry.get("issue"))
    out["pages"] = clean(entry.get("page"))
    out["doi"] = clean(entry.get("DOI"))
    out["url"] = clean(entry.get("URL"))

# Fall back to note front matter for the core identity if the library lacked it.
lines = note_path.read_text(encoding="utf-8", errors="replace").splitlines()
if lines and lines[0].strip() == "---":
    fm = {}
    for line in lines[1:]:
        if line.strip() == "---":
            break
        m = re.match(r"^([A-Za-z0-9_-]+)\s*:\s*(.*)$", line)
        if m:
            val = m.group(2).strip()
            if len(val) >= 2 and val[0] in "\"'" and val[-1] == val[0]:
                val = val[1:-1]
            fm[m.group(1)] = val.strip()
    if not out.get("title"):
        out["title"] = fm.get("title", "")
    if not out.get("author"):
        out["author"] = fm.get("authors", fm.get("author", ""))
    if not out.get("published_year"):
        out["published_year"] = fm.get("year", "")
    if not out.get("container_title"):
        out["container_title"] = fm.get("publication", "")
    if not out.get("type"):
        t = fm.get("type", "")
        out["type"] = "book" if t == "book" else ("article" if t in ("journalArticle", "article") else "")

for k, v in out.items():
    if v:
        print(f"{k}\t{v}")
PY
)"

TITLE=""; AUTHOR=""; PUBLISHED_YEAR=""; PUBLISHER=""; ISBN=""
CONTAINER_TITLE=""; VOLUME=""; ISSUE=""; PAGES=""; DOI=""; URL=""; DETECTED_TYPE=""
while IFS=$'\t' read -r key value; do
  case "$key" in
    type) DETECTED_TYPE="$value" ;;
    title) TITLE="$value" ;;
    author) AUTHOR="$value" ;;
    published_year) PUBLISHED_YEAR="$value" ;;
    publisher) PUBLISHER="$value" ;;
    isbn) ISBN="$value" ;;
    container_title) CONTAINER_TITLE="$value" ;;
    volume) VOLUME="$value" ;;
    issue) ISSUE="$value" ;;
    pages) PAGES="$value" ;;
    doi) DOI="$value" ;;
    url) URL="$value" ;;
  esac
done <<< "$LOOKUP"

SOURCE_TYPE="${TYPE_OVERRIDE:-$DETECTED_TYPE}"
if [[ -z "$SOURCE_TYPE" ]]; then
  SOURCE_TYPE=$(read_with_default "Source type [book/article]" "book")
fi
case "$SOURCE_TYPE" in
  book) SOURCE_DIR="$READING_ROOT/books" ;;
  article) SOURCE_DIR="$READING_ROOT/articles" ;;
  *) echo "Unsupported source type: $SOURCE_TYPE" >&2; exit 1 ;;
esac
mkdir -p "$SOURCE_DIR"

echo "Syncing '$CITEKEY' from $NOTE" >&2
TITLE=$(read_with_default "Title" "$TITLE")
[[ -z "${TITLE// }" ]] && { echo "Title is required." >&2; exit 1; }
AUTHOR=$(read_with_default "Author" "$AUTHOR")
PUBLISHED_YEAR=$(read_with_default "Publication year" "$PUBLISHED_YEAR")

if [[ "$SOURCE_TYPE" == "book" ]]; then
  PUBLISHER=$(read_with_default "Publisher/press" "$PUBLISHER")
  ISBN=$(read_with_default "ISBN" "$ISBN")
  FORMAT=$(read_optional "Format (optional)")
else
  CONTAINER_TITLE=$(read_with_default "Journal/publication" "$CONTAINER_TITLE")
  VOLUME=$(read_with_default "Volume" "$VOLUME")
  ISSUE=$(read_with_default "Issue" "$ISSUE")
  PAGES=$(read_with_default "Pages" "$PAGES")
  if [[ -n "$DOI" && -z "$URL" ]]; then URL="https://doi.org/$DOI"; fi
  URL=$(read_with_default "Access URL" "$URL")
fi

slug="$(slugify "$TITLE")"
[[ -z "$slug" ]] && slug="untitled-$SOURCE_TYPE"
file="$SOURCE_DIR/$slug.yaml"
[[ -e "$file" ]] && { echo "Refusing to overwrite existing file: ${file#$REPO_ROOT/}" >&2; exit 1; }

STATUS=$(read_with_default "Status [read/current]" "read")
STATUS=$(trim "$STATUS")
[[ "$STATUS" == "read" || "$STATUS" == "current" ]] || { echo "Status must be read or current." >&2; exit 1; }

STARTED=""; STARTED_ANNOUNCED=""; FINISHED=""; FINISHED_ANNOUNCED=""; READ_YEAR=""
if [[ "$STATUS" == "current" ]]; then
  STARTED=$(read_optional "Started date YYYY-MM-DD (optional)")
  [[ -n "$(trim "$STARTED")" ]] && STARTED_ANNOUNCED="$(current_timestamp)"
else
  FINISHED=$(read_optional "Finished date YYYY-MM-DD (optional)")
  READ_YEAR_DEFAULT=""
  [[ "$FINISHED" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && READ_YEAR_DEFAULT="${FINISHED%%-*}"
  READ_YEAR=$(read_with_default "Read year (optional)" "$READ_YEAR_DEFAULT")
  [[ -n "$(trim "$FINISHED")" ]] && FINISHED_ANNOUNCED="$(current_timestamp)"
fi

NOTES=$(read_optional "Notes (optional)")

{
  field "title" "$TITLE"
  field "author" "$AUTHOR"
  field "type" "$SOURCE_TYPE"
  field "cite_key" "$CITEKEY"
  field "status" "$STATUS"
  numeric_field "published_year" "$PUBLISHED_YEAR"
  numeric_field "read_year" "$READ_YEAR"
  if [[ "$SOURCE_TYPE" == "book" ]]; then
    field "publisher" "$PUBLISHER"
    field "isbn" "$ISBN"
    field "format" "${FORMAT:-}"
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
