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
    book|article|zotero)
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

# The ISBN entered here is not just local metadata: the reading feed publishes
# it as https://micro.blog/books/<isbn>, and Micro.blog builds the book record
# behind /reading/ and its reading goals from that link. An ISBN it cannot
# resolve produces a placeholder cover over there and no signal at all here.
#
# cdn.micro.blog answers unauthenticated, so the ISBN can be checked at the
# moment it is typed rather than by going to Micro.blog to look one up — which
# would defeat entering a work once, in this repo. See
# scripts/checks/book-cover-lint.py for the same check over the whole ledger and
# for what the three response shapes mean.
#
# Best-effort, exactly like the Open Library and Crossref lookups above: a
# network failure warns and gets out of the way rather than blocking the entry.
microblog_cover_state() {
  local isbn="$1" body size

  command -v curl >/dev/null 2>&1 || return 1

  body=$(mktemp)
  if ! curl --silent --location --max-time 15 --output "$body" \
       "https://cdn.micro.blog/books/${isbn}/cover.jpg" 2>/dev/null; then
    rm -f "$body"
    return 1
  fi

  size=$(wc -c < "$body" | tr -d '[:space:]')
  if [[ "$size" -lt 1000 ]]; then
    rm -f "$body"
    printf 'unknown-isbn'
    return 0
  fi
  if [[ "$(md5 -q "$body" 2>/dev/null || md5sum "$body" | cut -d' ' -f1)" \
        == "15677f7d458bc161a2b3a8597e290f39" ]]; then
    rm -f "$body"
    printf 'no-cover'
    return 0
  fi
  rm -f "$body"
  printf 'ok'
}

# Echoes the ISBN to keep (possibly re-entered) on stdout; everything else goes
# to stderr so this can be used inline in an assignment.
confirm_isbn_cover() {
  local isbn="$1" state

  while [[ -n "$isbn" ]]; do
    if ! state=$(microblog_cover_state "$isbn"); then
      echo "Could not reach cdn.micro.blog to check ISBN $isbn; continuing." >&2
      break
    fi
    case "$state" in
      ok)
        break
        ;;
      no-cover)
        echo "Micro.blog knows ISBN $isbn but has no cover art for it." >&2
        ;;
      unknown-isbn)
        echo "Micro.blog cannot resolve ISBN $isbn at all." >&2
        ;;
    esac
    echo "Another edition's ISBN will render a cover on /reading/ and in reading goals." >&2
    local retry
    retry=$(read_optional "ISBN (blank to keep $isbn)")
    retry=$(normalize_isbn "$retry")
    [[ -z "$retry" || "$retry" == "$isbn" ]] && break
    isbn="$retry"
  done

  printf '%s' "$isbn"
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

