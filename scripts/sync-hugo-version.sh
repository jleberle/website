#!/usr/bin/env bash
# Check if the local Hugo version is available for GitHub Actions and update
# the workflow plus statichost.yml.
#
# Usage:
#   scripts/sync-hugo-version.sh            # check and update if available
#   scripts/sync-hugo-version.sh --dry-run  # report only, no changes

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
GITHUB_WORKFLOW="$REPO_ROOT/.github/workflows/site-checks.yml"
STATICHOST="$REPO_ROOT/statichost.yml"
DRY_RUN=false

# Portable in-place sed (BSD/macOS and GNU/Linux differ on `sed -i`): edit
# through a temp file and write back into the original, which preserves its
# permissions and inode.
sed_inplace() {
  local script="$1" file="$2" tmp
  tmp=$(mktemp)
  sed "$script" "$file" > "$tmp" && cat "$tmp" > "$file"
  rm -f "$tmp"
}

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
echo "Checking release   : gohugoio/hugo v${LOCAL_VERSION}"

# Check Docker Hub for the tag
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://hub.docker.com/v2/repositories/hugomods/hugo/tags/${TARGET_TAG}")

if [[ "$HTTP_STATUS" != "200" ]]; then
  echo "Image not available on Docker Hub yet (HTTP $HTTP_STATUS). No changes made."
  exit 0
fi

RELEASE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  "https://github.com/gohugoio/hugo/releases/download/v${LOCAL_VERSION}/hugo_extended_${LOCAL_VERSION}_linux-amd64.deb")

if [[ "$RELEASE_STATUS" != "302" && "$RELEASE_STATUS" != "200" ]]; then
  echo "Hugo Linux .deb release not available yet (HTTP $RELEASE_STATUS). No changes made."
  exit 0
fi

echo "Image found on Docker Hub."
echo "Hugo release found on GitHub."

# Extract current versions from config files
CURRENT_WORKFLOW=$(grep -oE 'HUGO_VERSION: "[0-9]+\.[0-9]+\.[0-9]+"' "$GITHUB_WORKFLOW" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "unknown")
CURRENT_STATICHOST=$(grep -oE 'debian-git-[0-9]+\.[0-9]+\.[0-9]+' "$STATICHOST" 2>/dev/null || echo "unknown")

if [[ "$CURRENT_WORKFLOW" == "$LOCAL_VERSION" && "$CURRENT_STATICHOST" == "$TARGET_TAG" ]]; then
  echo "Both configs already on Hugo $LOCAL_VERSION. Nothing to update."
  exit 0
fi

echo ""
echo "Updates needed:"
[[ "$CURRENT_WORKFLOW" != "$LOCAL_VERSION" ]] && echo "  GitHub Actions  : $CURRENT_WORKFLOW → $LOCAL_VERSION"
[[ "$CURRENT_STATICHOST" != "$TARGET_TAG" ]] && echo "  statichost.yml  : $CURRENT_STATICHOST → $TARGET_TAG"

if $DRY_RUN; then
  echo ""
  echo "Dry run — no changes made."
  exit 0
fi

# Update GitHub Actions
sed_inplace "s|HUGO_VERSION: \"[0-9]*\.[0-9]*\.[0-9]*\"|HUGO_VERSION: \"${LOCAL_VERSION}\"|g" "$GITHUB_WORKFLOW"

# Update statichost.yml — handles both debian-git and ci/exts style tags
sed_inplace "s|hugomods/hugo:[a-z-]*[0-9]*\.[0-9]*\.[0-9]*|hugomods/hugo:${TARGET_TAG}|g" "$STATICHOST"

echo ""
echo "Updated. Review changes with: git diff .github/workflows/site-checks.yml statichost.yml"
