#!/usr/bin/env bash
# Scaffold a new post matching the site's conventions: articles and reviews are
# Hugo page bundles, while quotes are flat files. This is the CLI sibling of the
# Obsidian Templater templates in _templates/.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <article|review|quote> [--cover] [\"Title\"]" >&2
  exit 1
}

[[ $# -lt 1 ]] && usage
KIND="$1"; shift
case "$KIND" in article|review|quote) ;; *) usage ;; esac

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"

COVER=false
TITLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cover) COVER=true; shift ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *)
      [[ -n "$TITLE" ]] && usage
      TITLE="$1"; shift ;;
  esac
done

read_optional() {
  local prompt="$1" value
  read -r -p "$prompt: " value || value=""
  printf '%s' "$value"
}

if [[ -z "$TITLE" ]]; then
  TITLE=$(read_optional "Title")
fi
[[ -z "$TITLE" ]] && { echo "Title is required." >&2; exit 1; }

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

field() {
  local key="$1" value
  value=$(trim "$2")
  [[ -z "$value" ]] && return 0
  printf '%s: "%s"\n' "$key" "$(yaml_escape "$value")"
}

indented_field() {
  local key="$1" value
  value=$(trim "$2")
  [[ -z "$value" ]] && return 0
  printf '  %s: "%s"\n' "$key" "$(yaml_escape "$value")"
}

list_field() {
  local key="$1" raw="$2" item printed=false
  IFS=',' read -r -a items <<< "$raw"
  for item in "${items[@]}"; do
    item=$(trim "$item")
    [[ -z "$item" ]] && continue
    if ! $printed; then
      printf '%s:\n' "$key"
      printed=true
    fi
    printf -- '- "%s"\n' "$(yaml_escape "$item")"
  done
}

SLUG=$(slugify "$TITLE")
[[ -z "$SLUG" ]] && SLUG="untitled"
TODAY=$(date +%Y-%m-%d)
BASE="$TODAY-$SLUG"

DESCRIPTION=$(read_optional "Description (optional)")
SUMMARY=$(read_optional "Summary override (optional)")
TAGS=$(read_optional "Tags, comma-separated (optional)")

REVIEWED_TYPE=""
REVIEWED_TITLE=""
REVIEWED_AUTHOR=""
REVIEWED_PUBLISHER=""
REVIEWED_YEAR=""
SOURCE_TITLE=""
SOURCE_AUTHOR=""
SOURCE_YEAR=""
URL=""

if [[ "$KIND" == "review" ]]; then
  REVIEWED_TYPE=$(read_optional "Reviewed type, e.g. Book/Film (optional)")
  REVIEWED_TITLE=$(read_optional "Reviewed work title (optional)")
  REVIEWED_AUTHOR=$(read_optional "Reviewed work author/creator (optional)")
  REVIEWED_PUBLISHER=$(read_optional "Reviewed work publisher/studio (optional)")
  REVIEWED_YEAR=$(read_optional "Reviewed work year (optional)")
  URL=$(read_optional "Reviewed work URL (optional)")
  CATEGORIES=$(read_optional "Categories, comma-separated (optional; defaults to Reviews)")
  [[ -z "$CATEGORIES" ]] && CATEGORIES="Reviews"
else
  CATEGORIES=$(read_optional "Categories, comma-separated (optional)")
fi

if [[ "$KIND" == "quote" ]]; then
  SOURCE_TITLE=$(read_optional "Source title (optional)")
  SOURCE_AUTHOR=$(read_optional "Source author (optional)")
  SOURCE_YEAR=$(read_optional "Source year (optional)")
  URL=$(read_optional "External URL (optional)")
fi

ADD_COVER=false
COVER_ALT=""
COVER_CAPTION=""
if [[ "$KIND" != "quote" ]]; then
  if $COVER; then
    ADD_COVER=true
  else
    read -r -p "Add cover metadata? [y/N]: " COVER_ANSWER || COVER_ANSWER=""
    case "$COVER_ANSWER" in
      y|Y|yes|YES|Yes) ADD_COVER=true ;;
    esac
  fi

  if $ADD_COVER; then
    COVER_ALT=$(read_optional "Cover alt text (optional)")
    COVER_CAPTION=$(read_optional "Cover caption (optional)")
  fi
fi

unique_path() {
  local candidate="$1" suffix="$2" n=2
  local try="$candidate$suffix"
  while [[ -e "$try" ]]; do
    try="$candidate-$n$suffix"
    n=$((n+1))
  done
  printf '%s' "$try"
}

# Article covers show in lists; review covers stay hidden in list pages.
cover_block() {
  local hidden_in_list="$1"
  cat <<EOF
cover:
  image: "cover.avif"
EOF
  indented_field "alt" "$COVER_ALT"
  cat <<EOF
  hiddenInList: $hidden_in_list
  hiddenInSingle: false
EOF
  indented_field "caption" "$COVER_CAPTION"
  printf '  relative: true\n'
}

case "$KIND" in
  article)
    DIR=$(unique_path "$REPO_ROOT/content/articles/$BASE" "")
    FILE="$DIR/index.md"
    mkdir -p "$DIR"
    {
      cat <<EOF
---
title: "$(yaml_escape "$TITLE")"
slug: $SLUG
date: $TODAY
author: Jared L. Eberle
EOF
      field "description" "$DESCRIPTION"
      field "summary" "$SUMMARY"
      list_field "categories" "$CATEGORIES"
      list_field "tags" "$TAGS"
      $ADD_COVER && cover_block false
      printf -- '---\n\n'
    } > "$FILE"
    ;;
  review)
    DIR=$(unique_path "$REPO_ROOT/content/reviews/$BASE" "")
    FILE="$DIR/index.md"
    mkdir -p "$DIR"
    {
      cat <<EOF
---
title: "$(yaml_escape "$TITLE")"
slug: $SLUG
date: $TODAY
draft: false
EOF
      field "description" "$DESCRIPTION"
      field "summary" "$SUMMARY"
      field "reviewed_type" "$REVIEWED_TYPE"
      field "reviewed_title" "$REVIEWED_TITLE"
      field "reviewed_author" "$REVIEWED_AUTHOR"
      field "reviewed_publisher" "$REVIEWED_PUBLISHER"
      field "reviewed_year" "$REVIEWED_YEAR"
      field "external_url" "$URL"
      list_field "categories" "$CATEGORIES"
      list_field "tags" "$TAGS"
      $ADD_COVER && cover_block true
      printf -- '---\n\n'
    } > "$FILE"
    ;;
  quote)
    FILE=$(unique_path "$REPO_ROOT/content/quotes/$BASE" ".md")
    mkdir -p "$REPO_ROOT/content/quotes"
    {
      cat <<EOF
---
title: "$(yaml_escape "$TITLE")"
slug: $SLUG
date: $TODAY
author: Jared L. Eberle
EOF
      field "description" "$DESCRIPTION"
      field "summary" "$SUMMARY"
      field "source_title" "$SOURCE_TITLE"
      field "source_author" "$SOURCE_AUTHOR"
      field "source_year" "$SOURCE_YEAR"
      field "external_url" "$URL"
      list_field "categories" "$CATEGORIES"
      list_field "tags" "$TAGS"
      printf -- '---\n\n'
    } > "$FILE"
    ;;
esac

if $ADD_COVER; then
  echo "Add the cover with: scripts/add-images.sh ${FILE%/index.md} --cover <image>" >&2
fi
echo "Created $FILE" >&2
EDITOR_CMD="${VISUAL:-${EDITOR:-vi}}"
exec $EDITOR_CMD "$FILE"
