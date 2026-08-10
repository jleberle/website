#!/usr/bin/env bash
# Report whether this machine can build, check, and publish the site — and for
# anything missing, say what it is needed FOR and the exact command to install
# it.
#
# This exists because the prerequisites were previously a bulleted list in the
# README with no way to test them. The failure mode that produced it: a missing
# tool surfaces as a check erroring out mid-preflight, which reads as "the site
# is broken" rather than "one program isn't installed". Sorting the tools by
# what actually breaks without them is the useful part — three of the seven
# only matter for `preflight --full`, and one only for a task that runs twice a
# year, so a bare "install these seven things" overstates the setup cost.
#
# Usage:
#   scripts/doctor.sh          # report; exit 1 if a REQUIRED tool is missing
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
    --help|-h) sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

MISSING_REQUIRED=0
MISSING_OPTIONAL=0

heading() { $QUIET || printf '\n\033[1m%s\033[0m\n' "$1"; }
note()    { $QUIET || printf '\033[2m%s\033[0m\n' "$1"; }
ok()      { $QUIET || printf '  \033[32m✓\033[0m %-14s %s\n' "$1" "${2:-}"; }

# Every problem prints the same three things, in the same order: what is
# missing, what it is needed for, and the one command that fixes it.
problem() {
  local mark="$1" name="$2" state="$3" needed="$4" fix="$5"
  printf '  %s %-14s %s\n' "$mark" "$name" "$state"
  printf '      Needed for: %s\n' "$needed"
  printf '      Install:    %s\n' "$fix"
}

require() {
  local cmd="$1" name="$2" needed="$3" fix="$4" version="${5:-}"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$name" "$version"
  else
    problem $'\033[31m✗\033[0m' "$name" "not found" "$needed" "$fix"
    MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
  fi
}

optional() {
  local cmd="$1" name="$2" needed="$3" fix="$4" version="${5:-}"
  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$name" "$version"
  else
    problem $'\033[33m⚠\033[0m' "$name" "not found" "$needed" "$fix"
    MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
  fi
}

$QUIET || printf '\033[1mChecking what this machine needs to build and publish the site.\033[0m\n'

# --- Required ---------------------------------------------------------------
heading "REQUIRED — nothing builds or passes its checks without these"

HUGO_V=""
command -v hugo >/dev/null 2>&1 && HUGO_V="$(hugo version 2>/dev/null | awk '{print $2}')"
require hugo "hugo" \
  "building the site at all — this is the site generator" \
  "brew install hugo" "$HUGO_V"

PY_V=""
command -v python3 >/dev/null 2>&1 && PY_V="$(python3 --version 2>&1 | awk '{print $2}')"
require python3 "python3" \
  "almost every check that runs before a push" \
  "brew install python (or use the macOS system python3)" "$PY_V"

GIT_V=""
command -v git >/dev/null 2>&1 && GIT_V="$(git --version 2>/dev/null | awk '{print $3}')"
require git "git" \
  "publishing — a push is what deploys the site" \
  "brew install git" "$GIT_V"

# `identify` rather than `magick`: it ships under every ImageMagick major
# version, while the unified `magick` binary is absent from Ubuntu's package.
# scripts/checks/image-metadata-lint.py calls it, and that check BLOCKS a push,
# so a missing ImageMagick stops publishing outright.
IM_V=""
command -v identify >/dev/null 2>&1 && IM_V="$(identify -version 2>/dev/null | awk 'NR==1 {print $3}')"
require identify "imagemagick" \
  "the image metadata check, which blocks a push (it looks for GPS data)" \
  "brew install imagemagick" "$IM_V"

# --- Optional: the --full gate ---------------------------------------------
heading "OPTIONAL — only for 'preflight --full', which is what CI runs"
note "  Without these, --full skips those checks locally and CI still catches them."

NODE_V=""
command -v node >/dev/null 2>&1 && NODE_V="$(node --version 2>/dev/null)"
optional node "node" \
  "the HTML and CSS checks in --full, and the accessibility run" \
  "brew install node" "$NODE_V"

if command -v node >/dev/null 2>&1; then
  if [[ -d node_modules ]]; then
    ok "node_modules" "installed"
  else
    problem $'\033[33m⚠\033[0m' "node_modules" "not installed" \
      "the pinned versions of html-validate and stylelint (--full falls back to npx, which is slower and unpinned)" \
      "npm ci"
    MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
  fi
fi

LY_V=""
command -v lychee >/dev/null 2>&1 && LY_V="$(lychee --version 2>/dev/null | awk '{print $2}')"
optional lychee "lychee" \
  "the internal link check in --full" \
  "brew install lychee" "$LY_V"

