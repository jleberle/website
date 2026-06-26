#!/usr/bin/env bash
# Sync the Hugo version pinned in CI and statichost.yml to match local Hugo —
# but only once the matching Docker image and GitHub release actually exist.
# Bumping early 404s StaticHost's image pull and CI's .deb download (see
# .github/workflows/site-checks.yml and statichost.yml).
#
# Usage:
#   scripts/sync-hugo-version.sh            # check and update if available
#   scripts/sync-hugo-version.sh --dry-run  # report only, no changes

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
GITHUB_WORKFLOW="$REPO_ROOT/.github/workflows/site-checks.yml"
STATICHOST="$REPO_ROOT/statichost.yml"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=true; shift ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

LOCAL_VERSION=$(hugo version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [[ -z "$LOCAL_VERSION" ]]; then
  echo "Error: could not determine local Hugo version." >&2
  exit 1
fi
echo "Local Hugo version: $LOCAL_VERSION"

# curl -f treats any non-4xx/5xx response (including GitHub's redirect to the
# release asset) as success, so one check covers both Docker Hub and GitHub.
curl -fsS -o /dev/null "https://hub.docker.com/v2/repositories/hugomods/hugo/tags/debian-git-${LOCAL_VERSION}" \
  || { echo "Docker image hugomods/hugo:debian-git-${LOCAL_VERSION} not published yet. No changes made."; exit 0; }
curl -fsS -o /dev/null "https://github.com/gohugoio/hugo/releases/download/v${LOCAL_VERSION}/hugo_extended_${LOCAL_VERSION}_linux-amd64.deb" \
  || { echo "GitHub release v${LOCAL_VERSION} .deb not published yet. No changes made."; exit 0; }
echo "Docker image and GitHub release both available."

if $DRY_RUN; then
  echo "Dry run — would update $GITHUB_WORKFLOW and $STATICHOST to Hugo $LOCAL_VERSION."
  exit 0
fi

# -i.bak is portable across BSD and GNU sed (only a bare -i differs between them).
sed -i.bak -E "s/HUGO_VERSION: \"[0-9]+\.[0-9]+\.[0-9]+\"/HUGO_VERSION: \"${LOCAL_VERSION}\"/" "$GITHUB_WORKFLOW" && rm -f "$GITHUB_WORKFLOW.bak"
sed -i.bak -E "s|hugomods/hugo:[a-z-]+[0-9]+\.[0-9]+\.[0-9]+|hugomods/hugo:debian-git-${LOCAL_VERSION}|" "$STATICHOST" && rm -f "$STATICHOST.bak"

echo "Updated (or already current). Review with: git diff $GITHUB_WORKFLOW $STATICHOST"
