#!/usr/bin/env bash
# Catalogue today's writing and publish the updated log.
#
# Run this at the end of a writing session, from any machine that has this repo
# and the Obsidian vault:
#
#   scripts/log-writing.sh
#
# WHAT IT DOES
#   1. Fetches this repo, so other machines' observations are merged in first.
#   2. Censuses the vault -> data/observations/<this machine>.json
#   3. Rebuilds data/writing-log.json from the blog's git history plus every
#      machine's observations.
#   4. Commits and pushes, so the site redeploys with the new numbers.
#
# YOU DO NOT HAVE TO RUN IT ON EVERY MACHINE
# Obsidian Sync converges all of them on the same files, so a run here sees
# whatever Sync has delivered here -- including writing done at work this
# morning. Three installs so it is always to hand, not three obligations.
#
# NOR DO YOU HAVE TO RUN IT EVERY DAY
# Words are dated by each file's mtime, not by when this ran. Write Tuesday, run
# Friday, and the words still land on Tuesday. Forgetting costs you publication
# delay, not accuracy.
#
# Set NOTES_VAULT if the vault is not at ~/Notes on this machine.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

DATA="data/writing-log.json"
OBS="data/observations"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
note() { printf '  %s\n' "$*"; }
die()  { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

[[ -d .git ]] || die "log-writing: $REPO_ROOT is not a git repository"

if [[ -d .git/rebase-merge || -d .git/rebase-apply || -f .git/MERGE_HEAD ]]; then
  die "log-writing: a rebase or merge is in progress here — finish it first"
fi

# --- 1. fetch -------------------------------------------------------------
# Over anonymous HTTPS rather than the SSH origin. The repo is public, so
# fetching needs no credential, and on the machines where the GitHub key lives
# in Secretive that means one Touch ID prompt for the push instead of two.
# origin is left alone, so ship.sh keeps using SSH exactly as before.
bold "Fetching"
FETCH_URL="${WEBSITE_FETCH_URL:-https://github.com/jleberle/website.git}"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"


# The refspec matters. Fetching by URL alone lands in FETCH_HEAD and leaves
# refs/remotes/origin/$BRANCH untouched, so `@{u}` still points at wherever this
# checkout was the last time it talked to origin by name. The push guard below
# counts commits against `@{u}`, and a stale one makes every machine after the
# first believe it is carrying unpushed work of its own and refuse to publish.
# Writing the tracking ref explicitly keeps `@{u}` honest. `+` because a force
# push upstream should update the tracking ref rather than fail the fetch.
REFSPEC="+refs/heads/$BRANCH:refs/remotes/origin/$BRANCH"

if git fetch --quiet "$FETCH_URL" "$REFSPEC" 2>/dev/null; then
  # --autostash so an in-progress draft in the working tree doesn't block it.
  if git merge --ff-only --autostash "origin/$BRANCH" >/dev/null 2>&1; then
    note "up to date with origin/$BRANCH"
  else
    note "local history has diverged from origin — continuing with what's here"
    note "(your commits are safe; run scripts/ship.sh to reconcile)"
  fi
else
  note "offline or fetch failed — continuing with local history"
fi

# --autostash pops the stash after the fast-forward, and that pop can conflict:
# it happens whenever an incoming commit touches a file you have uncommitted
# edits in. Git leaves conflict markers in the working tree, keeps the stash
# entry, and exits non-zero -- but the merge itself already succeeded, so
# nothing above catches it.
#
# Stopping here is not optional. Left to run on, this script would count, build
# and commit against a tree containing `<<<<<<<` markers. The Hugo smoke test
# does not reliably catch that either: markers landing inside an HTML comment
# parse as ordinary text and the build passes clean.
if [[ -n "$(git ls-files --unmerged)" ]]; then
  bold "Stopped: unresolved conflict in your working tree"
  git ls-files --unmerged | awk '{print $4}' | sort -u | sed 's/^/    /'
  note "an incoming commit touched a file you had uncommitted edits in"
  note "resolve those files, then: git stash drop   (your edits are in the stash too)"
  exit 1
fi

# --- 2. census ------------------------------------------------------------
bold "Counting the vault"
python3 scripts/writing-log.py observe | sed 's/^writing-log: /  /'

# --- 3. rebuild -----------------------------------------------------------
bold "Rebuilding the log"
python3 scripts/writing-log.py --stats | sed 's/^writing-log: /  /'

if [[ -z "$(git status --porcelain -- "$DATA" "$OBS")" ]]; then
  bold "Nothing new to publish"
  note "no writing found since the last run"
  exit 0
fi

# --- 4. smoke test --------------------------------------------------------
# Cheap guard against committing a data file Hugo can't render. The full
# preflight gate runs on push anyway, via the pre-push hook.
bold "Checking the build"
if ! HUGO_OUT="$(hugo --minify --quiet 2>&1)"; then
  printf '%s\n' "$HUGO_OUT" >&2
  die "log-writing: hugo build failed — nothing committed"
fi
note "ok"

# --- 5. commit ------------------------------------------------------------
# Only ever these two paths. `git add -A` here would sweep up whatever is
# half-finished in the working tree; that is ship.sh's job, with its own
# confirmation prompt.
bold "Committing"
git add -- "$DATA" "$OBS"
git commit -q -m "Update writing log through $(date '+%Y-%m-%d')" -- "$DATA" "$OBS"
note "$(git log --oneline -1)"

# --- 6. push --------------------------------------------------------------
if ! git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; then
  bold "Not pushing"
  note "no upstream branch configured — the commit is safe locally"
  exit 0
fi

# Anything unpushed beyond the commit just made is work in progress that was
# deliberately not shipped. Publishing it as a side effect of a log update is
# not this script's call to make.
AHEAD="$(git rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
if [[ "$AHEAD" -gt 1 ]]; then
  bold "Not pushing"
  note "$((AHEAD - 1)) unpushed commit(s) of your own are sitting here:"
  git log --oneline '@{u}..HEAD^' | sed 's/^/    /'
  note "run scripts/ship.sh when you're ready — it publishes the log too"
  exit 0
fi

bold "Pushing"
note "(Touch ID, if your key asks for it)"
if git push --quiet; then
  bold "Published — Cloudflare Workers Builds will redeploy"
  exit 0
fi

# Rejected: almost always another machine pushed between our fetch and now.
# Undo our own commit so the checkout is left exactly as re-runnable as it was,
# rather than one commit ahead of a remote it cannot fast-forward to -- that
# state would make the *next* run see diverged history, refuse to merge, and
# then refuse to push for having "unpushed work". Two data files are the only
# thing being thrown away and both are derived: the next run regenerates them.
#
# --mixed, never --hard: a --hard here would also destroy whatever else is
# uncommitted in the working tree. The checkout below is scoped to data/.
git reset --quiet --mixed HEAD~1
git checkout --quiet -- "$DATA" "$OBS" 2>/dev/null || true
bold "Push rejected — nothing lost"
note "another machine probably published first; run this again"
exit 1
