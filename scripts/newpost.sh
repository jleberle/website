#!/usr/bin/env bash
# Scaffold an Obsidian-compatible draft matching the site's conventions.
# Drafts live in the Obsidian vault (~/Notes/07 Blog/Drafts by default), outside
# the repo, until scripts/publish-draft.sh moves them into Hugo content. Articles
# and reviews publish as page bundles; quotes publish as flat files.
# Override the draft location with WEBSITE_DRAFTS_DIR.
#
# THIS IS THE ONLY IMPLEMENTATION of what a draft looks like — the slug rule,
# the field order, the collision behaviour. The Obsidian Templater templates in
# templates/obsidian/ used to reimplement all of it in JavaScript, kept aligned
# by comments asking the next editor to keep them aligned. They now collect
# their prompts (Obsidian's suggester is nicer than a bash read) and shell out
# here for the answer, which is what --print and --print-target exist for.
#
# Every prompt has a matching flag, so any front door can supply what it already
# knows and be asked only for the rest. Supplying a flag suppresses its prompt;
# --batch suppresses every remaining prompt, taking the empty string for
# anything not given.
#
# Usage:
#   scripts/newpost.sh <article|review|quote> [--cover] ["Title"]
#   scripts/newpost.sh article --batch --title "T" --tags "Rodeo" --print
#   scripts/newpost.sh article --batch --title "T" --print-target
#
# Modes:
#   (default)       write the draft, then open it in $EDITOR
#   --no-edit       write the draft, print its path, don't open an editor
#   --print         write nothing; emit the draft's text on stdout
#   --print-target  write nothing; emit the draft's path relative to the drafts
#                   root, collisions already resolved
#   --print-slug    write nothing; emit the slug this title would get

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") <article|review|quote> [--cover] [\"Title\"]" >&2
  echo "Creates an ignored draft under drafts/<articles|reviews|quotes>/." >&2
  echo >&2
  echo "Non-interactive (for other front doors):" >&2
  echo "  --batch                  never prompt; unsupplied fields stay empty" >&2
  echo "  --title/--slug/--description/--summary/--series/--tags/--eras" >&2
  echo "  --sources/--about/--url  same meanings as the prompts" >&2
  echo "  --cover-alt/--cover-caption   imply --cover" >&2
  echo "  --print                  emit the draft text instead of writing it" >&2
  echo "  --print-target           emit the resolved draft path, nothing else" >&2
  echo "  --print-slug             emit the slug this title would get, nothing else" >&2
  echo "  --no-edit                write the draft but don't open an editor" >&2
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
BATCH=false
MODE=write          # write | print | print-target | print-slug
EDIT=true
TITLE=""

# Each field tracks whether it was SUPPLIED separately from whether it is
# non-empty: an explicit --description "" is an answer ("leave it out"), and
# re-prompting for it would defeat the point of a non-interactive caller.
SLUG_IN=""; SLUG_SET=false
DESCRIPTION=""; DESCRIPTION_SET=false
SUMMARY=""; SUMMARY_SET=false
SERIES=""; SERIES_SET=false
TAGS=""; TAGS_SET=false
ERAS=""; ERAS_SET=false
SOURCES=""; SOURCES_SET=false
ABOUT=""; ABOUT_SET=false
URL=""; URL_SET=false
COVER_ALT=""; COVER_CAPTION=""

need_value() { [[ $# -ge 2 ]] || { echo "$1 needs a value." >&2; usage; }; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cover) COVER=true; shift ;;
    --batch) BATCH=true; shift ;;
    --print) MODE=print; shift ;;
    --print-target) MODE=print-target; shift ;;
    --print-slug) MODE=print-slug; shift ;;
    --no-edit) EDIT=false; shift ;;
    --title) need_value "$1" "${2:-}"; TITLE="$2"; shift 2 ;;
    --slug) need_value "$1" "${2:-}"; SLUG_IN="$2"; SLUG_SET=true; shift 2 ;;
    --description) DESCRIPTION="${2:-}"; DESCRIPTION_SET=true; shift 2 ;;
    --summary) SUMMARY="${2:-}"; SUMMARY_SET=true; shift 2 ;;
    --series) SERIES="${2:-}"; SERIES_SET=true; shift 2 ;;
    --tags) TAGS="${2:-}"; TAGS_SET=true; shift 2 ;;
    --eras) ERAS="${2:-}"; ERAS_SET=true; shift 2 ;;
    --sources) SOURCES="${2:-}"; SOURCES_SET=true; shift 2 ;;
    --about) ABOUT="${2:-}"; ABOUT_SET=true; shift 2 ;;
    --url) URL="${2:-}"; URL_SET=true; shift 2 ;;
    --cover-alt) COVER_ALT="${2:-}"; COVER=true; shift 2 ;;
    --cover-caption) COVER_CAPTION="${2:-}"; COVER=true; shift 2 ;;
    --help|-h) usage ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *)
      [[ -n "$TITLE" ]] && usage
      TITLE="$1"; shift ;;
  esac
done

# --print and --print-target must not write, so they must not open an editor.
[[ "$MODE" == write ]] || EDIT=false

# ask <varname> <already-supplied?> <prompt> — prompts only when the caller
# didn't supply the field and isn't in batch mode.
ask() {
  local var="$1" supplied="$2" prompt="$3"
  $supplied && return 0
  $BATCH && return 0
  printf -v "$var" '%s' "$(read_optional "$prompt")"
}

