#!/usr/bin/env bash
# Publish an Obsidian draft into the Hugo content tree.
#
# Drafts live in the Obsidian vault (~/Notes/04 Blog/Drafts by default), outside
# the repo. Override with WEBSITE_DRAFTS_DIR. Draft layout:
#   <drafts>/articles/YYYY-MM-DD-slug.md -> content/articles/YYYY-MM-DD-slug/index.md
#   <drafts>/reviews/YYYY-MM-DD-slug.md  -> content/reviews/YYYY-MM-DD-slug/index.md
#   <drafts>/quotes/YYYY-MM-DD-slug.md   -> content/quotes/YYYY-MM-DD-slug.md
#
# On publish, citation keys used in the body (pandoc [@key] citations or a
# <!-- cite: @key --> comment) can be rendered as a Works Cited list. With
# --cite, a Chicago "Works Cited" list is appended to articles and reviews.
# With --push, scripts/ship.sh runs immediately after (preflight, commit, push)
# instead of leaving the change for a later scripts/ship.sh call — skip this if
# the post still needs scripts/add-images.sh before it's ready to go live.

set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [--cite] [--push] <articles|reviews|quotes>/YYYY-MM-DD-slug.md

Moves an Obsidian draft (from the vault drafts folder, or an absolute path) into
the Hugo content tree and sets draft: false. Articles and reviews publish as Hugo
page bundles; quotes publish as flat files.

  --cite   Also append a rendered "Works Cited" list (articles and reviews only).
  --push   Also run scripts/ship.sh (preflight, commit, push) once published.
EOF
  exit 1
}

CITE=false
PUSH=false
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cite) CITE=true; shift ;;
    --push) PUSH=true; shift ;;
    -*) echo "Unknown option: $1" >&2; usage ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
[[ ${#ARGS[@]} -eq 1 ]] || usage

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/lib.sh"

# Drafts live in the Obsidian vault, outside the repo. Override with WEBSITE_DRAFTS_DIR.
DRAFTS_ROOT="${WEBSITE_DRAFTS_DIR:-$HOME/Notes/04 Blog/Drafts}"

DRAFT_INPUT="${ARGS[0]}"
case "$DRAFT_INPUT" in
  /*)       DRAFT_PATH="$DRAFT_INPUT" ;;
  drafts/*) DRAFT_PATH="$DRAFTS_ROOT/${DRAFT_INPUT#drafts/}" ;;  # legacy in-repo layout
  *)        DRAFT_PATH="$DRAFTS_ROOT/$DRAFT_INPUT" ;;
esac

[[ -f "$DRAFT_PATH" ]] || { echo "Draft not found: $DRAFT_INPUT" >&2; exit 1; }

case "$DRAFT_PATH" in
  "$DRAFTS_ROOT"/articles/*.md)
    SECTION="articles"
    TARGET_DIR="$REPO_ROOT/content/articles/$(basename "$DRAFT_PATH" .md)"
    TARGET_PATH="$TARGET_DIR/index.md"
    ;;
  "$DRAFTS_ROOT"/reviews/*.md)
    SECTION="reviews"
    TARGET_DIR="$REPO_ROOT/content/reviews/$(basename "$DRAFT_PATH" .md)"
    TARGET_PATH="$TARGET_DIR/index.md"
    ;;
  "$DRAFTS_ROOT"/quotes/*.md)
    SECTION="quotes"
    TARGET_DIR="$REPO_ROOT/content/quotes"
    TARGET_PATH="$TARGET_DIR/$(basename "$DRAFT_PATH")"
    ;;
  *)
    echo "Draft must live under $DRAFTS_ROOT in articles/, reviews/, or quotes/." >&2
    exit 1
    ;;
esac

[[ ! -e "$TARGET_PATH" ]] || { echo "Refusing to overwrite existing content: $TARGET_PATH" >&2; exit 1; }

TMP_FILE="$(mktemp)"
PUBLISH_DATE="$(rfc3339_now)"
awk -v publish_date="$PUBLISH_DATE" '
  NR == 1 && $0 == "---" {
    in_yaml = 1
    saw_yaml = 1
    print
    next
  }

  NR == 1 {
    print "---"
    print "draft: false"
    print "publishDate: \"" publish_date "\""
    print "lastmod: \"" publish_date "\""
    print "---"
    print ""
    print
    next
  }

  saw_yaml && in_yaml && $0 == "---" {
    if (!saw_draft) {
      print "draft: false"
    }
    if (!saw_publish_date) {
      print "publishDate: \"" publish_date "\""
    }
    if (!saw_lastmod) {
      print "lastmod: \"" publish_date "\""
    }
    in_yaml = 0
    print
    next
  }

  saw_yaml && in_yaml && $0 ~ /^draft:[[:space:]]*/ {
    print "draft: false"
    saw_draft = 1
    next
  }

  saw_yaml && in_yaml && $0 ~ /^publishDate:[[:space:]]*/ {
    saw_publish_date = 1
    print
    next
  }

  saw_yaml && in_yaml && $0 ~ /^lastmod:[[:space:]]*/ {
    saw_lastmod = 1
    print
    next
  }

  { print }
' "$DRAFT_PATH" > "$TMP_FILE"

mkdir -p "$TARGET_DIR"
mv "$TMP_FILE" "$TARGET_PATH"
rm "$DRAFT_PATH"

echo "Published $SECTION draft:"
echo "  $DRAFT_INPUT"
echo "  -> ${TARGET_PATH#$REPO_ROOT/}"

# With --cite, append a rendered Chicago "Works Cited" list to prose posts.
if $CITE; then
  case "$SECTION" in
    articles|reviews)
      REFS="$("$SCRIPT_DIR/cite-refs.sh" --bibliography "$TARGET_PATH" 2>/dev/null || true)"
      if [[ -n "$REFS" ]]; then
        printf '\n## Works Cited\n\n%s\n' "$REFS" >> "$TARGET_PATH"
        echo "  appended Works Cited"
      else
        echo "  --cite: no references rendered (check pandoc and WEBSITE_BIBLIOGRAPHY)"
      fi
      ;;
    *)
      echo "  --cite ignored for $SECTION"
      ;;
  esac
fi

if $PUSH; then
  TITLE="$(sed -n 's/^title: *"\(.*\)"[[:space:]]*$/\1/p' "$TARGET_PATH" | head -1)"
  "$SCRIPT_DIR/ship.sh" "Publish: ${TITLE:-$SECTION post}"
fi
