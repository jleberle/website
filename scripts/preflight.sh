#!/usr/bin/env bash
# Pre-push gate. Two tiers, split by ONE question:
#
#   if this reaches the live site wrong, can it be taken back?
#
# Cloudflare Workers Builds deploys on every push, independently of GitHub
# Actions, and public/ is untracked — so CI is not a gate, it is a report that arrives after
# the site is already live. That is what makes the tiers mean something. A
# BLOCKING failure is one where the push itself does damage that a follow-up
# commit cannot undo (or where the site simply fails to build). Everything else
# is an ADVISORY: printed locally so it can be fixed before pushing, but never
# a reason to stop, because a second commit fixes it completely.
#
# Advisories are not optional, they are deferred: `--full` (what CI runs)
# promotes every advisory to a failure. So locally `--full` also answers "what
# will CI say about this?" without pushing.
#
# BLOCKING — cannot be walked back:
#   1. published drafts      — content/ must not contain draft: true (a post you
#                               believe is live and isn't; silent by nature)
#   2. image metadata        — EXIF/IPTC/XMP (incl. GPS) on a published raster;
#                               once served it is scraped, syndicated, archived
#   3. hugo --minify         — fails on ERROR, surfaces WARN; a build error means
#                               Cloudflare Workers Builds publishes nothing
#   4. content resources     — cover blocks pointing at files that don't exist
#   5. source junk files     — Thumbs.db/desktop.ini in Hugo inputs get copied
#                               into the build (.DS_Store is in .gitignore, so it
#                               cannot be committed and is not checked here)
#   6. checks/feed-lint.py   — RSS/JSON Feed well-formedness + absolute URLs, and
#                               reading-feed <link> stability. THE sharpest one:
#                               Micro.blog dedupes on <link>, so a changed link
#                               creates duplicate posts on eberle.blog that must
#                               be deleted by hand (see hugo.yaml `services.rss`)
#   7. published references  — every internal src/href/srcset/feed URL in the
#                               output must resolve to a published file; guards
#                               the build.publishResources=false resource pattern
#
# REGENERATED, not checked — the answer is mechanical, so producing it beats
# failing and making a human retype it. ship.sh commits with `git add -A`, so
# the refreshed files ride along with the push:
#   - data/writing-log.json   (writing-log.py)
#   - static/_headers CSP     (csp-hashes.sh --write; prints every hash it moves)
#   - public/_headers digests (digest-fields.sh)
#
# ADVISORY — real, but a follow-up commit fixes them with no trace:
#   taxonomy facets, tag vocabulary, series naming, graph connections,
#   image policy, page size, image display
#
# LOCAL-ONLY ADVISORY (warn_local) — the Obsidian template drift check. Never
# promoted by --full, because CI has no vault and would be claiming an
# enforcement it cannot perform.
#
# Full mode (CI) adds, and promotes all advisories to failures:
#   html-validate, stylelint, checks/a11y-lint.py, lychee --offline
#
# NOT here at all: the security.txt signature. Nothing in a commit can
# invalidate it — only the calendar — so it belongs on the weekly CI schedule
# with lead time, not on the push path where it can wall off a writer who
# doesn't hold the key. See .github/workflows/site-checks.yml.
#
# Usage:
#   scripts/preflight.sh              # blocking tier + advisories
#   scripts/preflight.sh --strict     # fail on Hugo WARN lines too
#   scripts/preflight.sh --full       # the CI gate: advisories become failures

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT" || exit 1

STRICT=false
FULL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=true ;;
    --full) FULL=true ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

FAILURES=0
ADVISORIES=0
step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
pass() { printf '\033[32m✓ %s\033[0m\n' "$1"; }

