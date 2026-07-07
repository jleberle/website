#!/usr/bin/env bash
# Mark a currently-reading source as finished and update its ledger metadata.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [--push] [collection/slug|slug]" >&2
  echo "Marks data/reading/<type>s/<slug>.yaml as read, sets finished/read_year," >&2
  echo "and rewrites the file in canonical key order." >&2
  echo "  --push  Skip the editor and run scripts/ship.sh (preflight, commit, push)." >&2
  exit 1
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
READING_ROOT="$REPO_ROOT/data/reading"

PUSH=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --push) PUSH=true ;;
    --help|-h) usage ;;
    -*) echo "Unknown option: $arg" >&2; usage ;;
    *) ARGS+=("$arg") ;;
  esac
done
[[ ${#ARGS[@]} -gt 1 ]] && usage
set -- "${ARGS[@]}"

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

list_field() {
  local key="$1" values="$2" item
  [[ -z "$values" ]] && return 0
  printf '%s:\n' "$key"
  while IFS= read -r item; do
    [[ -z "$(trim "$item")" ]] && continue
    printf '  - "%s"\n' "$(yaml_escape "$item")"
  done <<< "$values"
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

extract_list() {
  local key="$1" file="$2"
  awk -v key="$key" '
    $0 ~ "^" key ":" { inlist=1; next }
    inlist && $0 ~ /^  - / {
      item = $0
      sub(/^  - /, "", item)
      if (item ~ /^".*"$/) {
        sub(/^"/, "", item)
        sub(/"$/, "", item)
        gsub(/\\"/, "\"", item)
        gsub(/\\\\/, "\\", item)
      }
      print item
      next
    }
    inlist { exit }
  ' "$file"
}

declare -a CURRENT_FILES=()

list_current_sources() {
  local file slug title index=1 status type collection
  while IFS= read -r file; do
    status=$(extract_value "status" "$file")
    [[ "$status" == "current" ]] || continue
    slug="$(basename "$file" .yaml)"
    title=$(extract_value "title" "$file")
    collection="$(basename "$(dirname "$file")")"
    type=$(extract_value "type" "$file")
    [[ -z "$type" ]] && type="${collection%s}"
    CURRENT_FILES+=("$file")
    printf '  %d. %s [%s] (%s/%s)\n' "$index" "${title:-$slug}" "$type" "$collection" "$slug" >&2
    index=$((index + 1))
  done < <(find "$READING_ROOT" -mindepth 2 -maxdepth 2 -name '*.yaml' | sort)
}

resolve_source_file() {
  local input="$1" slug collection file

  if [[ -n "$input" ]]; then
    if [[ "$input" == */* ]]; then
      collection="${input%%/*}"
      slug="${input##*/}"
      slug="${slug%.yaml}"
      file="$READING_ROOT/$collection/$slug.yaml"
      [[ -f "$file" ]] || {
        echo "Source not found: data/reading/$collection/$slug.yaml" >&2
        exit 1
      }
      printf '%s' "$file"
      return 0
    fi

    slug="${input%.yaml}"
    matches=()
    while IFS= read -r match; do
      matches+=("$match")
    done < <(find "$READING_ROOT" -mindepth 2 -maxdepth 2 -name "$slug.yaml" | sort)
    if [[ ${#matches[@]} -eq 1 ]]; then
      printf '%s' "${matches[0]}"
      return 0
    fi
    if [[ ${#matches[@]} -gt 1 ]]; then
      echo "Ambiguous slug '$slug'. Use collection/slug instead:" >&2
      printf '  %s\n' "${matches[@]#$READING_ROOT/}" >&2
      exit 1
    fi
    echo "Source not found: $slug" >&2
    exit 1
  fi

  list_current_sources
  [[ ${#CURRENT_FILES[@]} -gt 0 ]] || {
    echo "No sources are currently marked status: \"current\"." >&2
    exit 1
  }

  local choice
  choice=$(read_optional "Choose current source by number or collection/slug")
  choice=$(trim "$choice")
  [[ -n "$choice" ]] || {
    echo "A selection is required." >&2
    exit 1
  }

  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#CURRENT_FILES[@]} )); then
    printf '%s' "${CURRENT_FILES[$((choice - 1))]}"
    return 0
  fi

  resolve_source_file "$choice"
}

SOURCE_FILE="$(resolve_source_file "${1:-}")"
SOURCE_STATUS="$(extract_value "status" "$SOURCE_FILE")"
SOURCE_TITLE="$(extract_value "title" "$SOURCE_FILE")"
SOURCE_COLLECTION="$(basename "$(dirname "$SOURCE_FILE")")"
SOURCE_TYPE="$(extract_value "type" "$SOURCE_FILE")"
[[ -z "$SOURCE_TYPE" ]] && SOURCE_TYPE="${SOURCE_COLLECTION%s}"

[[ "$SOURCE_STATUS" == "current" ]] || {
  echo "\"${SOURCE_TITLE:-$(basename "$SOURCE_FILE" .yaml)}\" is not marked current." >&2
  echo "Current status: ${SOURCE_STATUS:-<empty>}" >&2
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

AUTHOR="$(extract_value "author" "$SOURCE_FILE")"
CITE_KEY="$(extract_value "cite_key" "$SOURCE_FILE")"
PUBLISHED_YEAR="$(extract_value "published_year" "$SOURCE_FILE")"
STARTED="$(extract_value "started" "$SOURCE_FILE")"
STARTED_ANNOUNCED="$(extract_value "started_announced" "$SOURCE_FILE")"
NOTES="$(extract_value "notes" "$SOURCE_FILE")"
RELATED_POSTS="$(extract_list "related_posts" "$SOURCE_FILE")"
FINISHED_ANNOUNCED="$(current_timestamp)"

PUBLISHER="$(extract_value "publisher" "$SOURCE_FILE")"
ISBN="$(extract_value "isbn" "$SOURCE_FILE")"
FORMAT="$(extract_value "format" "$SOURCE_FILE")"
CONTAINER_TITLE="$(extract_value "container_title" "$SOURCE_FILE")"
VOLUME="$(extract_value "volume" "$SOURCE_FILE")"
ISSUE="$(extract_value "issue" "$SOURCE_FILE")"
PAGES="$(extract_value "pages" "$SOURCE_FILE")"
DOI="$(extract_value "doi" "$SOURCE_FILE")"
URL="$(extract_value "url" "$SOURCE_FILE")"

TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

{
  field "title" "$SOURCE_TITLE"
  field "author" "$AUTHOR"
  field "type" "$SOURCE_TYPE"
  field "cite_key" "$CITE_KEY"
  field "status" "read"
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
  list_field "related_posts" "$RELATED_POSTS"
} > "$TMP_FILE"

mv "$TMP_FILE" "$SOURCE_FILE"
trap - EXIT

echo "Updated ${SOURCE_FILE#$REPO_ROOT/}" >&2
echo "  status: read" >&2
echo "  read_year: $READ_YEAR" >&2
echo "  finished: $FINISHED" >&2

if [[ -n "$CITE_KEY" ]]; then
  VAULT="${WEBSITE_VAULT_DIR:-$HOME/Notes}"
  NOTES_SUB="${WEBSITE_READING_NOTES_DIR:-02 Notes/01 Reading Notes}"
  VAULT_NOTE="$VAULT/$NOTES_SUB/$CITE_KEY.md"
  if [[ "$(python3 "$SCRIPT_DIR/sync-vault-status.py" "$VAULT_NOTE" "read")" == "updated" ]]; then
    echo "  vault note: $CITE_KEY status -> read" >&2
  fi
fi

if $PUSH; then
  "$SCRIPT_DIR/ship.sh" "Finished reading: ${SOURCE_TITLE:-$(basename "$SOURCE_FILE" .yaml)}"
else
  ${VISUAL:-${EDITOR:-vi}} "$SOURCE_FILE"
fi
