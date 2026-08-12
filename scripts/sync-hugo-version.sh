#!/usr/bin/env bash
# Sync the Hugo version pinned in .hugo-version to match local Hugo — but
# only once the matching GitHub release actually exists. Bumping early would
# 404 CI's .deb download (see .github/workflows/site-checks.yml, which derives
# its own Hugo version from .hugo-version at run time, so it can never drift
# from what this script sets here).
#
# .hugo-version does NOT drive the live build — Cloudflare Workers Builds
# pins Hugo via its own HUGO_VERSION build variable (dashboard-managed, see
# docs/operations.md), independent of anything in this repo. After bumping
# .hugo-version, update that build variable too or the two will drift.
#
# Usage:
#   scripts/sync-hugo-version.sh            # check and update if available
#   scripts/sync-hugo-version.sh --dry-run  # report only, no changes

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
PIN_FILE="$REPO_ROOT/.hugo-version"
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

curl -fsS -o /dev/null "https://github.com/gohugoio/hugo/releases/download/v${LOCAL_VERSION}/hugo_extended_${LOCAL_VERSION}_linux-amd64.deb" \
  || { echo "GitHub release v${LOCAL_VERSION} .deb not published yet. No changes made."; exit 0; }
echo "GitHub release available."

if $DRY_RUN; then
  echo "Dry run — would update $PIN_FILE to Hugo $LOCAL_VERSION."
  exit 0
fi

echo "$LOCAL_VERSION" > "$PIN_FILE"

echo "Updated (or already current). Review with: git diff $PIN_FILE"
echo "Remember: also update the HUGO_VERSION build variable in Cloudflare's Workers Builds settings."