if [[ -z "$TITLE" ]] && ! $BATCH; then
  TITLE=$(read_optional "Title")
fi
[[ -z "$TITLE" ]] && { echo "Title is required (pass --title)." >&2; exit 1; }

SLUG=$(slugify "$TITLE")
[[ -z "$SLUG" ]] && SLUG="untitled"
if $SLUG_SET; then
  SLUG=$(slugify "$SLUG_IN")
  [[ -z "$SLUG" ]] && SLUG="untitled"
fi

# --print-slug answers "what slug would this title get?" and stops. It exists
# so another front door can offer the same default a terminal user is offered,
# without reimplementing slugify to do it.
if [[ "$MODE" == print-slug ]]; then
  printf '%s\n' "$SLUG"
  exit 0
fi

# A review's slug names the reviewed work, not the review's own headline: the
# archive publishes "The Rise and Fall of Tucker Carlson" at
# /reviews/zengerle-tucker-carlson/, an author-plus-short-title form that keeps
# the URL stable no matter what the piece ends up being called. Nothing can
# derive that from the title, so offer the title-derived slug as the default and
# let it be typed over. Whatever comes back is slugified, so either
# "zengerle-tucker-carlson" or "Zengerle Tucker Carlson" works.
if [[ "$KIND" == "review" ]] && ! $SLUG_SET && ! $BATCH; then
  SLUG=$(slugify "$(read_with_default "Slug" "$SLUG")")
  [[ -z "$SLUG" ]] && SLUG="untitled"
fi

TODAY=$(date +%Y-%m-%d)
NOW=$(rfc3339_now)
BASE="$TODAY-$SLUG"

ask DESCRIPTION $DESCRIPTION_SET "Description (optional)"
ask SUMMARY $SUMMARY_SET "Summary override (optional)"
ask SERIES $SERIES_SET 'Series name, for multi-part posts (optional; same name on every part, e.g. "My Summer With Claude")'
ask TAGS $TAGS_SET "Tags, comma-separated (optional; reuse existing tags; new tag only if a second post will share it)"
ask ERAS $ERAS_SET "Eras, comma-separated (optional; a decade like 1970s or a century like 19th Century — reuse existing eras)"

# The work a post is about is named once, by its source key — the directory name
# under content/sources/, a citation-style lastname+year. Its title, author,
# publisher and year live on that page, so nothing here re-types them. A key with
# no page yet is fine: create content/sources/<key>/_index.md and the connection
# starts working.
ask SOURCES $SOURCES_SET "Source key(s), comma-separated, e.g. mckenziejones2015 (optional)"
# Must be a subset of SOURCES — labels which of those links the piece is
# centrally about rather than merely cites. A review or quote with exactly one
# source is taken to be about it without this; an article gets no such
# inference, since citing one book in passing is normal there.
ask ABOUT $ABOUT_SET "About: which source key(s) this piece is centrally about, comma-separated, subset of the above (optional)"

if [[ "$KIND" == "review" ]]; then
  ask URL $URL_SET "Reviewed work URL (optional)"
fi

if [[ "$KIND" == "quote" ]]; then
  ask URL $URL_SET "External URL for this passage (optional)"
fi

ADD_COVER=false
SECTION="${KIND}s"
if [[ "$KIND" != "quote" ]]; then
  if $COVER; then
    ADD_COVER=true
  elif ! $BATCH; then
    read -r -p "Add cover metadata? [y/N]: " COVER_ANSWER || COVER_ANSWER=""
    case "$COVER_ANSWER" in
      y|Y|yes|YES|Yes) ADD_COVER=true ;;
    esac
  fi

  if $ADD_COVER && ! $BATCH; then
    [[ -n "$COVER_ALT" ]] || COVER_ALT=$(read_optional "Cover alt text (optional)")
    [[ -n "$COVER_CAPTION" ]] || COVER_CAPTION=$(read_optional "Cover caption (optional)")
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

# One emitter for all three kinds. They previously had a case block each,
# identical but for the cover flag and whether external_url appeared at all —
# and `external_url` was only ever absent from the article block because an
# article never prompted for one. It is emitted here whenever it is non-empty,
# which changes nothing for interactive use and stops --url being silently
# dropped on an article.
emit_draft() {
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
  if $ADD_COVER; then
    [[ "$KIND" == "review" ]] && cover_block true || cover_block false
  fi
  printf -- '---\n\n<!-- more -->\n'
}

FILE=$(unique_path "$DRAFTS_ROOT/$SECTION/$BASE" ".md")

# --print-target hands a caller the path this draft would take, collisions
# already resolved against the drafts root. Templater needs it to place the
# note before it has any content to put in it.
if [[ "$MODE" == print-target ]]; then
  printf '%s\n' "${FILE#"$DRAFTS_ROOT/"}"
  exit 0
fi

if [[ "$MODE" == print ]]; then
  emit_draft
  exit 0
fi

mkdir -p "$DRAFTS_ROOT/$SECTION"
emit_draft > "$FILE"

if $ADD_COVER; then
  echo "After publishing, add the cover with: scripts/add-images.sh content/$SECTION/$BASE --cover <image>" >&2
fi
echo "Created draft: ${FILE#"$DRAFTS_ROOT/"}" >&2
echo "Publish with: scripts/publish-draft.sh \"$FILE\"" >&2

if $EDIT; then
  EDITOR_CMD="${VISUAL:-${EDITOR:-vi}}"
  exec $EDITOR_CMD "$FILE"
fi
