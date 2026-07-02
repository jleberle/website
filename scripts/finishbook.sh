#!/usr/bin/env bash
# Mark a currently-reading book as finished and update its ledger metadata.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [slug]" >&2
  echo "Marks data/reading/books/<slug>.yaml as read, sets finished/read_year," >&2
  echo "and rewrites the file in canonical key order." >&2
  exit 1
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
BOOK_DIR="$REPO_ROOT/data/reading/books"

[[ $# -gt 1 ]] && usage
[[ "${1:-}" == "--help" || "${1:-}" == "-h" ]] && usage

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
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

read_optional() {
  local prompt="$1" value
  read -r -p "$prompt: " value || value=""
  printf '%s' "$value"
}

current_timestamp() {
  date +"%Y-%m-%dT%H:%M:%S%z" | sed -E 's/([0-9]{2})([0-9]{2})$/\1:\2/'
}

extract_value() {
  local key="$1" file="$2" line
  line=$(sed -n "s/^${key}: //p" "$file" | head -n 1)
  [[ -z "$line" ]] && return 0
  if [[ "$line" == \"*\" ]]; then
    line="${line#\"}"
    line="${line%\"}"
    line="${line//\\\"/\"}"
    line="${line//\\\\/\\}"
  fi
  printf '%s' "$line"
}

declare -a CURRENT_FILES=()

list_current_books() {
  local file slug title index=1 status
  for file in "$BOOK_DIR"/*.yaml; do
    [[ -e "$file" ]] || continue
    status=$(extract_value "status" "$file")
    [[ "$status" == "current" ]] || continue
    slug="$(basename "$file" .yaml)"
    title=$(extract_value "title" "$file")
    CURRENT_FILES+=("$file")
    printf '  %d. %s (%s)\n' "$index" "${title:-$slug}" "$slug" >&2
    index=$((index + 1))
  done
}

resolve_book_file() {
  local input="$1" slug file

  if [[ -n "$input" ]]; then
    slug="${input##*/}"
    slug="${slug%.yaml}"
    file="$BOOK_DIR/$slug.yaml"
    [[ -f "$file" ]] || {
      echo "Book not found: data/reading/books/$slug.yaml" >&2
      exit 1
    }
    printf '%s' "$file"
    return 0
  fi

  list_current_books
  [[ ${#CURRENT_FILES[@]} -gt 0 ]] || {
    echo "No books are currently marked status: \"current\"." >&2
    exit 1
  }

  local choice
  choice=$(read_optional "Choose current book by number or slug")
  choice=$(trim "$choice")
  [[ -n "$choice" ]] || {
    echo "A selection is required." >&2
    exit 1
  }

  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#CURRENT_FILES[@]} )); then
    printf '%s' "${CURRENT_FILES[$((choice - 1))]}"
    return 0
  fi

  slug="${choice##*/}"
  slug="${slug%.yaml}"
  file="$BOOK_DIR/$slug.yaml"
  [[ -f "$file" ]] || {
    echo "Book not found: data/reading/books/$slug.yaml" >&2
    exit 1
  }
  printf '%s' "$file"
}

BOOK_FILE="$(resolve_book_file "${1:-}")"
BOOK_STATUS="$(extract_value "status" "$BOOK_FILE")"
BOOK_TITLE="$(extract_value "title" "$BOOK_FILE")"

[[ "$BOOK_STATUS" == "current" ]] || {
  echo "\"${BOOK_TITLE:-$(basename "$BOOK_FILE" .yaml)}\" is not marked current." >&2
  echo "Current status: ${BOOK_STATUS:-<empty>}" >&2
  exit 1
}

TODAY="$(date +%F)"
FINISHED="$(read_optional "Finished date YYYY-MM-DD (default: $TODAY)")"
FINISHED="$(trim "$FINISHED")"
[[ -z "$FINISHED" ]] && FINISHED="$TODAY"

if [[ ! "$FINISHED" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Finished date must look like YYYY-MM-DD." >&2
  exit 1
fi

READ_YEAR="${FINISHED%%-*}"

AUTHOR="$(extract_value "author" "$BOOK_FILE")"
CITE_KEY="$(extract_value "cite_key" "$BOOK_FILE")"
PUBLISHED_YEAR="$(extract_value "published_year" "$BOOK_FILE")"
PUBLISHER="$(extract_value "publisher" "$BOOK_FILE")"
ISBN="$(extract_value "isbn" "$BOOK_FILE")"
FORMAT="$(extract_value "format" "$BOOK_FILE")"
STARTED="$(extract_value "started" "$BOOK_FILE")"
STARTED_ANNOUNCED="$(extract_value "started_announced" "$BOOK_FILE")"
NOTES="$(extract_value "notes" "$BOOK_FILE")"
FINISHED_ANNOUNCED="$(current_timestamp)"

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

{
  field "title" "$BOOK_TITLE"
  field "author" "$AUTHOR"
  field "cite_key" "$CITE_KEY"
  field "status" "read"
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
} > "$TMP_FILE"

mv "$TMP_FILE" "$BOOK_FILE"
trap - EXIT

echo "Updated ${BOOK_FILE#$REPO_ROOT/}" >&2
echo "  status: read" >&2
echo "  read_year: $READ_YEAR" >&2
echo "  finished: $FINISHED" >&2
${VISUAL:-${EDITOR:-vi}} "$BOOK_FILE"
