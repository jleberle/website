#!/usr/bin/env bash
# Convert one or more images (jpg, jpeg, png, webp) to optimized .avif for web delivery.
# Also writes a .jpg alongside each file for OpenGraph crawler compatibility.
# Originals are preserved unless --replace is passed.
#
# Usage:
#   scripts/to-avif.sh photo.jpg                  # writes photo.avif + photo.jpg alongside original
#   scripts/to-avif.sh --replace photo.png         # converts and removes original
#                                                  # (.jpg originals are kept as the jpeg fallback)
#   scripts/to-avif.sh -q 70 photo.png             # custom avif quality (default: 50)
#   scripts/to-avif.sh --no-jpeg photo.png         # skip jpeg output
#   scripts/to-avif.sh *.jpg                       # batch

set -euo pipefail

QUALITY=50
JPEG_QUALITY=85
REPLACE=false
JPEG=true
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --replace) REPLACE=true; shift ;;
    -q|--quality) QUALITY="$2"; shift 2 ;;
    --jpeg-quality) JPEG_QUALITY="$2"; shift 2 ;;
    --no-jpeg) JPEG=false; shift ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Usage: $(basename "$0") [--replace] [-q QUALITY] [--jpeg-quality QUALITY] [--no-jpeg] <image> [...]" >&2
  exit 1
fi

# Icons that must remain PNG for browser/OS compatibility
PROTECTED=(
  "assets/icons/apple-touch-icon.png"
  "static/icons/apple-touch-icon.png"
  "static/icons/favicon-16x16.png"
  "static/icons/favicon-32x32.png"
  "static/favicon.ico"
)

for src in "${FILES[@]}"; do
  # Normalise path for comparison
  norm_src="${src#./}"
  for protected in "${PROTECTED[@]}"; do
    if [[ "$norm_src" == "$protected" || "$norm_src" == *"/$protected" ]]; then
      echo "  skip (protected icon, must stay PNG): $src"
      continue 2
    fi
  done

  ext="${src##*.}"
  case "${ext,,}" in
    jpg|jpeg|png|webp) ;;
    avif) echo "  skip (already avif): $src"; continue ;;
    *) echo "  skip (unsupported format): $src"; continue ;;
  esac

  before=$(du -k "$src" | cut -f1)

  # Convert to avif. Orientation is baked in before -strip discards the EXIF
  # tag; heic:speed trades encode time for slightly smaller files.
  dest_avif="${src%.*}.avif"
  magick "$src" -auto-orient -strip -quality "$QUALITY" -define heic:speed=2 "$dest_avif"
  after_avif=$(du -k "$dest_avif" | cut -f1)
  pct_avif=$(( (after_avif - before) * 100 / before ))
  sign=""; [[ $pct_avif -gt 0 ]] && sign="+"
  echo "  ${src} → ${dest_avif}  (${before}K → ${after_avif}K, ${sign}${pct_avif}%)"

  # Convert to jpeg for OG crawler compatibility. A .jpg source is kept as its
  # own fallback rather than lossily re-encoded over itself.
  src_is_jpeg_dest=false
  if $JPEG; then
    dest_jpg="${src%.*}.jpg"
    if [[ "$dest_jpg" -ef "$src" ]]; then
      src_is_jpeg_dest=true
      echo "  keep (source already jpeg, serves as OG fallback): $src"
    else
      magick "$src" -auto-orient -background white -alpha remove -strip \
        -interlace JPEG -quality "$JPEG_QUALITY" "$dest_jpg"
      after_jpg=$(du -k "$dest_jpg" | cut -f1)
      pct_jpg=$(( (after_jpg - before) * 100 / before ))
      sign=""; [[ $pct_jpg -gt 0 ]] && sign="+"
      echo "  ${src} → ${dest_jpg}  (${before}K → ${after_jpg}K, ${sign}${pct_jpg}%)"
    fi
  fi

  if $REPLACE; then
    if $src_is_jpeg_dest; then
      echo "  kept original (needed as jpeg fallback): $src"
    else
      rm "$src"
      echo "  removed original: $src"
    fi
  fi
done
