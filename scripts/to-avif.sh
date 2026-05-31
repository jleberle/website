#!/usr/bin/env bash
# Convert one or more images (jpg, jpeg, png, webp) to optimized .avif for web delivery.
# Originals are preserved unless --replace is passed.
#
# Usage:
#   scripts/to-avif.sh photo.jpg                  # writes photo.avif alongside original
#   scripts/to-avif.sh --replace photo.jpg         # converts and removes original
#   scripts/to-avif.sh -q 70 photo.png             # custom quality (default: 60)
#   scripts/to-avif.sh *.jpg                       # batch

set -euo pipefail

QUALITY=60
REPLACE=false
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --replace) REPLACE=true; shift ;;
    -q|--quality) QUALITY="$2"; shift 2 ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Usage: $(basename "$0") [--replace] [-q QUALITY] <image> [...]" >&2
  exit 1
fi

for src in "${FILES[@]}"; do
  ext="${src##*.}"
  case "${ext,,}" in
    jpg|jpeg|png|webp) ;;
    avif) echo "  skip (already avif): $src"; continue ;;
    *) echo "  skip (unsupported format): $src"; continue ;;
  esac

  dest="${src%.*}.avif"
  before=$(du -k "$src" | cut -f1)

  magick "$src" -quality "$QUALITY" "$dest"

  after=$(du -k "$dest" | cut -f1)
  pct=$(( (after - before) * 100 / before ))
  sign=""; [[ $pct -gt 0 ]] && sign="+"
  echo "  ${src} → ${dest}  (${before}K → ${after}K, ${sign}${pct}%)"

  if $REPLACE; then
    rm "$src"
    echo "  removed original: $src"
  fi
done