# Every failure takes two arguments, and the second is not optional:
#
#   fail "what is wrong, in plain words"  "what to do about it"
#
# The check's own output above already names the files. What it cannot say is
# what the person reading it should do next, and "preflight failed" with no
# next step is the same as no message at all for anyone who did not write the
# check. Requiring the fix line as an argument is what keeps it that way —
# a new check cannot be added without answering the question.
fail() {
  printf '\033[31m✗ %s\033[0m\n' "$1"
  printf '   \033[1mFix:\033[0m %s\n' "$2"
  FAILURES=$((FAILURES + 1))
}

# An advisory is a real defect that a follow-up commit fixes completely, so it
# does not stop a push. Under --full (the CI gate) it is a failure like any
# other — deferred, not forgiven.
warn() {
  if $FULL; then
    fail "$1" "$2"
  else
    printf '\033[33m⚠ %s\033[0m\n' "$1"
    printf '   \033[1mFix:\033[0m %s\n' "$2"
    printf '   \033[2mNot blocking — you can push now. CI will fail on it.\033[0m\n'
    ADVISORIES=$((ADVISORIES + 1))
  fi
}

# An advisory that CI genuinely cannot make: it depends on something only this
# machine has (the Obsidian vault). --full must NOT promote these, because
# --full's whole claim is that it shows what CI will say — and for these, CI
# says nothing at all. Saying "CI will fail on it" here would be a lie of
# exactly the kind this gate's messages exist to avoid.
warn_local() {
  printf '\033[33m⚠ %s\033[0m\n' "$1"
  printf '   \033[1mFix:\033[0m %s\n' "$2"
  printf '   \033[2mNot blocking, and CI cannot check this — the vault only exists here.\033[0m\n'
  ADVISORIES=$((ADVISORIES + 1))
}

step "published drafts"
if DRAFT_OUT=$(python3 scripts/checks/draft-lint.py content 2>&1); then
  pass "$DRAFT_OUT"
else
  echo "$DRAFT_OUT"
  fail "A post marked \`draft: true\` is sitting in content/, so it will NOT appear on the site." \
       "Either finish it and remove the \`draft: true\` line, or move it back out to your drafts folder. Listed above."
fi

step "taxonomy facets"
if FACET_OUT=$(python3 scripts/checks/taxonomy-facet-lint.py content 2>&1); then
  pass "$FACET_OUT"
else
  echo "$FACET_OUT"
  warn "A time period (like 1970s) is filed under \`tags:\`, which is for subjects." \
       "Move that value into the \`eras:\` list in the post front matter. Tags say what a piece is ABOUT; eras say what period it covers."
fi

step "tag vocabulary"
if VOCAB_OUT=$(python3 scripts/checks/tag-vocabulary-lint.py content 2>&1); then
  pass "$VOCAB_OUT"
else
  echo "$VOCAB_OUT"
  warn "A tag is not on the approved subject list, so it would create a new topic page nobody links to." \
       "Either correct the spelling to match an existing tag, or — if it is genuinely a new subject — add it to VOCABULARY in scripts/checks/tag-vocabulary-lint.py in the same commit."
fi

step "series naming"
if SERIES_OUT=$(python3 scripts/checks/series-lint.py content 2>&1); then
  pass "$SERIES_OUT"
else
  echo "$SERIES_OUT"
  warn "One series is spelled two different ways, so its parts would split into two separate series." \
       "Pick one spelling and use it in the \`series:\` line of every part. The variants are listed above."
fi

step "graph connections"
if CONN_OUT=$(python3 scripts/checks/connection-lint.py content 2>&1); then
  pass "$CONN_OUT"
else
  echo "$CONN_OUT"
  warn "A post is not connected to anything — no tags and no sources — so nothing on the site links to it." \
       "Add at least one \`tags:\` or \`sources:\` entry so it appears on a topic or bibliography page. The message above says which post and which field."
fi