# The edition lookup above reports the printing you hold, which is the right
# `published_year` for a reading ledger but the wrong year for a citation key —
# a 2012 printing of The Hobbit is not tolkien2012. Open Library keeps a "work"
# above its editions, and its search index exposes that work's first publication
# year, so the key can cite the work while the record describes the edition.
lookup_openlibrary_first_year() {
  local isbn="$1" response year

  command -v curl >/dev/null 2>&1 || return 1
  command -v python3 >/dev/null 2>&1 || return 1

  response=$(curl --fail --silent --location --max-time 10 \
    "https://openlibrary.org/search.json?isbn=${isbn}&fields=first_publish_year&limit=1" 2>/dev/null || true)

  [[ -n "$response" ]] || return 1

  year=$(OPENLIB_SEARCH="$response" python3 - <<'PY_INNER'
import json
import os

try:
    docs = (json.loads(os.environ.get("OPENLIB_SEARCH") or "{}") or {}).get("docs") or []
except (ValueError, AttributeError):
    docs = []
year = docs[0].get("first_publish_year") if isinstance(docs and docs[0], dict) else None
print(year if isinstance(year, int) and 1000 < year < 2200 else "")
PY_INNER
)

  [[ -n "$year" ]] || return 1
  printf '%s\n' "$year"
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

# Zotero is the scholarly half of the library and the only lookup here that is
# local, offline, and already correct — the record was curated when the work was
# read rather than reconstructed from a catalogue afterwards. It also carries
# the one field the network lookups cannot supply: `citation-key`, which is
# exactly what a source folder is named (see docs/reading.md), so importing a
# work and naming its page are the same act.
#
# It is a prefill, never a requirement. Only 23 of 59 current sources are in
# Zotero at all — the casual reading is not and should not be, which is the
# whole reason the cite-key ledger was replaced by the sources taxonomy in
# b8fce17. A book read on holiday still costs one file.
zotero_library() {
  printf '%s' "${WEBSITE_BIBLIOGRAPHY:-$HOME/Documents/Library/Library.json}"
}

# Emits the same key<TAB>value stream as the network lookups. MODE is "key" for
# an exact citation-key match or "search" to list candidates.
lookup_zotero() {
  local mode="$1" needle="$2" bib
  bib=$(zotero_library)
  [[ -f "$bib" ]] || return 1
  command -v python3 >/dev/null 2>&1 || return 1

  python3 - "$bib" "$mode" "$needle" <<'PY'
import json, re, sys, unicodedata

bib, mode, needle = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    lib = json.load(open(bib, encoding="utf-8"))
except (OSError, ValueError):
    sys.exit(1)

def name(a):
    if a.get("literal"):
        return a["literal"].strip()
    return " ".join(p for p in (a.get("given", "").strip(), a.get("family", "").strip()) if p)

def authors(e):
    return " and ".join(n for n in (name(a) for a in e.get("author", [])) if n)

def year(e):
    parts = (e.get("issued") or {}).get("date-parts") or [[]]
    return str(parts[0][0]) if parts and parts[0] else ""

# Zotero stores titles in sentence case; every source page on the site is in
# title case, so importing verbatim would leave one record in five looking
# unlike its neighbours. This only ever raises a word's first letter — a token
# already carrying a capital anywhere (Pequots, Seminole, U.S., McKenzie-Jones)
# is passed through untouched — so it cannot mangle a proper noun or an
# acronym, and the result is still only the editable default at the prompt.
SMALL = {"a", "an", "the", "and", "but", "or", "nor", "for", "so", "yet", "at",
         "by", "in", "of", "on", "to", "up", "as", "from", "with", "into",
         "over", "than", "that", "via"}

def title_case(text):
    words = text.split(" ")
    out = []
    start = True
    for w in words:
        if not w:
            out.append(w)
            continue
        if any(c.isupper() for c in w):
            out.append(w)
        elif start or w.lower().strip(".,;:'\"()") not in SMALL:
            out.append(w[0].upper() + w[1:])
        else:
            out.append(w)
        start = w.endswith(":") or w.endswith("?") or w.endswith("—")
    return " ".join(out)

# Zotero packs every ISBN an edition ever had into one space-separated field —
# 39 of 94 entries here do. The site's templates strip non-alphanumerics to
# build Open Library and WorldCat links, so passing the raw field through would
# fuse two ISBNs into one bogus 26-digit number and produce dead links on both.
def isbn(e):
    raw = (e.get("ISBN") or "").strip()
    return re.sub(r"[^0-9Xx]", "", raw.split()[0]) if raw else ""

# The site knows five kinds; CSL knows dozens. Anything archival maps to
# `archive` so it is not offered a library-catalogue search it cannot satisfy.
TYPES = {
    "book": "book", "chapter": "book",
    "thesis": "thesis",
    "article-journal": "article", "article-magazine": "article",
    "article-newspaper": "article", "paper-conference": "article",
    "manuscript": "archive", "document": "archive", "report": "archive",
}

# CSL has one `thesis` type for work at every degree level; Zotero keeps the
# level in the item's own Type field, exported as `genre` — "Dissertation",
# "Master's Thesis", "M.S.". A doctoral dissertation is not a thesis and the
# kicker is the only place the site says which it is, so read the degree rather
# than flattening both to "Thesis". Anything not clearly doctoral stays
# `thesis`, which covers the master's spellings without enumerating them.
DOCTORAL = re.compile(r"dissertation|doctoral|ph\.?\s*d", re.I)

# Zotero also only sometimes types a dissertation as `thesis` at all; older and
# imported records land on the generic `document` and carry the kind in `genre`
# alone. Trusting the CSL type there labels a dissertation "Archive".
def source_type(e):
    t = TYPES.get(e.get("type", ""), "book")
    genre = e.get("genre") or ""
    if t == "archive" and re.search(r"thesis|dissertation", genre, re.I):
        t = "thesis"
    if t == "thesis" and DOCTORAL.search(genre):
        return "dissertation"
    return t

# Neither has a publisher; Zotero files the granting institution under
# `publisher-place`. Reading that field for any other type would put a city
# where the press belongs.
def publisher(e):
    p = (e.get("publisher") or e.get("container-title") or "").strip()
    if not p and source_type(e) in ("thesis", "dissertation"):
        p = (e.get("publisher-place") or "").strip()
    return p

if mode == "key":
    hit = next((e for e in lib if e.get("citation-key") == needle), None)
    if hit is None:
        sys.exit(1)
    fields = (
        ("citation_key", hit.get("citation-key", "")),
        ("source_type", source_type(hit)),
        ("title", title_case(re.sub(r"\s+", " ", (hit.get("title") or "").strip()))),
        ("author", authors(hit)),
        ("publisher", publisher(hit)),
        ("published_year", year(hit)),
        ("isbn", isbn(hit)),
        ("doi", (hit.get("DOI") or "").strip()),
        ("url", (hit.get("URL") or "").strip()),
    )
    for k, v in fields:
        print(f"{k}\t{v}")
    sys.exit(0)

def fold(s):
    s = unicodedata.normalize("NFKD", s or "")
    return re.sub(r"[^a-z0-9 ]+", " ", s.encode("ascii", "ignore").decode().lower())

terms = [t for t in fold(needle).split() if t]
rows = []
for e in lib:
    hay = fold(f"{e.get('citation-key','')} {e.get('title','')} {authors(e)} {year(e)}")
    if all(t in hay for t in terms):
        rows.append((e.get("citation-key", ""), year(e), authors(e)[:28], (e.get("title") or "")[:52]))
for r in sorted(rows, key=lambda r: r[1], reverse=True)[:15]:
    print("\t".join(r))
sys.exit(0 if rows else 1)
PY
}

if [[ "$SOURCE_TYPE" == "zotero" ]]; then
  BIB_PATH=$(zotero_library)
  [[ -f "$BIB_PATH" ]] || {
    echo "Zotero library not found: $BIB_PATH (set WEBSITE_BIBLIOGRAPHY)" >&2
    exit 3
  }

  ZKEY="$TITLE"
  if [[ -z "$ZKEY" ]]; then
    ZKEY=$(read_optional "Zotero citation key (or words to search for)")
  fi
  [[ -n "${ZKEY// }" ]] || { echo "A citation key or search term is required." >&2; exit 1; }

  if ! ZLOOKUP=$(lookup_zotero key "$ZKEY"); then
    echo "No entry with citation key '$ZKEY'. Searching…" >&2
    if ! MATCHES=$(lookup_zotero search "$ZKEY"); then
      echo "Nothing in the Zotero library matches '$ZKEY'." >&2
      exit 1
    fi
    printf '\n%-24s %-6s %-30s %s\n' "KEY" "YEAR" "AUTHOR" "TITLE" >&2
    while IFS=$'\t' read -r k y a t; do
      printf '%-24s %-6s %-30s %s\n' "$k" "$y" "$a" "$t" >&2
    done <<< "$MATCHES"
    printf '\n' >&2
    ZKEY=$(read_optional "Citation key")
    ZLOOKUP=$(lookup_zotero key "$ZKEY") || {
      echo "No entry with citation key '$ZKEY'." >&2
      exit 1
    }
  fi

  ZKEY_FIELD=""; ZTYPE=""; ZTITLE=""; ZAUTHOR=""; ZPUBLISHER=""
  ZYEAR=""; ZISBN=""; ZDOI=""; ZURL=""
  while IFS=$'\t' read -r key value; do
    case "$key" in
      citation_key) ZKEY_FIELD="$value" ;;
      source_type) ZTYPE="$value" ;;
      title) ZTITLE="$value" ;;
      author) ZAUTHOR="$value" ;;
      publisher) ZPUBLISHER="$value" ;;
      published_year) ZYEAR="$value" ;;
      isbn) ZISBN="$value" ;;
      doi) ZDOI="$value" ;;
      url) ZURL="$value" ;;
    esac
  done <<< "$ZLOOKUP"

  echo "Prefilled from Zotero: [$ZKEY_FIELD] $ZTITLE" >&2

  SOURCE_TYPE=$(read_with_default "Source type [book/article/archive/thesis/dissertation]" "$ZTYPE")
  SOURCE_TYPE=$(trim "$SOURCE_TYPE")
  TITLE=$(read_with_default "Title" "$ZTITLE")
  [[ -z "${TITLE// }" ]] && { echo "Title is required." >&2; exit 1; }
  AUTHOR=$(read_with_default "Author (optional)" "$ZAUTHOR")
  PUBLISHER=$(read_with_default "Publisher/publication (optional)" "$ZPUBLISHER")
  PUBLISHED_YEAR=$(read_with_default "Publication year (optional)" "$ZYEAR")
  FORMAT=""
  ISBN=$(read_with_default "ISBN (optional)" "$ZISBN")
  ISBN=$(normalize_isbn "$ISBN")
  # Zotero carries whichever ISBN was recorded when the work was catalogued,
  # which is no more likely to be one Micro.blog can resolve than a typed one.
  ISBN=$(confirm_isbn_cover "$ISBN")
  DOI=$(normalize_doi "$(read_with_default "DOI (optional)" "$ZDOI")")
  ACCESS_URL=$(read_with_default "Access URL (optional)" "$ZURL")
  ZOTERO_KEY="$ZKEY_FIELD"
