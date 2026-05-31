#!/usr/bin/env bash
# Convert all .webp files to .avif and update every reference in the repo.
# Usage: scripts/webp-to-avif.sh [--dry-run]

set -euo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

log()  { echo "  $*"; }
skip() { echo "  (dry-run) $*"; }

converted=0; skipped=0; total_before=0; total_after=0

echo "==> Converting .webp → .avif (quality 60)"
while IFS= read -r webp; do
  avif="${webp%.webp}.avif"
  before=$(du -k "$webp" | cut -f1)
  total_before=$((total_before + before))

  if $DRY_RUN; then
    skip "would convert: ${webp#$ROOT/}"
    skipped=$((skipped + 1))
    continue
  fi

  magick "$webp" -quality 60 "$avif"
  after=$(du -k "$avif" | cut -f1)
  total_after=$((total_after + after))
  pct=$(( (after - before) * 100 / before ))
  log "converted: ${webp#$ROOT/}  (${before}K → ${after}K, ${pct:+$pct}%)"
  rm "$webp"
  converted=$((converted + 1))
done < <(find "$ROOT" -name "*.webp" -not -path "$ROOT/public/*" -not -path "$ROOT/resources/*")

echo ""
echo "==> Updating .webp references in content/ and hugo.yaml"

# Files that may contain .webp references
while IFS= read -r f; do
  if $DRY_RUN; then
    count=$(grep -o "\.webp" "$f" | wc -l | tr -d ' ')
    skip "would update $count reference(s) in: ${f#$ROOT/}"
  else
    sed -i '' 's/\.webp/.avif/g' "$f"
    log "updated references: ${f#$ROOT/}"
  fi
done < <(grep -rl "\.webp" "$ROOT/content" "$ROOT/hugo.yaml" "$ROOT/layouts" 2>/dev/null || true)

echo ""
if $DRY_RUN; then
  echo "==> Dry-run complete. Re-run without --dry-run to apply."
else
  savings=$((total_before - total_after))
  pct_total=$(( savings * 100 / (total_before > 0 ? total_before : 1) ))
  echo "==> Done. Converted $converted files."
  echo "    Before: ${total_before}K  After: ${total_after}K  Saved: ${savings}K (${pct_total}%)"
fi
