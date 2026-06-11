#!/usr/bin/env bash
# Scaffold a new post matching the site's conventions — the CLI sibling of the
# Obsidian Templater templates in _templates/:
#
#   article → bundle  content/articles/YYYY-MM-DD-slug/index.md
#             (cover block only with --cover; pairs with add-images.sh)
#   review  → bundle  content/reviews/YYYY-MM-DD-slug/index.md  (cover block always)
#   quote   → flat    content/quotes/YYYY-MM-DD-slug.md
#             (always has external_url; prompted, left empty to fill in the editor)
#
# The slug front-matter field keeps the date prefix out of the URL.
#
# Usage:
#   scripts/newpost.sh article [--cover] ["Title"]
#   scripts/newpost.sh review ["Title"]
#   scripts/newpost.sh quote ["Title"]

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

if [[ -z "$TITLE" ]]; then
  read -r -p "Title: " TITLE || TITLE=""
fi
[[ -z "$TITLE" ]] && { echo "Title is required." >&2; exit 1; }

URL=""
if [[ "$KIND" == "quote" ]]; then
  read -r -p "External URL (Enter to fill in later): " URL || URL=""
fi

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | \
    sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}
SLUG=$(slugify "$TITLE")
[[ -z "$SLUG" ]] && SLUG="untitled"

yaml_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

TODAY=$(date +%Y-%m-%d)
BASE="$TODAY-$SLUG"

unique_path() {
  local candidate="$1" suffix="$2" n=2
  local try="$candidate$suffix"
  while [[ -e "$try" ]]; do
    try="$candidate-$n$suffix"
    n=$((n+1))
  done
  printf '%s' "$try"
}

# article covers show in lists (matching existing articles); review covers don't
cover_block() {
  local hidden_in_list="$1"
  cat <<EOF
cover:
  image: "cover.avif"
  alt: ""
  hiddenInList: $hidden_in_list
  hiddenInSingle: false
  caption: ""
  relative: true # To use relative path for cover image, used in hugo Page-bundles
EOF
}

case "$KIND" in
  article)
    DIR=$(unique_path "$REPO_ROOT/content/articles/$BASE" "")
    FILE="$DIR/index.md"
    mkdir -p "$DIR"
    {
      cat <<EOF
---
author: Jared L. Eberle
categories:
-
date: $TODAY
tags:
-
title: "$(yaml_escape "$TITLE")"
slug: $SLUG
description: ""
summary: ""
EOF
      $COVER && cover_block false
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
categories:
- Reviews
tags:
-
draft: false
date: $TODAY
title: "$(yaml_escape "$TITLE")"
summary: "Review of "
EOF
      cover_block true
      cat <<EOF
slug: $SLUG
description: "Review of "
---

EOF
    } > "$FILE"
    ;;
  quote)
    FILE=$(unique_path "$REPO_ROOT/content/quotes/$BASE" ".md")
    mkdir -p "$REPO_ROOT/content/quotes"
    cat > "$FILE" <<EOF
---
author: Jared L. Eberle
categories:
-
date: $TODAY
tags:
-
title: "$(yaml_escape "$TITLE")"
slug: $SLUG
external_url: "$(yaml_escape "$URL")"
description: ""
---

EOF
    ;;
esac

if [[ "$KIND" == "review" ]] || { [[ "$KIND" == "article" ]] && $COVER; }; then
  echo "Add the cover with: scripts/add-images.sh ${FILE%/index.md} --cover <image>" >&2
fi
echo "Created $FILE" >&2
EDITOR_CMD="${VISUAL:-${EDITOR:-vi}}"
exec $EDITOR_CMD "$FILE"