# --- Optional: occasional tasks --------------------------------------------
heading "OPTIONAL — occasional maintenance, not part of publishing"

GPG_V=""
command -v gpg >/dev/null 2>&1 && GPG_V="$(gpg --version 2>/dev/null | awk 'NR==1 {print $3}')"
optional gpg "gpg" \
  "re-signing security.txt, roughly once a year (CI warns 60 days ahead)" \
  "brew install gnupg" "$GPG_V"

CURL_V=""
command -v curl >/dev/null 2>&1 && CURL_V="$(curl --version 2>/dev/null | awk 'NR==1 {print $2}')"
optional curl "curl" \
  "looking up books by ISBN/DOI, and the dead-link archiver" \
  "brew install curl (macOS ships one already)" "$CURL_V"

# --- Configuration ----------------------------------------------------------
heading "SETUP — where things live"

# The pinned Hugo in statichost.yml is what actually builds the live site. A
# local version ahead of it can use features the deploy cannot, so the build
# passes here and fails there — the one drift worth naming explicitly.
PINNED="$(sed -n -E 's/^image: hugomods\/hugo:debian-git-([0-9]+\.[0-9]+\.[0-9]+)@sha256:.*/\1/p' statichost.yml 2>/dev/null)"
LOCAL="$(printf '%s' "${HUGO_V:-}" | sed -E 's/^v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/')"
if [[ -z "$PINNED" ]]; then
  printf '  \033[33m⚠\033[0m %-14s %s\n' "hugo pin" "could not read a version from statichost.yml"
elif [[ -z "$LOCAL" ]]; then
  : # hugo missing; already reported above
elif [[ "$LOCAL" == "$PINNED" ]]; then
  ok "hugo pin" "local $LOCAL matches the deploy ($PINNED)"
else
  printf '  \033[33m⚠\033[0m %-14s %s\n' "hugo pin" "local $LOCAL, deploy builds with $PINNED"
  printf '      Needed for: the live build to behave like this one\n'
  printf '      Install:    scripts/sync-hugo-version.sh (bumps the pin once the image exists)\n'
  MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
fi

if [[ "$(printf '%s' "${HUGO_V:-}")" == *extended* ]]; then
  ok "hugo edition" "extended"
elif [[ -n "${HUGO_V:-}" ]]; then
  printf '  \033[33m⚠\033[0m %-14s %s\n' "hugo edition" "not the extended build"
  printf '      Needed for: matching the deploy, which uses extended\n'
  printf '      Install:    brew install hugo (Homebrew ships extended)\n'
  MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
fi

# Drafts live outside the repo, in the Obsidian vault. That is a real
# dependency on one machine's setup, so doctor names it rather than letting
# `newpost.sh` be the thing that discovers it.
DRAFTS_ROOT="${WEBSITE_DRAFTS_DIR:-$HOME/Notes/07 Blog/Drafts}"
if [[ -d "$DRAFTS_ROOT" ]]; then
  ok "drafts" "$DRAFTS_ROOT"
else
  printf '  \033[33m⚠\033[0m %-14s %s\n' "drafts" "no folder at $DRAFTS_ROOT"
  printf '      Needed for: new drafts, which are written outside the repo\n'
  printf '      Install:    set WEBSITE_DRAFTS_DIR to your drafts folder, or create that path\n'
  MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
fi

if [[ -n "${WEBSITE_REPO:-}" ]]; then
  ok "WEBSITE_REPO" "$WEBSITE_REPO"
else
  printf '  \033[33m⚠\033[0m %-14s %s\n' "WEBSITE_REPO" "not set"
  printf '      Needed for: running `site` from outside the repo\n'
  printf '      Install:    set WEBSITE_REPO to %s\n' "$REPO_ROOT"
  MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
fi

# --- Summary ----------------------------------------------------------------
echo
if [[ $MISSING_REQUIRED -gt 0 ]]; then
  printf '\033[31m%d required tool(s) missing — the site cannot be built or published until they are installed.\033[0m\n' "$MISSING_REQUIRED"
  printf 'Install the ones marked ✗ above, then run this again.\n'
  exit 1
fi

if [[ $MISSING_OPTIONAL -gt 0 ]]; then
  printf '\033[32mReady to write and publish.\033[0m\n'
  printf '\033[33m%d optional item(s) above are unset or missing. Nothing is blocked by them.\033[0m\n' "$MISSING_OPTIONAL"
else
  printf '\033[32mEverything is installed and configured.\033[0m\n'
fi
exit 0