step "Obsidian templates"
# Advisory, and skipped entirely when the vault isn't on this machine (exit 3),
# for the same reason the writing-log census is: only one machine needs
# Obsidian for the repo copy to stay meaningful. Divergence is also fully
# reversible — the templates are inputs to drafting, not to the published site,
# so nothing about a push is made wrong by them being out of step.
set +e
TPL_OUT=$(scripts/sync-templates.sh --check 2>&1)
TPL_RC=$?
set -e
case $TPL_RC in
  0|3) pass "$TPL_OUT" ;;
  *)
    echo "$TPL_OUT"
    warn_local "The Obsidian draft templates differ between the repo and the vault." \
               "Whichever copy you edited is the one to keep: scripts/sync-templates.sh --from-vault (you edited in Obsidian) or --to-vault (you edited in the repo)."
    ;;
esac

step "source image policy"
if IMAGE_OUT=$(python3 scripts/checks/image-policy-lint.py assets content static 2>&1); then
  pass "$IMAGE_OUT"
else
  echo "$IMAGE_OUT"
  warn "Image(s) are in a heavy format (JPEG/PNG/WebP) instead of AVIF, so pages load slower than they need to." \
       "Run scripts/to-avif.sh --replace on the files listed above, or add them with scripts/add-images.sh, which converts automatically."
fi

step "image metadata"
if META_OUT=$(python3 scripts/checks/image-metadata-lint.py assets content static 2>&1); then
  pass "$META_OUT"
else
  echo "$META_OUT"
  fail "Image(s) still carry hidden camera data — which can include the GPS coordinates of where the photo was taken." \
       "Strip it by re-running the image through scripts/to-avif.sh --replace, or scripts/add-images.sh. Once published this data is copied by scrapers and archives and cannot be recalled."
fi

step "writing log"
# Regenerates rather than merely checking: this repo gains content commits most
# weeks, so "the JSON is out of date" is the normal state before a push, not an
# error. ship.sh commits with `git add -A`, so the refreshed
# data/writing-log.json rides along with whatever else is being pushed. Runs
# before the build because Hugo reads the file it writes.
#
# Deliberately does NOT census the vault -- that is `scripts/log-writing.sh`,
# run by hand. Rebuilding here reads only committed inputs (git history and
# data/observations/), so it produces the same answer on every machine and in
# CI, and a push never silently re-dates vault writing to whatever today's
# mtimes happen to say.
#
# Exit 3 means a git source repo isn't on this machine. That's a skip, not a
# failure; the committed JSON stands.
set +e
WLOG_OUT=$(python3 scripts/writing-log.py --allow-missing 2>&1)
WLOG_RC=$?
set -e
case $WLOG_RC in
  0) pass "$WLOG_OUT" ;;
  3) pass "$WLOG_OUT" ;;
  *) echo "$WLOG_OUT"; fail "The writing log (data/writing-log.json) could not be rebuilt from git history." \
       "Read the error above — this is a bug in scripts/writing-log.py or a damaged git checkout, not something you did wrong in a post." ;;
esac

step "hugo build"
BUILD_OUT=$(hugo --minify 2>&1)
BUILD_RC=$?
WARNINGS=$(grep -c '^WARN' <<<"$BUILD_OUT" || true)
if [[ $BUILD_RC -ne 0 ]]; then
  grep -E '^(ERROR|Error)' <<<"$BUILD_OUT" | head -10
  fail "Hugo could not build the site. Nothing would be published at all." \
       "The first error above names the file and line. A missing closing shortcode tag or a broken front-matter line is the usual cause."
elif [[ $WARNINGS -gt 0 ]]; then
  grep '^WARN' <<<"$BUILD_OUT"
  if $STRICT; then
    fail "The site built, but with $WARNINGS warning(s), and --strict treats those as errors." \
       "Each WARN line above names its file. Missing image alt text is the most common one."
  else
    pass "build passed ($WARNINGS warning(s) above)"
  fi
else
  pass "build passed, no warnings"
fi

step "content resources"
if RESOURCE_OUT=$(python3 scripts/checks/content-resource-lint.py content 2>&1); then
  pass "$RESOURCE_OUT"
else
  echo "$RESOURCE_OUT"
  fail "A post points at an image file that is not there, so it would publish with a broken image." \
       "Check the filename in the post front matter against the files actually in its folder — usually a typo or an image that was never copied in. Listed above."
