#!/usr/bin/env bash
# Stage, commit, and push pending changes after running the local preflight gate.
#
# This is the last step of the write -> publish -> distribute pipeline: once
# preflight passes, StaticHost deploys and GitHub Actions pings WebSub/Micro.blog
# automatically, so a clean push is the only manual action left.
#
# Usage:
#   scripts/ship.sh "Commit message"
#   scripts/ship.sh --full "Commit message"   # run preflight --full first
#   scripts/ship.sh --yes "Commit message"    # skip the file-list confirmation
#   scripts/ship.sh                           # prompts for a commit message
#
# Because this commits with `git add -A`, it first lists every pending change
# and asks for confirmation, so unrelated in-progress work can't ride along
# silently. --yes skips the prompt for non-interactive use.
#
# Refuses to commit or push if preflight fails, leaving the working tree
# exactly as it was so you can fix the issue and re-run.

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") [--full] [--yes] [\"Commit message\"]" >&2
  echo "Runs scripts/preflight.sh, then git add -A, commit, and push." >&2
  echo "  --full  Run the slower preflight --full gate first." >&2
  echo "  --yes   Skip the file-list confirmation prompt." >&2
  exit 1
}

FULL=false
YES=false
ARGS=()
for arg in "$@"; do
  case "$arg" in
    --full) FULL=true ;;
    --yes) YES=true ;;
    --help|-h) usage ;;
    -*) echo "Unknown option: $arg" >&2; usage ;;
    *) ARGS+=("$arg") ;;
  esac
done
[[ ${#ARGS[@]} -gt 1 ]] && usage

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." >/dev/null 2>&1 && pwd )"
cd "$REPO_ROOT"

if [[ -z "$(git status --porcelain)" ]]; then
  echo "Nothing to ship: working tree is clean." >&2
  exit 0
fi

# Everything listed here will be committed (git add -A). Confirm before
# proceeding so stray or unrelated in-progress files are caught by eye.
echo "Will commit and push ALL of the following:" >&2
git status --short >&2
if ! $YES; then
  read -r -p "Proceed? [y/N]: " CONFIRM
  case "$CONFIRM" in
    y|Y|yes|YES|Yes) ;;
    *) echo "Aborted; nothing committed or pushed." >&2; exit 1 ;;
  esac
fi

MESSAGE="${ARGS[0]:-}"
if [[ -z "$MESSAGE" ]]; then
  read -r -p "Commit message: " MESSAGE
  [[ -n "$MESSAGE" ]] || { echo "A commit message is required." >&2; exit 1; }
fi

PREFLIGHT_ARGS=()
$FULL && PREFLIGHT_ARGS+=(--full)

echo "Running preflight..." >&2
if ! scripts/preflight.sh "${PREFLIGHT_ARGS[@]}"; then
  echo >&2
  echo "Preflight failed; nothing committed or pushed. Fix the issues above and re-run." >&2
  exit 1
fi

git add -A
git commit -m "$MESSAGE"
git push

echo "Shipped: $MESSAGE" >&2
