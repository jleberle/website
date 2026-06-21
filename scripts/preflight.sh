#!/usr/bin/env bash
# Pre-push gate: everything CI checks, plus an internal-integrity scan, in one
# command before publishing. Run as: scripts/preflight.sh && git push
#
#   1. hugo --minify        — fails on ERROR, surfaces WARN (missing figure alt etc.)
#   2. html-validate        — HTML5 validation of every page (same as CI; rules
#                              tuned in .htmlvalidate.json)
#   3. a11y-lint.py          — content images without alt + heading-level skips
#   4. csp-hashes.sh --check — CSP hash drift against the fresh build (same as CI)
#   5. lychee --offline      — internal links/files in public/ (CI cron covers external)
#   6. reference scan        — every internal src/href/srcset/feed URL in the
#                              output must resolve to a published file; guards the
#                              build.publishResources=false resource-invocation
#                              pattern (see hugo.yaml)
#
# This must stay in lockstep with .woodpecker.yml — StaticHost deploys on push
# independently of CI, so preflight is the only gate that can stop a bad deploy.
#
# Usage:
#   scripts/preflight.sh             # warnings are reported but don't fail
#   scripts/preflight.sh --strict    # hugo WARN lines also fail the gate

set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

STRICT=false
[[ "${1:-}" == "--strict" ]] && STRICT=true

FAILURES=0
step() { printf '\n\033[1m== %s\033[0m\n' "$1"; }
pass() { printf '\033[32m✓ %s\033[0m\n' "$1"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$1"; FAILURES=$((FAILURES + 1)); }

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
  HV_OUT=$("${HV[@]}" "public/**/*.html" 2>&1)
  if [[ $? -eq 0 ]]; then
    pass "html-validate clean"
  else
    tail -20 <<<"$HV_OUT"
    fail "html-validate errors (rules tuned in .htmlvalidate.json)"
  fi
else
  echo "node/npx not found — skipping html-validate (npm ci); CI still runs it"
fi

step "content a11y lint"
if A11Y_OUT=$(python3 scripts/a11y-lint.py public 2>&1); then
  pass "content a11y lint clean"
else
  tail -20 <<<"$A11Y_OUT"
  fail "content a11y issues (missing alt / heading skips)"
fi

step "CSP hashes"
if bash scripts/csp-hashes.sh --check --no-build >/dev/null 2>&1; then
  pass "CSP hashes match static/_headers"
else
  bash scripts/csp-hashes.sh --check --no-build 2>&1 | tail -5
  fail "CSP hash drift — run scripts/csp-hashes.sh and update static/_headers"
fi

step "internal links (lychee --offline)"
if command -v lychee >/dev/null; then
  LYCHEE_OUT=$(lychee --offline --root-dir "$REPO_ROOT/public" --no-progress public/ 2>&1)
  if [[ $? -eq 0 ]]; then
    pass "internal links resolve"
  else
    tail -15 <<<"$LYCHEE_OUT"
    fail "broken internal links"
  fi
else
  echo "lychee not installed — skipping (brew install lychee); CI cron still checks links"
fi

step "published-reference scan"
SCAN_OUT=$(python3 - <<'PY'
import re, os, sys, html, urllib.parse

pub = 'public'
exists = set()
for root, _, files in os.walk(pub):
    for f in files:
        exists.add(os.path.relpath(os.path.join(root, f), pub))

def check(url, src, missing):
    u = urllib.parse.urlparse(url)
    if u.scheme and u.netloc not in ('', 'jaredeberle.org'):
        return
    p = urllib.parse.unquote(u.path)
    if not p.startswith('/'):
        return
    p = p.lstrip('/')
    if not p:
        return
    cand = [p, p + 'index.html', p.rstrip('/') + '/index.html']
    if not any(c in exists for c in cand):
        missing.add((src, url))

missing = set()
for root, _, files in os.walk(pub):
    for f in files:
        if not f.endswith(('.html', '.xml', '.json')):
            continue
        rel = os.path.relpath(os.path.join(root, f), pub)
        txt = open(os.path.join(root, f), encoding='utf8', errors='ignore').read()
        # feeds embed entity-escaped HTML; unescape so quoted URLs parse cleanly
        txt = html.unescape(txt)
        for m in re.findall(r'(?:src|href|poster|content|data-lightbox-src)=(?:"([^"]+)"|([^ >"\']+))', txt):
            check(m[0] or m[1], rel, missing)
        for ss in re.findall(r'srcset=(?:"([^"]+)"|\'([^\']+)\')', txt):
            for part in (ss[0] or ss[1]).split(','):
                check(part.strip().split(' ')[0], rel, missing)
        for m in re.findall(r'https://jaredeberle\.org(/[^"\\\s<>)]+)', txt):
            check(m, rel, missing)

for src, url in sorted(missing):
    print(f"  {src}  ->  {url}")
sys.exit(1 if missing else 0)
PY
)
if [[ $? -eq 0 ]]; then
  pass "every internal reference resolves to a published file"
else
  echo "$SCAN_OUT" | head -20
  fail "dangling references (a template likely builds a URL by string instead of invoking the resource)"
fi

echo
if [[ $FAILURES -eq 0 ]]; then
  printf '\033[32mPreflight passed — safe to push.\033[0m\n'
else
  printf '\033[31mPreflight failed: %d issue(s).\033[0m\n' "$FAILURES"
  exit 1
fi
