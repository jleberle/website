#!/usr/bin/env bash
# Stage, commit, and push pending changes after running the local preflight gate.
#
# This is the last step of the write -> publish -> distribute pipeline: once
# preflight passes, Cloudflare Workers Builds deploys and GitHub Actions pings WebSub/Micro.blog
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

# writing-log.py reads *committed* git history, so the preflight run above
# regenerated data/writing-log.json before the commit just made existed --
# today's post was still invisible to `git log`. Re-run now that it exists,
# and fold any change into the same not-yet-pushed commit (--amend is safe
# here: nothing has been pushed yet, so this rewrites no shared history).
# Without this, the log stays visibly stale until some later, unrelated push
# happens to trigger another preflight run.
set +e
WLOG_OUT=$(python3 scripts/writing-log.py --allow-missing 2>&1)
WLOG_RC=$?
set -e
if [[ $WLOG_RC -eq 0 ]] && ! git diff --quiet -- data/writing-log.json; then
  git add data/writing-log.json
  git commit --amend --no-edit
  echo "writing log: updated after commit, folded in ($WLOG_OUT)" >&2
elif [[ $WLOG_RC -ne 0 && $WLOG_RC -ne 3 ]]; then
  echo "writing log: post-commit rebuild failed, left as committed by preflight:" >&2
  echo "$WLOG_OUT" >&2
fi

# Tells the global pre-push hook (~/git/dotfiles/git/hooks/pre-push) that
# preflight already ran and passed above, so it doesn't run the whole gate a
# second time for a push that came from here. Exported only for this `git
# push` child process, not the calling shell, so a bare `git push` afterward
# is still fully gated.
WEBSITE_PREFLIGHT_VERIFIED=1 git push

echo "Shipped: $MESSAGE" >&2
