#!/usr/bin/env bash
# Add images to a post bundle with the site's two conversion paths baked in:
#
#   cover  → cover.avif (display/schema) + optimized cover.jpg (og:image
#            fallback for social crawlers), via to-avif.sh
#   body   → .avif only (no jpeg fallback needed), original removed
#
# Prints paste-ready front-matter / figure-shortcode snippets afterwards.
# Body figure snippets have alt="" — fill them in, or the build will warn.
#
# Usage:
#   scripts/add-images.sh <post-dir> --cover photo.jpg
#   scripts/add-images.sh <post-dir> img1.jpg img2.png ...
#   scripts/add-images.sh <post-dir> -q 60 img.jpg     # custom avif quality

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
TO_AVIF="$REPO_ROOT/scripts/to-avif.sh"

usage() {
  echo "Usage: $(basename "$0") <post-dir> [--cover] [-q QUALITY] <image> [...]" >&2
  exit 1
}

[[ $# -lt 2 ]] && usage
POST_DIR="$1"; shift

COVER=false
QUALITY_ARGS=()
IMAGES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --cover) COVER=true; shift ;;
    -q|--quality) QUALITY_ARGS+=(-q "$2"); shift 2 ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) IMAGES+=("$1"); shift ;;
  esac
done

[[ ${#IMAGES[@]} -eq 0 ]] && usage
[[ -f "$POST_DIR/index.md" ]] || { echo "Not a post bundle (no index.md): $POST_DIR" >&2; exit 1; }
$COVER && [[ ${#IMAGES[@]} -gt 1 ]] && { echo "--cover takes exactly one image" >&2; exit 1; }

slugify_stem() {
  local name; name=$(basename "$1")
  local stem="${name%.*}"
  printf '%s' "$stem" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

lower_ext() {
  local ext="${1##*.}"
  ext=$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')
  [[ "$ext" == "jpeg" ]] && ext="jpg"
  printf '%s' "$ext"
}

if $COVER; then
  src="${IMAGES[0]}"
  ext=$(lower_ext "$src")
  dest="$POST_DIR/cover.$ext"
  [[ -e "$POST_DIR/cover.avif" ]] && { echo "cover.avif already exists in $POST_DIR" >&2; exit 1; }
  cp "$src" "$dest"
  if [[ "$ext" == "jpg" ]]; then
    # jpg source: to-avif keeps it as the og fallback (re-encoded if smaller)
    "$TO_AVIF" "${QUALITY_ARGS[@]+"${QUALITY_ARGS[@]}"}" "$dest"
  else
    # other formats: produce cover.avif + cover.jpg, drop the original
    "$TO_AVIF" --replace "${QUALITY_ARGS[@]+"${QUALITY_ARGS[@]}"}" "$dest"
  fi
  cat <<EOF

Add to front matter (write the alt — it describes the image for screen readers):

cover:
  image: "cover.avif"
  alt: ""
  hiddenInList: true
  hiddenInSingle: false
  caption: ""
  relative: true # To use relative path for cover image, used in hugo Page-bundles
EOF
else
  SNIPPETS=()
  for src in "${IMAGES[@]}"; do
    ext=$(lower_ext "$src")
    stem=$(slugify_stem "$src")
    if [[ "$ext" == "avif" ]]; then
      cp "$src" "$POST_DIR/$stem.avif"
      echo "  copied (already avif): $stem.avif"
    else
      dest="$POST_DIR/$stem.$ext"
      cp "$src" "$dest"
      # body images need no jpeg fallback; original removed after conversion
      "$TO_AVIF" --no-jpeg --replace "${QUALITY_ARGS[@]+"${QUALITY_ARGS[@]}"}" "$dest"
    fi
    SNIPPETS+=("{{< figure src=\"$stem.avif\" alt=\"\" align=center >}}")
  done
  cat <<EOF

Paste where needed (fill in alt text, or add a caption — empty figures warn at build):

EOF
  printf '%s\n' "${SNIPPETS[@]}"
fi