fi

if [[ -z "$SOURCE_TYPE" ]]; then
  SOURCE_TYPE=$(read_with_default "Source type [book/article]" "book")
fi
SOURCE_TYPE=$(trim "$SOURCE_TYPE")
case "$SOURCE_TYPE" in
  book|article|archive|thesis|dissertation) ;;
  *) echo "Unsupported source type: $SOURCE_TYPE" >&2; exit 1 ;;
esac

if [[ -z "${ZOTERO_KEY:-}" ]]; then
AUTHOR=""; PUBLISHER=""; PUBLISHED_YEAR=""; FORMAT=""
ISBN=""; DOI=""; ACCESS_URL=""; LOOKUP_FIRST_YEAR=""

if [[ "$SOURCE_TYPE" == "book" ]]; then
  LOOKUP_TITLE=""; LOOKUP_AUTHOR=""; LOOKUP_PUBLISHER=""; LOOKUP_PUBLISHED_YEAR=""
  LOOKUP_FIRST_YEAR=""

  ISBN_INPUT=$(read_optional "ISBN (optional, used for Open Library lookup)")
  ISBN=$(normalize_isbn "$ISBN_INPUT")
  # Checked before the Open Library lookup so a re-entered ISBN is the one that
  # prefills the metadata below.
  ISBN=$(confirm_isbn_cover "$ISBN")
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
      LOOKUP_FIRST_YEAR=$(lookup_openlibrary_first_year "$ISBN" || true)
      if [[ -n "$LOOKUP_FIRST_YEAR" && "$LOOKUP_FIRST_YEAR" != "$LOOKUP_PUBLISHED_YEAR" ]]; then
        echo "This edition is $LOOKUP_PUBLISHED_YEAR; the work was first published $LOOKUP_FIRST_YEAR." >&2
      fi
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
fi

