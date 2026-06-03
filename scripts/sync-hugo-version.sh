#!/usr/bin/env bash
# Check if the local Hugo version has a matching hugomods/hugo:debian-git-{version}
# image on Docker Hub and update .woodpecker.yml and statichost.yml if so.
#
# Usage:
#   scripts/sync-hugo-version.sh            # check and update if available
#   scripts/sync-hugo-version.sh --dry-run  # report only, no changes

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
WOODPECKER="$REPO_ROOT/.woodpecker.yml"
STATICHOST="$REPO_ROOT/statichost.yml"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

# Get local Hugo version
LOCAL_VERSION=$(hugo version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ -z "$LOCAL_VERSION" ]]; then
  echo "Error: could not determine local Hugo version." >&2
  exit 1
fi

TARGET_TAG="debian-git-${LOCAL_VERSION}"
echo "Local Hugo version : $LOCAL_VERSION"
echo "Checking image     : hugomods/hugo:${TARGET_TAG}"

# Check Docker Hub for the tag
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://hub.docker.com/v2/repositories/hugomods/hugo/tags/${TARGET_TAG}")

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "Image not available on Docker Hub yet (HTTP $HTTP_STATUS). No changes made."
  exit 0
fi

echo "Image found on Docker Hub."

# Extract current versions from config files
CURRENT_WOODPECKER=$(grep -oE 'debian-git-[0-9]+\.[0-9]+\.[0-9]+' "$WOODPECKER" 2>/dev/null || echo "unknown")
CURRENT_STATICHOST=$(grep -oE 'debian-git-[0-9]+\.[0-9]+\.[0-9]+' "$STATICHOST" 2>/dev/null || echo "unknown")

if [[ "$CURRENT_WOODPECKER" == "$TARGET_TAG" && "$CURRENT_STATICHOST" == "$TARGET_TAG" ]]; then
  echo "Both configs already on $TARGET_TAG. Nothing to update."
  exit 0
fi

echo ""
echo "Updates needed:"
[[ "$CURRENT_WOODPECKER" != "$TARGET_TAG" ]] && echo "  .woodpecker.yml : $CURRENT_WOODPECKER → $TARGET_TAG"
[[ "$CURRENT_STATICHOST" != "$TARGET_TAG" ]] && echo "  statichost.yml  : $CURRENT_STATICHOST → $TARGET_TAG"

if $DRY_RUN; then
  echo ""
  echo "Dry run — no changes made."
  exit 0
fi

# Update .woodpecker.yml
sed -i '' "s|hugomods/hugo:debian-git-[0-9]*\.[0-9]*\.[0-9]*|hugomods/hugo:${TARGET_TAG}|g" "$WOODPECKER"

# Update statichost.yml — handles both debian-git and ci/exts style tags
sed -i '' "s|hugomods/hugo:[a-z-]*[0-9]*\.[0-9]*\.[0-9]*|hugomods/hugo:${TARGET_TAG}|g" "$STATICHOST"

echo ""
echo "Updated. Review changes with: git diff .woodpecker.yml statichost.yml"
