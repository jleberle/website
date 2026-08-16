#!/usr/bin/env bash
# Publish an Obsidian draft into the Hugo content tree.
#
# Drafts live in the Obsidian vault (~/Notes/07 Blog/Drafts by default), outside
# the repo. Override with WEBSITE_DRAFTS_DIR. Draft layout:
#   <drafts>/articles/YYYY-MM-DD-slug.md -> content/articles/YYYY-MM-DD-slug/index.md
#   <drafts>/reviews/YYYY-MM-DD-slug.md  -> content/reviews/YYYY-MM-DD-slug/index.md
#   <drafts>/quotes/YYYY-MM-DD-slug.md   -> content/quotes/YYYY-MM-DD-slug.md
#
# On publish, citation keys used in the body (pandoc [@key] citations or a
# <!-- cite: @key --> comment) can be rendered as a Works Cited list. With
# --cite, a Chicago "Works Cited" list is appended to articles and reviews.
# With --push, scripts/ship.sh runs immediately after (preflight, commit, push)
# instead of leaving the change for a later scripts/ship.sh call.
#
# Body images: Obsidian saves pasted screenshots next to the note itself
# (attachmentFolderPath "./") and links them as vault-root-relative markdown
# image links (newLinkFormat "absolute", useMarkdownLinks true) -- see
# .obsidian/app.json. For articles and reviews, publish-draft.sh resolves
# those links, copies the images into the post bundle, converts them to AVIF
# via scripts/to-avif.sh, rewrites the links to {{< figure >}} shortcodes, and
# removes the originals from the vault.
#
# Cover images: if the draft has both a `cover:` block (from newpost.sh
# --cover) and a `sources:` credit, publish-draft.sh fetches the cover
# automatically via scripts/fetch-cover.py once the bundle directory exists --
# it reads the source's title/author, searches Apple's Books catalogue, and
# writes cover.avif + cover.jpg. Best-effort: a network failure or a title
# with no match warns and leaves the cover: block pointing at a file that
# doesn't exist yet rather than blocking the rest of the publish. A draft
# without sources: (or without a cover: block at all) is untouched, same as
# before -- add one by hand with scripts/fetch-cover.py or
# scripts/add-images.sh --cover.

set -euo pipefail

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") [--cite] [--push] [<articles|reviews|quotes>/YYYY-MM-DD-slug.md]

Moves an Obsidian draft (from the vault drafts folder, or an absolute path) into
the Hugo content tree and sets draft: false. Articles and reviews publish as Hugo
page bundles; quotes publish as flat files.

