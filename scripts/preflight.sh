#!/usr/bin/env bash
# Pre-push gate for the deploy-critical checks you want locally before a push.
# CI runs `--full` for the slower structural and accessibility checks.
#
# Default local gate:
#   1. published drafts      — content/ must not contain draft: true
#   2. image policy          — raster sources must be AVIF or allowed companions/icons
#   3. hugo --minify         — fails on ERROR, surfaces WARN (missing figure alt etc.)
#   4. content resources     — source Markdown cover blocks point at real files
#   4b. cite-key cross-ref   — advisory: cite keys missing from Zotero / without a vault note
#   5. source junk files     — fail if OS/editor metadata sits in Hugo inputs
#   6. generated junk files  — fail if OS/editor metadata lands in public/
#   7. checks/feed-lint.py   — RSS/JSON Feed well-formedness + absolute URLs
#   8. csp-hashes.sh --check — CSP hash drift against the fresh build
#   8b. security.txt sig     — RFC 9116 clearsignature present, valid, unexpired
#   9. published references  — every internal src/href/srcset/feed URL in the
#                               output must resolve to a published file; guards
#                               the build.publishResources=false resource pattern
#   10. page-size-lint.py    — oversized HTML pages relative to this site's norms
#   11. image-display-lint.py — image candidates too small for their rendered slot
#
# Full mode adds:
#   12. html-validate        — HTML5 validation of every page
#   13. stylelint            — CSS lint (rules tuned in .stylelintrc.json)
#   14. checks/a11y-lint.py  — content images without alt + heading-level skips
#   15. lychee --offline     — internal links/files in public/
#
# StaticHost deploys on push independently of GitHub Actions, so the default
# gate stays focused on "will this build and publish correctly right now?"
#
# Usage:
#   scripts/preflight.sh              # local deploy gate
#   scripts/preflight.sh --strict     # fail on Hugo WARN lines too
#   scripts/preflight.sh --full       # add the slower CI-grade checks

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
step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
pass() { printf '\033[32m✓ %s\033[0m\n' "$1"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$1"; FAILURES=$((FAILURES + 1)); }

step "published drafts"
if DRAFT_OUT=$(python3 scripts/checks/draft-lint.py content 2>&1); then
  pass "$DRAFT_OUT"
else
  echo "$DRAFT_OUT"
  fail "draft content is present in the publishable content tree"
fi

step "source image policy"
if IMAGE_OUT=$(python3 scripts/checks/image-policy-lint.py assets content static 2>&1); then
  pass "$IMAGE_OUT"
else
  echo "$IMAGE_OUT"
  fail "unoptimized raster sources (use the image helper before publishing)"
fi

step "hugo build"
BUILD_OUT=$(hugo --minify 2>&1)
BUILD_RC=$?
WARNINGS=$(grep -c '^WARN' <<<"$BUILD_OUT" || true)
if [[ $BUILD_RC -ne 0 ]]; then
  grep -E '^(ERROR|Error)' <<<"$BUILD_OUT" | head -10
  fail "build failed"
elif [[ $WARNINGS -gt 0 ]]; then
  grep '^WARN' <<<"$BUILD_OUT"
  if $STRICT; then
    fail "build passed with $WARNINGS warning(s) (--strict)"
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
  fail "content resource issues (e.g. cover block references a missing file)"
fi

step "source junk files"
SOURCE_JUNK_OUT=$(find assets content data layouts static -type f \( -name '.DS_Store' -o -name 'Thumbs.db' -o -name 'desktop.ini' \) -print 2>/dev/null)
if [[ -z "$SOURCE_JUNK_OUT" ]]; then
  pass "no OS/editor metadata in Hugo source directories"
else
  echo "$SOURCE_JUNK_OUT"
  fail "source tree contains OS/editor metadata (these can be copied into public/ on build)"
fi

step "generated junk files"
JUNK_OUT=$(find public -type f \( -name '.DS_Store' -o -name 'Thumbs.db' -o -name 'desktop.ini' \) -print)
if [[ -z "$JUNK_OUT" ]]; then
  pass "no OS/editor metadata in public/"
else
  echo "$JUNK_OUT"
  fail "generated output contains OS/editor metadata"
fi

step "feed lint"
if FEED_OUT=$(python3 scripts/checks/feed-lint.py public 2>&1); then
  pass "$FEED_OUT"
else
  echo "$FEED_OUT" | head -20
  fail "feed validation issues"
fi

step "CSP hashes"
if bash scripts/csp-hashes.sh --check --no-build >/dev/null 2>&1; then
  pass "CSP hashes match static/_headers"
else
  bash scripts/csp-hashes.sh --check --no-build 2>&1 | tail -5
  fail "CSP hash drift — run scripts/csp-hashes.sh and update static/_headers"
fi

step "security.txt signature"
if SEC_OUT=$(scripts/sign-security-txt.sh --check 2>&1); then
  pass "security.txt $SEC_OUT"
else
  echo "$SEC_OUT"
  fail "security.txt unsigned/tampered/expired — run scripts/sign-security-txt.sh"
fi

step "published-reference scan"
if SCAN_OUT=$(python3 scripts/checks/published-reference-lint.py public 2>&1); then
  pass "$SCAN_OUT"
else
  echo "$SCAN_OUT" | head -20
  fail "dangling references (a template likely builds a URL by string instead of invoking the resource)"
fi

step "page size lint"
if PAGE_OUT=$(python3 scripts/checks/page-size-lint.py public 2>&1); then
  pass "$PAGE_OUT"
else
  echo "$PAGE_OUT"
  fail "oversized HTML pages"
fi

step "image display lint"
if DISPLAY_OUT=$(python3 scripts/checks/image-display-lint.py public 2>&1); then
  pass "$DISPLAY_OUT"
else
  echo "$DISPLAY_OUT"
  fail "images likely to render soft or blurry on site"
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
      fail "html-validate errors (rules tuned in .htmlvalidate.json)"
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
      fail "stylelint errors (rules tuned in .stylelintrc.json)"
    fi
  else
    echo "node/npx not found — skipping stylelint (npm ci); CI still runs it"
  fi

  step "content a11y lint"
  if A11Y_OUT=$(python3 scripts/checks/a11y-lint.py public 2>&1); then
    pass "content a11y lint clean"
  else
    tail -20 <<<"$A11Y_OUT"
    fail "content a11y issues (missing alt / heading skips)"
  fi

  step "internal links (lychee --offline)"
  if command -v lychee >/dev/null; then
    if LYCHEE_OUT=$(lychee --offline --root-dir "$REPO_ROOT/public" --no-progress public/ 2>&1); then
      pass "internal links resolve"
    else
      tail -15 <<<"$LYCHEE_OUT"
      fail "broken internal links"
    fi
  else
    echo "lychee not installed — skipping (brew install lychee); CI still runs it"
  fi
fi

echo
if [[ $FAILURES -eq 0 ]]; then
  printf '\033[32mPreflight passed — safe to push.\033[0m\n'
else
  printf '\033[31mPreflight failed: %d issue(s).\033[0m\n' "$FAILURES"
  exit 1
fi
