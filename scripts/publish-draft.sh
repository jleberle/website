#!/usr/bin/env bash
# Publish an Obsidian draft into the Hugo content tree.
#
# Draft layout:
#   drafts/articles/YYYY-MM-DD-slug.md  -> content/articles/YYYY-MM-DD-slug/index.md
#   drafts/reviews/YYYY-MM-DD-slug.md   -> content/reviews/YYYY-MM-DD-slug/index.md
#   drafts/quotes/YYYY-MM-DD-slug.md    -> content/quotes/YYYY-MM-DD-slug.md

set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") drafts/<articles|reviews|quotes>/YYYY-MM-DD-slug.md

Moves an ignored Obsidian draft into the Hugo content tree and sets draft: false.
Articles and reviews publish as Hugo page bundles; quotes publish as flat files.
EOF
  exit 1
}

[[ $# -eq 1 ]] || usage

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"

DRAFT_INPUT="$1"
case "$DRAFT_INPUT" in
  /*) DRAFT_PATH="$DRAFT_INPUT" ;;
  *) DRAFT_PATH="$REPO_ROOT/$DRAFT_INPUT" ;;
esac

[[ -f "$DRAFT_PATH" ]] || { echo "Draft not found: $DRAFT_INPUT" >&2; exit 1; }

case "$DRAFT_PATH" in
  "$REPO_ROOT"/drafts/articles/*.md)
    SECTION="articles"
    TARGET_DIR="$REPO_ROOT/content/articles/$(basename "$DRAFT_PATH" .md)"
    TARGET_PATH="$TARGET_DIR/index.md"
    ;;
  "$REPO_ROOT"/drafts/reviews/*.md)
    SECTION="reviews"
    TARGET_DIR="$REPO_ROOT/content/reviews/$(basename "$DRAFT_PATH" .md)"
    TARGET_PATH="$TARGET_DIR/index.md"
    ;;
  "$REPO_ROOT"/drafts/quotes/*.md)
    SECTION="quotes"
    TARGET_DIR="$REPO_ROOT/content/quotes"
    TARGET_PATH="$TARGET_DIR/$(basename "$DRAFT_PATH")"
    ;;
  *)
    echo "Draft must live in drafts/articles, drafts/reviews, or drafts/quotes." >&2
    exit 1
    ;;
esac

[[ ! -e "$TARGET_PATH" ]] || { echo "Refusing to overwrite existing content: $TARGET_PATH" >&2; exit 1; }

TMP_FILE="$(mktemp)"
awk '
  NR == 1 && $0 == "---" {
    in_yaml = 1
    saw_yaml = 1
    print
    next
  }

  NR == 1 {
    print "---"
    print "draft: false"
    print "---"
    print ""
    print
    next
  }

  saw_yaml && in_yaml && $0 == "---" {
    if (!saw_draft) {
      print "draft: false"
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

  { print }
' "$DRAFT_PATH" > "$TMP_FILE"

mkdir -p "$TARGET_DIR"
mv "$TMP_FILE" "$TARGET_PATH"
rm "$DRAFT_PATH"

echo "Published $SECTION draft:"
echo "  $DRAFT_INPUT"
echo "  -> ${TARGET_PATH#$REPO_ROOT/}"