fi

step "source junk files"
# Only the two files that can actually reach the live site. `.DS_Store` used to
# be checked here and no longer is: it's in .gitignore, so it cannot be
# committed, and Cloudflare Workers Builds builds from a fresh clone that never contains one.
# The matching scan of public/ is gone for the same reason — public/ is
# untracked and rebuilt in a clean container, so anything found there was a
# local artifact that was never going to ship. Thumbs.db and desktop.ini are
# NOT gitignored, so on a Windows machine they remain committable and real.
SOURCE_JUNK_OUT=$(find assets content data layouts static -type f \( -name 'Thumbs.db' -o -name 'desktop.ini' \) -print 2>/dev/null)
if [[ -z "$SOURCE_JUNK_OUT" ]]; then
  pass "no committable OS/editor metadata in Hugo source directories"
else
  echo "$SOURCE_JUNK_OUT"
  fail "Windows junk files (Thumbs.db / desktop.ini) are sitting in the site source and would be copied onto the live site." \
       "Delete the files listed above; nothing needs them."
fi

step "feed lint"
if FEED_OUT=$(python3 scripts/checks/feed-lint.py public 2>&1); then
  pass "$FEED_OUT"
else
  echo "$FEED_OUT" | head -20
  fail "Something is wrong with the RSS/JSON feeds." \
       "Read the message above — it explains the specific problem and what to do. If it mentions changed reading links, take it seriously: that creates duplicate posts on eberle.blog that have to be deleted by hand."
fi

step "CSP hashes"
# Regenerated, not checked. Drift here is live-breaking (a stale hash means the
# browser blocks a real inline script in production), but the correct value is
# fully determined by the build that just ran — so failing only made a human
# copy-paste a hash that the script already knew. Writing it keeps the push
# unblocked AND keeps production correct, which checking could only do one of.
# csp-hashes.sh --write prints every hash it adds or removes with the source
# that produced it, so a newly introduced inline script still shows up here.
if CSP_OUT=$(bash scripts/csp-hashes.sh --write --no-build 2>&1); then
  pass "$CSP_OUT"
else
  echo "$CSP_OUT"
  fail "The security header in static/_headers could not be updated to match this build." \
       "Read the error above. Until this is resolved, scripts on the live site may be blocked by the browser."
fi

step "Content-Digest headers"
if DIGEST_OUT=$(bash scripts/digest-fields.sh --no-build 2>&1); then
  pass "$DIGEST_OUT"
else
  echo "$DIGEST_OUT"
  fail "Could not write the Content-Digest headers for the feeds." \
       "Read the error above — this is a problem in scripts/digest-fields.sh, not in your writing."
fi

step "published-reference scan"
if SCAN_OUT=$(python3 scripts/checks/published-reference-lint.py public 2>&1); then
  pass "$SCAN_OUT"
else
  echo "$SCAN_OUT" | head -20
  fail "The built site links to file(s) that were never published — visitors would get a 404 or a broken image." \
       "Each line above shows which page links to which missing file. If it is an image in a post, the template needs to reference it as a Hugo resource rather than writing out the path by hand (see docs/images.md)."
fi

step "page size lint"
if PAGE_OUT=$(python3 scripts/checks/page-size-lint.py public 2>&1); then
  pass "$PAGE_OUT"
else
  echo "$PAGE_OUT"
  warn "A page has grown past the size limit set for this site." \
       "See the Known growth limits table in docs/operations.md — this usually means a list page needs splitting or paginating, not that a single post is too long."
fi

step "image display lint"
if DISPLAY_OUT=$(python3 scripts/checks/image-display-lint.py public 2>&1); then
  pass "$DISPLAY_OUT"
else
  echo "$DISPLAY_OUT"
  warn "Image(s) are too small for the space the design puts them in, so they will look soft or blurry." \
       "Re-add them from a higher-resolution original with scripts/add-images.sh. Each line above gives the size available and the size supplied."
