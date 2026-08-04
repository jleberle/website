#!/usr/bin/env bash
# Scaffold an Obsidian-compatible draft matching the site's conventions.
# Drafts live in the Obsidian vault (~/Notes/07 Blog/Drafts by default), outside
# the repo, until scripts/publish-draft.sh moves them into Hugo content. Articles
# and reviews publish as page bundles; quotes publish as flat files.
# Override the draft location with WEBSITE_DRAFTS_DIR.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <article|review|quote> [--cover] [\"Title\"]" >&2
  echo "Creates an ignored draft under drafts/<articles|reviews|quotes>/." >&2
  exit 1
}

[[ $# -lt 1 ]] && usage
KIND="$1"; shift
case "$KIND" in article|review|quote) ;; *) usage ;; esac

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/lib.sh"

# Drafts live in the Obsidian vault, outside the repo. Override with WEBSITE_DRAFTS_DIR.
DRAFTS_ROOT="${WEBSITE_DRAFTS_DIR:-$HOME/Notes/07 Blog/Drafts}"

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
  TITLE=$(read_optional "Title")
fi
[[ -z "$TITLE" ]] && { echo "Title is required." >&2; exit 1; }

SLUG=$(slugify "$TITLE")
[[ -z "$SLUG" ]] && SLUG="untitled"

# A review's slug names the reviewed work, not the review's own headline: the
# archive publishes "The Rise and Fall of Tucker Carlson" at
# /reviews/zengerle-tucker-carlson/, an author-plus-short-title form that keeps
# the URL stable no matter what the piece ends up being called. Nothing can
# derive that from the title, so offer the title-derived slug as the default and
# let it be typed over. Whatever comes back is slugified, so either
# "zengerle-tucker-carlson" or "Zengerle Tucker Carlson" works.
if [[ "$KIND" == "review" ]]; then
  SLUG=$(slugify "$(read_with_default "Slug" "$SLUG")")
  [[ -z "$SLUG" ]] && SLUG="untitled"
fi

TODAY=$(date +%Y-%m-%d)
NOW=$(rfc3339_now)
BASE="$TODAY-$SLUG"

DESCRIPTION=$(read_optional "Description (optional)")
SUMMARY=$(read_optional "Summary override (optional)")
SERIES=$(read_optional 'Series name, for multi-part posts (optional; same name on every part, e.g. "My Summer With Claude")')
TAGS=$(read_optional "Tags, comma-separated (optional; reuse existing tags; new tag only if a second post will share it)")
ERAS=$(read_optional "Eras, comma-separated (optional; a decade like 1970s or a century like 19th Century — reuse existing eras)")

URL=""
# The work a post is about is named once, by its source key — the directory name
# under content/sources/, a citation-style lastname+year. Its title, author,
# publisher and year live on that page, so nothing here re-types them. A key with
# no page yet is fine: create content/sources/<key>/_index.md and the connection
# starts working.
SOURCES=$(read_optional "Source key(s), comma-separated, e.g. mckenziejones2015 (optional)")
# Must be a subset of SOURCES — labels which of those links the piece is
# centrally about rather than merely cites. A review or quote with exactly one
# source is taken to be about it without this; an article gets no such
# inference, since citing one book in passing is normal there.
ABOUT=$(read_optional "About: which source key(s) this piece is centrally about, comma-separated, subset of the above (optional)")

if [[ "$KIND" == "review" ]]; then
  URL=$(read_optional "Reviewed work URL (optional)")
fi

if [[ "$KIND" == "quote" ]]; then
  URL=$(read_optional "External URL for this passage (optional)")
fi

ADD_COVER=false
COVER_ALT=""
COVER_CAPTION=""
SECTION="${KIND}s"
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
  field "alt" "$COVER_ALT" "  "
  cat <<EOF
  hiddenInList: $hidden_in_list
  hiddenInSingle: false
EOF
  field "caption" "$COVER_CAPTION" "  "
  printf '  relative: true\n'
}

case "$KIND" in
  article)
    FILE=$(unique_path "$DRAFTS_ROOT/articles/$BASE" ".md")
    mkdir -p "$DRAFTS_ROOT/articles"
    {
      cat <<EOF
---
title: "$(yaml_escape "$TITLE")"
slug: $SLUG
date: "$NOW"
draft: true
EOF
      field "description" "$DESCRIPTION"
      field "summary" "$SUMMARY"
      field "series" "$SERIES"
      list_field "sources" "$SOURCES"
      list_field "about" "$ABOUT"
      list_field "tags" "$TAGS"
      list_field "eras" "$ERAS"
      $ADD_COVER && cover_block false
      printf -- '---\n\n<!-- more -->\n'
    } > "$FILE"
    ;;
  review)
    FILE=$(unique_path "$DRAFTS_ROOT/reviews/$BASE" ".md")
    mkdir -p "$DRAFTS_ROOT/reviews"
    {
      cat <<EOF
---
title: "$(yaml_escape "$TITLE")"
slug: $SLUG
date: "$NOW"
draft: true
EOF
      field "description" "$DESCRIPTION"
      field "summary" "$SUMMARY"
      field "series" "$SERIES"
      list_field "sources" "$SOURCES"
      list_field "about" "$ABOUT"
      field "external_url" "$URL"
      list_field "tags" "$TAGS"
      list_field "eras" "$ERAS"
      $ADD_COVER && cover_block true
      printf -- '---\n\n<!-- more -->\n'
    } > "$FILE"
    ;;
  quote)
    FILE=$(unique_path "$DRAFTS_ROOT/quotes/$BASE" ".md")
    mkdir -p "$DRAFTS_ROOT/quotes"
    {
      cat <<EOF
---
title: "$(yaml_escape "$TITLE")"
slug: $SLUG
date: "$NOW"
draft: true
EOF
      field "description" "$DESCRIPTION"
      field "summary" "$SUMMARY"
      field "series" "$SERIES"
      list_field "sources" "$SOURCES"
      list_field "about" "$ABOUT"
      field "external_url" "$URL"
      list_field "tags" "$TAGS"
      list_field "eras" "$ERAS"
      printf -- '---\n\n<!-- more -->\n'
    } > "$FILE"
    ;;
esac

if $ADD_COVER; then
  echo "After publishing, add the cover with: scripts/add-images.sh content/$SECTION/$BASE --cover <image>" >&2
fi
echo "Created draft: ${FILE#$DRAFTS_ROOT/}" >&2
echo "Publish with: scripts/publish-draft.sh \"$FILE\"" >&2
EDITOR_CMD="${VISUAL:-${EDITOR:-vi}}"
exec $EDITOR_CMD "$FILE"
