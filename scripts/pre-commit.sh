#!/opt/homebrew/bin/bash
# Repository-specific pre-commit checks, invoked by the global hook in
# ~/.dotfiles/git/hooks/pre-commit:
#   1. Block draft content from being committed.
#   2. Convert staged source images to AVIF + JPEG, removing originals.
#      OG JPEG companions (a .jpg with a sibling .avif) are preserved.

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$REPO_ROOT/scripts/to-avif.sh"

mapfile -t posts < <(git diff --cached --name-only --diff-filter=AM | grep -iE '^content/.*\.md$' || true)
drafts=()
for post in "${posts[@]}"; do
  if git show ":$post" | grep -qiE '^draft:\s*true'; then
    drafts+=("$post")
  fi
done
if [[ ${#drafts[@]} -gt 0 ]]; then
  echo "Unstaging draft(s) — commit will proceed without them:" >&2
  for draft in "${drafts[@]}"; do
    echo "  $draft" >&2
    git rm --cached "$draft"
  done
fi

mapfile -t staged_images < <(git diff --cached --name-only --diff-filter=AM | grep -iE '\.(jpg|jpeg|png|webp)$' || true)
if [[ ${#staged_images[@]} -eq 0 ]]; then
  exit 0
fi

og_jpegs=()
source_images=()
for image in "${staged_images[@]}"; do
  ext="${image##*.}"
  if [[ "${ext,,}" == "jpg" || "${ext,,}" == "jpeg" ]]; then
    if [[ "$image" == assets/images/* ]]; then
      og_jpegs+=("$image")
      continue
    fi
    avif_sibling="${image%.*}.avif"
    if [[ -f "$REPO_ROOT/$avif_sibling" ]] || git diff --cached --name-only | grep -q "^${avif_sibling}$"; then
      og_jpegs+=("$image")
      continue
    fi
  fi
  source_images+=("$image")
done

if [[ ${#og_jpegs[@]} -gt 0 ]]; then
  echo "Keeping ${#og_jpegs[@]} OG JPEG companion(s) as-is:"
  printf '  %s\n' "${og_jpegs[@]}"
fi

if [[ ${#source_images[@]} -eq 0 ]]; then
  exit 0
fi

echo "Converting ${#source_images[@]} image(s) to AVIF + JPEG..."
for image in "${source_images[@]}"; do
  output=$("$SCRIPT" --replace "$image")
  echo "$output"
  if echo "$output" | grep -q "skip (protected"; then
    continue
  fi
  git rm --cached "$image" 2>/dev/null || true
  avif="${image%.*}.avif"
  jpg="${image%.*}.jpg"
  git add "$avif"
  [[ -f "$REPO_ROOT/$jpg" ]] && git add "$jpg"
done

echo "Done. AVIF and JPEG files staged, originals removed."