fi

if $FULL; then
  step "html-validate (all pages)"
  # Prefer the version pinned in package.json (run `npm ci` once); fall back to
  # npx so the gate still works on a machine without node_modules installed.
  if [[ -x node_modules/.bin/html-validate ]]; then
    HV=(node_modules/.bin/html-validate)
  elif command -v npx >/dev/null; then
    echo "node_modules not installed — run 'npm ci' to use the pinned version; falling back to npx"
    HV=(npx --yes html-validate)
  else
    HV=()
  fi
  if [[ ${#HV[@]} -gt 0 ]]; then
    if HV_OUT=$("${HV[@]}" "public/**/*.html" 2>&1); then
      pass "html-validate clean"
    else
      tail -20 <<<"$HV_OUT"
      fail "The generated HTML is invalid." \
       "The output above gives the file, line, and rule. This nearly always comes from a template or a raw HTML block in a post, not from ordinary Markdown."
    fi
  else
    echo "node/npx not found — skipping html-validate (npm ci); CI still runs it"
  fi

  step "stylelint"
  # Prefer the version pinned in package.json (run `npm ci` once); fall back to
  # npx so the gate still works on a machine without node_modules installed.
  if [[ -x node_modules/.bin/stylelint ]]; then
    SL=(node_modules/.bin/stylelint)
  elif command -v npx >/dev/null; then
    echo "node_modules not installed — run 'npm ci' to use the pinned version; falling back to npx"
    SL=(npx --yes stylelint)
  else
    SL=()
  fi
  if [[ ${#SL[@]} -gt 0 ]]; then
    if SL_OUT=$("${SL[@]}" "assets/css/**/*.css" 2>&1); then
      pass "stylelint clean"
    else
      tail -20 <<<"$SL_OUT"
      fail "The CSS has lint errors." \
       "The output above gives the file, line, and rule. Run: npx stylelint --fix \"assets/css/**/*.css\" to fix the mechanical ones automatically."
    fi
  else
    echo "node/npx not found — skipping stylelint (npm ci); CI still runs it"
  fi

  step "content a11y lint"
  if A11Y_OUT=$(python3 scripts/checks/a11y-lint.py public 2>&1); then
    pass "content a11y lint clean"
  else
    tail -20 <<<"$A11Y_OUT"
    fail "Accessibility problems in the published pages — images without alt text, or headings that skip a level." \
       "Add alt text to the images listed above. For headings, do not jump from ## straight to ####; screen-reader users navigate by that structure."
  fi

  step "internal links (lychee --offline)"
  if command -v lychee >/dev/null; then
    if LYCHEE_OUT=$(lychee --offline --root-dir "$REPO_ROOT/public" --no-progress public/ 2>&1); then
      pass "internal links resolve"
    else
      tail -15 <<<"$LYCHEE_OUT"
      fail "Link(s) inside the site point at pages that do not exist." \
       "Each broken link is listed above with the page it appears on. A renamed or deleted post is the usual cause."
    fi
  else
    echo "lychee not installed — skipping (brew install lychee); CI still runs it"
  fi
fi

echo
if [[ $FAILURES -gt 0 ]]; then
  printf '\033[31mPreflight failed: %d blocking issue(s).\033[0m\n' "$FAILURES"
  if [[ $ADVISORIES -gt 0 ]]; then
    printf '\033[33m%d advisory(ies) above as well.\033[0m\n' "$ADVISORIES"
  fi
  printf 'Nothing was pushed. Each ✗ above names the file and the fix.\n'
  exit 1
fi

if [[ $ADVISORIES -gt 0 ]]; then
  printf '\033[32mPreflight passed — safe to push.\033[0m\n'
  printf '\033[33m%d advisory(ies) above: not blocking, because a follow-up commit\n' "$ADVISORIES"
  printf 'fixes them completely. CI will fail on them, so clear them soon.\033[0m\n'
else
  printf '\033[32mPreflight passed — safe to push.\033[0m\n'
fi