# `none` writes no status at all, which is what makes a page a bibliography
# entry rather than a reading event: it keeps its own URL, its backlinks and its
# subjects, but stays off /reading/, which has no date to file it under. See
# docs/reading.md. A Zotero import defaults to `none` because the common case
# there is a work cited in a footnote years ago, not one logged as read today —
# answer `read` and it joins the ledger like any other.
STATUS_DEFAULT="read"
[[ -n "${ZOTERO_KEY:-}" ]] && STATUS_DEFAULT="none"
STATUS=$(read_with_default "Status [read/reading/none]" "$STATUS_DEFAULT")
STATUS=$(trim "$STATUS")
TODAY=$(date +%Y-%m-%d)

STARTED=""; STARTED_ANNOUNCED=""; FINISHED=""; READ_YEAR=""
case "$STATUS" in
  none)
    STATUS=""
    ;;
  reading)
    STARTED=$(read_with_default "Started (YYYY-MM-DD)" "$TODAY")
    # Stamped unconditionally, same as finishsource.sh does for
    # finished_announced: the reading feed's pubDate should read as "just
    # announced" rather than midnight on whatever date was entered above.
    STARTED_ANNOUNCED=$(rfc3339_now)
    ;;
  *)
    STATUS="read"
    FINISHED=$(read_with_default "Finished (YYYY-MM-DD, blank if unknown)" "$TODAY")
    READ_YEAR="${FINISHED%%-*}"
    READ_YEAR=$(read_with_default "Read year (optional)" "$READ_YEAR")
    ;;
esac

TAGS=$(read_optional "Tags, comma-separated (optional; reuse existing tags; new tag only if a second source will share it)")
ERAS=$(read_optional "Eras, comma-separated (optional; a decade like 1970s or a century like 19th Century — reuse existing eras)")

NOTES=$(read_optional "Short note (optional)")

