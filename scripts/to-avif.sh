#!/usr/bin/env bash
# Convert one or more images (jpg, jpeg, png, webp) to optimized .avif for web delivery.
# Also writes a .jpg alongside each file for OpenGraph crawler compatibility.
# Originals are preserved unless --replace is passed.
#
# OG jpegs are capped at OG_MAX_WIDTH and re-encoded progressive at JPEG_QUALITY.
# A .jpg source is re-encoded over itself only when that shrinks it by at least
# 5%, so re-running the script never compounds generational quality loss.
#
# Usage:
#   scripts/to-avif.sh photo.jpg                  # writes photo.avif + photo.jpg alongside original
#   scripts/to-avif.sh --replace photo.png         # converts and removes original
#                                                  # (.jpg originals are kept as the jpeg fallback)
#   scripts/to-avif.sh -q 70 photo.png             # custom avif quality (default: 50)
#   scripts/to-avif.sh --no-jpeg photo.png         # skip jpeg output
#   scripts/to-avif.sh --chroma 444 shot.png       # avif chroma subsampling (default: 420);
#                                                  # 420 is smaller and fine for photos, 444
#                                                  # avoids color bleed on screenshots/text
#                                                  # with sharp colored edges
#   scripts/to-avif.sh --og-only cover.jpg         # only (re)optimize the OG jpeg; never
#                                                  # touches the avif (use for existing covers)
#   scripts/to-avif.sh --og-width 800 photo.jpg    # custom OG jpeg max width (default: 1200)
#   scripts/to-avif.sh *.jpg                       # batch

set -euo pipefail

QUALITY=50
CHROMA=420
JPEG_QUALITY=85
OG_MAX_WIDTH=1200
REPLACE=false
JPEG=true
OG_ONLY=false
FILES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --replace) REPLACE=true; shift ;;
    -q|--quality) QUALITY="$2"; shift 2 ;;
    --chroma) CHROMA="$2"; shift 2 ;;
    --jpeg-quality) JPEG_QUALITY="$2"; shift 2 ;;
    --og-width) OG_MAX_WIDTH="$2"; shift 2 ;;
    --no-jpeg) JPEG=false; shift ;;
    --og-only) OG_ONLY=true; shift ;;
    -*) echo "Unknown option: $1" >&2; exit 1 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "Usage: $(basename "$0") [--replace] [--og-only] [-q QUALITY] [--chroma 420|422|444] [--jpeg-quality QUALITY] [--og-width WIDTH] [--no-jpeg] <image> [...]" >&2
  exit 1
fi

case "$CHROMA" in
  420|422|444) ;;
  *) echo "Invalid --chroma value: $CHROMA (must be 420, 422, or 444)" >&2; exit 1 ;;
esac

if $OG_ONLY && ! $JPEG; then
  echo "--og-only and --no-jpeg are mutually exclusive" >&2
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
  # tag; heic:speed trades encode time for slightly smaller files. A fully
  # opaque alpha channel carries no information, so drop it (screenshots saved
  # as PNG often ship one); genuine transparency is preserved since AVIF
  # supports it and we only touch images that report as opaque.
  if ! $OG_ONLY; then
    dest_avif="${src%.*}.avif"
    alpha_args=()
    if [[ "$(magick "$src" -format '%[opaque]' info: 2>/dev/null)" == "True" ]]; then
      alpha_args=(-alpha off)
    fi
    magick "$src" -auto-orient -strip "${alpha_args[@]}" -quality "$QUALITY" \
      -define heic:speed=2 -define heic:chroma="$CHROMA" "$dest_avif"
    after_avif=$(du -k "$dest_avif" | cut -f1)
    pct_avif=$(( (after_avif - before) * 100 / before ))
    sign=""; [[ $pct_avif -gt 0 ]] && sign="+"
    echo "  ${src} → ${dest_avif}  (${before}K → ${after_avif}K, ${sign}${pct_avif}%)"
  fi

  # Convert to jpeg for OG crawler compatibility: capped at OG_MAX_WIDTH (only
  # ever shrinks), progressive, metadata stripped. A .jpg source is re-encoded
  # over itself via a temp file, kept only when ≥5% smaller so repeat runs
  # don't stack lossy generations.
  src_is_jpeg_dest=false
  if $JPEG; then
    dest_jpg="${src%.*}.jpg"
    if [[ "$dest_jpg" -ef "$src" ]]; then
      src_is_jpeg_dest=true
      tmp_jpg=$(mktemp "${TMPDIR:-/tmp}/ogjpg.XXXXXX").jpg
      magick "$src" -auto-orient -strip -resize "${OG_MAX_WIDTH}x>" \
        -interlace JPEG -quality "$JPEG_QUALITY" "$tmp_jpg"
      before_b=$(stat -f%z "$src" 2>/dev/null || stat -c%s "$src")
      after_b=$(stat -f%z "$tmp_jpg" 2>/dev/null || stat -c%s "$tmp_jpg")
      if (( after_b * 100 <= before_b * 95 )); then
        mv "$tmp_jpg" "$src"
        echo "  ${src} re-encoded for OG  ($((before_b / 1024))K → $((after_b / 1024))K, -$(( (before_b - after_b) * 100 / before_b ))%)"
      else
        rm -f "$tmp_jpg"
        echo "  keep (already optimized, <5% savings): $src"
      fi
    else
      magick "$src" -auto-orient -background white -alpha remove -strip \
        -resize "${OG_MAX_WIDTH}x>" -interlace JPEG -quality "$JPEG_QUALITY" "$dest_jpg"
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