Called with no path, lists every draft under the drafts folder and prompts for
a number instead — handy when you don't have newpost.sh's printed path handy
anymore (e.g. publishing a day or two later).

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
[[ ${#ARGS[@]} -le 1 ]] || usage

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
source "$SCRIPT_DIR/lib.sh"

# Drafts live in the Obsidian vault, outside the repo. Override with WEBSITE_DRAFTS_DIR.
DRAFTS_ROOT="${WEBSITE_DRAFTS_DIR:-$HOME/Notes/07 Blog/Drafts}"

# No path given: list every draft (newest first) and prompt for one, rather
# than requiring the caller to remember or re-type the vault-relative path.
if [[ ${#ARGS[@]} -eq 0 ]]; then
  # Draft basenames are date-prefixed (YYYY-MM-DD-slug.md), so sorting on the
  # basename (not the full path, which would group by section first) puts
  # them newest-first across all three kinds -- no need to shell out for mtimes.
  DRAFT_FILES=()
  while IFS= read -r -d '' f; do
    DRAFT_FILES+=("$f")
  done < <(
    find "$DRAFTS_ROOT" -mindepth 2 -maxdepth 2 \( -path "*/articles/*.md" -o -path "*/reviews/*.md" -o -path "*/quotes/*.md" \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do printf '%s\t%s\0' "$(basename "$f")" "$f"; done \
      | sort -z -r \
      | while IFS= read -r -d '' pair; do printf '%s\0' "${pair#*$'\t'}"; done
  )

  [[ ${#DRAFT_FILES[@]} -gt 0 ]] || { echo "No drafts found under $DRAFTS_ROOT." >&2; exit 1; }

  echo "Drafts (newest first):" >&2
  DRAFT_LABELS=()
  for f in "${DRAFT_FILES[@]}"; do
    title="$(sed -n 's/^title: *"\(.*\)"[[:space:]]*$/\1/p' "$f" | head -1)"
    rel="${f#"$DRAFTS_ROOT/"}"
    if [[ -n "$title" ]]; then
      DRAFT_LABELS+=("$rel  —  $title")
    else
      DRAFT_LABELS+=("$rel")
    fi
  done

  PS3="Publish which draft? (number, or Ctrl-C to cancel): "
  DRAFT_PATH=""
  select choice in "${DRAFT_LABELS[@]}"; do
    if [[ -n "${choice:-}" ]]; then
      DRAFT_PATH="${DRAFT_FILES[$((REPLY-1))]}"
      break
    fi
    echo "Invalid choice." >&2
  done
  [[ -n "$DRAFT_PATH" ]] || { echo "No draft selected." >&2; exit 1; }
  ARGS=("$DRAFT_PATH")
fi

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

# Carry over and optimize body images (page bundles only -- quotes are flat
# files with no bundle dir to hold them). See the header comment for how
# Obsidian links these.
if [[ "$SECTION" != "quotes" ]]; then
  VAULT_ROOT="${WEBSITE_VAULT_ROOT:-$HOME/Notes}"
  TO_AVIF="$SCRIPT_DIR/to-avif.sh"
  IMAGE_MAP="$(python3 - "$TARGET_PATH" "$VAULT_ROOT" "$(dirname "$DRAFT_PATH")" <<'PY'
import os
import re
import sys
import urllib.parse

target_path, vault_root, draft_dir = sys.argv[1:4]
EXTS = {"jpg", "jpeg", "png", "webp", "avif"}

with open(target_path, "r") as f:
    content = f.read()

seen_stems = set()
resolved = []


def slugify_stem(name):
    stem = os.path.splitext(name)[0].lower()
    stem = re.sub(r"[^a-z0-9]+", "-", stem).strip("-")
    return stem or "image"


def repl(m):
    alt, raw_path = m.group(1), m.group(2)
    if raw_path.startswith(("http://", "https://", "//")):
        return m.group(0)
    decoded = urllib.parse.unquote(raw_path)
    candidates = [
        decoded if os.path.isabs(decoded) else None,
        os.path.join(vault_root, decoded),
        os.path.join(draft_dir, os.path.basename(decoded)),
    ]
    src = next((c for c in candidates if c and os.path.isfile(c)), None)
    if src is None:
        print(f"  warning: could not resolve image, left as-is: {raw_path}", file=sys.stderr)
        return m.group(0)
    ext = os.path.splitext(src)[1].lstrip(".").lower()
    if ext == "jpeg":
        ext = "jpg"
    if ext not in EXTS:
        print(f"  warning: unsupported image format, left as-is: {src}", file=sys.stderr)
        return m.group(0)
    stem = slugify_stem(os.path.basename(src))
    base_stem, n = stem, 2
    while stem in seen_stems:
        stem = f"{base_stem}-{n}"
        n += 1
    seen_stems.add(stem)
    resolved.append((src, ext, stem))
    alt_escaped = alt.replace('"', '\\"')
    return '{{< figure src="' + stem + '.avif" alt="' + alt_escaped + '" align=center >}}'


new_content = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", repl, content)


def ensure_blank_lines_around_figures(text):
    # Figure shortcodes are block-level; html-validate chokes if one lands
    # adjacent to paragraph text with no blank line separating them (the
    # renderer nests it inside the <p>, producing implicitly-closed/stray
    # tags). Force a blank line before and after every figure shortcode line.
    lines = text.split("\n")
    out = []
    for i, line in enumerate(lines):
        is_figure = line.strip().startswith("{{< figure") and line.strip().endswith(">}}")
        if is_figure and out and out[-1].strip() != "":
            out.append("")
        out.append(line)
        if is_figure and i + 1 < len(lines) and lines[i + 1].strip() != "":
            out.append("")
    return "\n".join(out)


new_content = ensure_blank_lines_around_figures(new_content)

with open(target_path, "w") as f:
    f.write(new_content)

for src, ext, stem in resolved:
    print(f"{src}\t{ext}\t{stem}")
PY
)"

  if [[ -n "$IMAGE_MAP" ]]; then
    while IFS=$'\t' read -r img_src img_ext img_stem; do
      [[ -z "$img_src" ]] && continue
      img_dest="$TARGET_DIR/$img_stem.$img_ext"
      cp "$img_src" "$img_dest"
      if [[ "$img_ext" == "avif" ]]; then
        echo "  copied (already avif): $img_stem.avif"
      else
        "$TO_AVIF" --no-jpeg --replace "$img_dest" >/dev/null
        echo "  converted: $img_stem.avif"
      fi
      rm -f "$img_src"
    done <<< "$IMAGE_MAP"
  fi
fi

# Auto-fetch a cover when a review credits a source and asked for one
# (newpost.sh --cover). Reviews only: the cover illustrates the specific book
# being reviewed, which has no equivalent meaning for an article that merely
# cites a source (fetch-cover.py's resolve_about_source refuses non-reviews
# too, but gating here as well skips the pointless invocation on every
# article publish). Same best-effort spirit as the Open Library/Crossref
# lookups in newsource.sh: a bad match or no network falls through rather
# than blocking the rest of the publish. See the header comment.
if [[ "$SECTION" == "reviews" && ! -e "$TARGET_DIR/cover.avif" ]]; then
  FRONT_MATTER="$(sed -n '2,/^---$/p' "$TARGET_PATH" | sed '$d')"
  if grep -qE '^cover:[[:space:]]*$' <<< "$FRONT_MATTER" \
     && grep -qE '^sources:' <<< "$FRONT_MATTER"; then
    echo "Fetching cover..."
    if ! "$SCRIPT_DIR/fetch-cover.py" "$TARGET_DIR"; then
      echo "  cover not fetched automatically -- add one by hand with scripts/fetch-cover.py \"${TARGET_DIR#$REPO_ROOT/}\"" >&2
    fi
  fi
fi

TITLE="$(sed -n 's/^title: *"\(.*\)"[[:space:]]*$/\1/p' "$TARGET_PATH" | head -1)"
SLUG="$(sed -n 's/^slug: *"\(.*\)"[[:space:]]*$/\1/p' "$TARGET_PATH" | head -1)"
BASE_URL="$(sed -n 's/^baseURL: *//p' "$REPO_ROOT/hugo.yaml" | head -1)"
FALLBACK_SLUG="$(basename "$DRAFT_PATH" .md)"
POST_URL="${BASE_URL%/}/$SECTION/${SLUG:-$FALLBACK_SLUG}/"

echo "Published $SECTION draft:"
echo "  $DRAFT_INPUT"
echo "  -> ${TARGET_PATH#$REPO_ROOT/}"
echo "  $POST_URL"

# Log the publish event to today's Obsidian Status note. Best-effort: the
# draft has already left the vault by this point (moved into content/ above),
# so there's no Obsidian-side file left to flag draft:false on -- this is the
# closest equivalent, a breadcrumb in the daily note. Requires the Advanced
# URI plugin and the core Daily Notes plugin pointed at a real folder (see
# .obsidian/daily-notes.json); silently no-ops if Obsidian isn't running.
LOG_LINE="[Published: \"${TITLE:-$SECTION post}\"]($POST_URL) ($SECTION)"
ENCODED_DATA="$(python3 -c 'import sys, urllib.parse; print(urllib.parse.quote(sys.argv[1]))' "$LOG_LINE")"
open "obsidian://advanced-uri?vault=Notes&daily=true&data=${ENCODED_DATA}&mode=append&openmode=silent" 2>/dev/null || true

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
  "$SCRIPT_DIR/ship.sh" "Publish: ${TITLE:-$SECTION post}"
fi