# The folder name IS the key a post references in `sources:`, so it defaults to
# a citation-style lastname+year rather than a title slug — short enough to type
# from memory and stable when a subtitle changes. Anything is accepted as long
# as it urlizes to itself (lowercase, no spaces or underscores).
LOOKUP_FIRST_YEAR="${LOOKUP_FIRST_YEAR:-}"
KEY_AUTHOR=$(printf '%s' "$AUTHOR" \
  | sed 's/ and .*//; s/,.*//' \
  | awk '{ for (i = NF; i > 0; i--) if (length($i) > 2 || $i !~ /^[A-Z]\.?$/) { print $i; exit } }' \
  | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z')
KEY_YEAR="${LOOKUP_FIRST_YEAR:-$PUBLISHED_YEAR}"
SLUG="${KEY_AUTHOR}${KEY_YEAR}"
# Zotero already assigned this work a citation key, and docs/reading.md keeps a
# Zotero-derived source under that key verbatim so the two libraries agree on
# one name. It is still only a default: an auto-generated key like
# zotero-item-602 should be fixed in Zotero rather than published as a URL.
[[ -n "${ZOTERO_KEY:-}" ]] && SLUG="$ZOTERO_KEY"
[[ -z "$SLUG" ]] && SLUG=$(slugify "$TITLE")
[[ -z "$SLUG" ]] && SLUG="untitled-source"
if [[ -n "$LOOKUP_FIRST_YEAR" && "$LOOKUP_FIRST_YEAR" != "$PUBLISHED_YEAR" ]]; then
  echo "Key uses the work's first publication year ($LOOKUP_FIRST_YEAR), not this edition ($PUBLISHED_YEAR)." >&2
fi

# Two works by one author in one year collide on lastname+year. The source that
# was published first keeps the bare key — its /sources/<key>/ URL is already
# out in the world and renaming it would break that — so later arrivals take a
# letter suffix, the ordinary citation convention: egan2023, egan2023a. Rare at
# fifty sources, routine at five hundred, which is why the script proposes the
# next free suffix instead of leaving it to be improvised each time.
if [[ -e "$SOURCES_ROOT/$SLUG/_index.md" ]]; then
  BASE_SLUG="$SLUG"
  for letter in {a..z}; do
    if [[ ! -e "$SOURCES_ROOT/${BASE_SLUG}${letter}/_index.md" ]]; then
      SLUG="${BASE_SLUG}${letter}"
      break
    fi
  done
  # a-z is 26 slots — comfortably more than the two-authors-one-year collision
  # this exists for will ever need, but it is still a hard ceiling with no
  # check on it, so fall through to aa-zz (676 more) before asking for a
  # manual key, on the same reasoning that made a-z automatic instead of
  # manual: the script proposing the next free suffix beats improvising one.
  if [[ "$SLUG" == "$BASE_SLUG" ]]; then
    for l1 in {a..z}; do
      for l2 in {a..z}; do
        if [[ ! -e "$SOURCES_ROOT/${BASE_SLUG}${l1}${l2}/_index.md" ]]; then
          SLUG="${BASE_SLUG}${l1}${l2}"
          break 2
        fi
      done
    done
  fi
  if [[ "$SLUG" == "$BASE_SLUG" ]]; then
    echo "content/sources/$BASE_SLUG/ exists and so does every a-z/aa-zz suffix; enter a key by hand." >&2
  else
    echo "content/sources/$BASE_SLUG/ already exists — proposing $SLUG." >&2
  fi
fi

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
  [[ -n "$STATUS" ]] && printf 'status: "%s"\n' "$STATUS"
  [[ -n "$PUBLISHED_YEAR" ]] && printf 'published_year: %s\n' "$PUBLISHED_YEAR"
  [[ -n "$READ_YEAR" ]] && printf 'read_year: %s\n' "$READ_YEAR"
  field "publisher" "$PUBLISHER"
  field "format" "$FORMAT"
  field "isbn" "$ISBN"
  field "doi" "$DOI"
  field "access_url" "$ACCESS_URL"
  field "started" "$STARTED"
  field "started_announced" "$STARTED_ANNOUNCED"
  field "finished" "$FINISHED"
  list_field "tags" "$TAGS"
  list_field "eras" "$ERAS"
  printf -- '---\n\n'
  [[ -n "$NOTES" ]] && printf '%s\n' "$NOTES"
} > "$DEST/_index.md"

echo "Created content/sources/$SLUG/_index.md" >&2
echo "Connect writing to it with: sources: [\"$SLUG\"]" >&2
EDITOR_CMD="${VISUAL:-${EDITOR:-vi}}"
exec $EDITOR_CMD "$DEST/_index.md"
