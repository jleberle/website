#!/usr/bin/env bash
# Report whether this checkout is configured to build, check, and publish the
# site — the things that are specific to THIS repo on THIS machine, not
# whether a program is installed.
#
# Tool presence (hugo, imagemagick, lychee, node, git, curl, gnupg) lives in
# ~/git/dotfiles/homebrew/brewfile and is checked by `dots brew-check`
# (`make brew-check` in that repo). This script used to duplicate that check;
# it doesn't anymore. Run `dots brew-check` first if you're not sure the
# tools themselves are installed.
#
# What's left here is config drift that only makes sense to check from
# inside this repo: the pinned Hugo version vs. what's actually installed,
# whether node_modules is populated, whether the Obsidian drafts folder
# exists, whether WEBSITE_REPO is set. None of that is "install a program" —
# it's "is this checkout set up correctly."
#
# Usage:
#   scripts/doctor.sh          # report
#   scripts/doctor.sh --quiet  # print only problems

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "doctor: not inside a git repository." >&2
  echo "        Run this from the website repo — the scripts locate it with git." >&2
  exit 1
}
cd "$REPO_ROOT" || exit 1

QUIET=false
for arg in "$@"; do
  case "$arg" in
    --quiet|-q) QUIET=true ;;
    --help|-h) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

MISSING=0

heading() { $QUIET || printf '\n\033[1m%s\033[0m\n' "$1"; }
ok()      { $QUIET || printf '  \033[32m✓\033[0m %-14s %s\n' "$1" "${2:-}"; }
warn() {
  local name="$1" state="$2" needed="$3" fix="$4"
  printf '  \033[33m⚠\033[0m %-14s %s\n' "$name" "$state"
  printf '      Needed for: %s\n' "$needed"
  printf '      Fix:        %s\n' "$fix"
  MISSING=$((MISSING + 1))
}

$QUIET || printf '\033[1mChecking this checkout is configured to build and publish the site.\033[0m\n'
$QUIET || printf '(Tool presence is checked separately — run: dots brew-check)\n'

heading "SETUP — where things live"

HUGO_V=""
command -v hugo >/dev/null 2>&1 && HUGO_V="$(hugo version 2>/dev/null | awk '{print $2}')"

if [[ -z "$HUGO_V" ]]; then
  warn "hugo" "not found" "building the site at all" "dots brew-check (or: brew install hugo)"
else
  # The pin in .hugo-version tracks what Cloudflare Workers Builds' own
  # HUGO_VERSION build variable is set to (dashboard-managed, not read from
  # this repo — see docs/operations.md). A local version ahead of it can use
  # features the deploy cannot, so the build passes here and fails there —
  # the one drift worth naming explicitly.
  PINNED="$(cat .hugo-version 2>/dev/null)"
  LOCAL="$(printf '%s' "$HUGO_V" | sed -E 's/^v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
  if [[ -z "$PINNED" ]]; then
    warn "hugo pin" "could not read a version from .hugo-version" \
      "the live build to behave like this one" "check .hugo-version exists and is readable"
  elif [[ "$LOCAL" == "$PINNED" ]]; then
    ok "hugo pin" "local $LOCAL matches the deploy ($PINNED)"
  else
    warn "hugo pin" "local $LOCAL, deploy builds with $PINNED" \
      "the live build to behave like this one" \
      "echo $LOCAL > .hugo-version (once the matching .deb is published), then update Cloudflare Workers Builds's HUGO_VERSION build variable to match"
  fi

  if [[ "$HUGO_V" == *extended* ]]; then
    ok "hugo edition" "extended"
  else
    warn "hugo edition" "not the extended build" \
      "matching the deploy, which uses extended" "brew install hugo (Homebrew ships extended)"
  fi
fi

if [[ -d node_modules ]]; then
  ok "node_modules" "installed"
else
  warn "node_modules" "not installed" \
    "the pinned versions of html-validate and stylelint used by 'preflight --full' (falls back to npx otherwise, slower and unpinned)" \
    "npm ci"
fi

# Drafts live outside the repo, in the Obsidian vault. That is a real
# dependency on one machine's setup, so doctor names it rather than letting
# `newpost.sh` be the thing that discovers it.
DRAFTS_ROOT="${WEBSITE_DRAFTS_DIR:-$HOME/Notes/07 Blog/Drafts}"
if [[ -d "$DRAFTS_ROOT" ]]; then
  ok "drafts" "$DRAFTS_ROOT"
else
  warn "drafts" "no folder at $DRAFTS_ROOT" \
    "new drafts, which are written outside the repo" \
    "set WEBSITE_DRAFTS_DIR to your drafts folder, or create that path"
fi

if [[ -n "${WEBSITE_REPO:-}" ]]; then
  ok "WEBSITE_REPO" "$WEBSITE_REPO"
else
  warn "WEBSITE_REPO" "not set" \
    "running \`site\` from outside the repo" "set WEBSITE_REPO to $REPO_ROOT"
fi

# --- Summary ----------------------------------------------------------------
echo
if [[ $MISSING -gt 0 ]]; then
  printf '\033[33m%d item(s) above need attention.\033[0m\n' "$MISSING"
else
  printf '\033[32mThis checkout is configured correctly.\033[0m\n'
fi
exit 0
