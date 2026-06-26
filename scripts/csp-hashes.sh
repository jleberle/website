#!/usr/bin/env bash
# Recompute SHA-256 hash-sources for the Content-Security-Policy in
# static/_headers — both style-src (inline <style>) and script-src (inline
# <script>, excluding src= and ld+json). Run after Hugo upgrades or template
# changes that touch inline styles or scripts: a changed minifier or a changed
# inline script silently breaks a hash otherwise.
#
# Usage:
#   scripts/csp-hashes.sh              # print current hashes for copy-paste into _headers
#   scripts/csp-hashes.sh --check      # diff against static/_headers; exit 1 on drift
#   scripts/csp-hashes.sh --check --no-build   # reuse an existing public/ (e.g. in CI)
set -euo pipefail
cd "$(dirname "$0")/.."

CHECK=false
NO_BUILD=false
for arg in "$@"; do
  case "$arg" in
    --check)    CHECK=true ;;
    --no-build) NO_BUILD=true ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

if $NO_BUILD; then
  # Reuse the public/ a prior build produced (CI build step does `hugo --minify`).
  [[ -d public ]] || { echo "Error: --no-build set but public/ not found." >&2; exit 2; }
else
  # Build fresh — minifyOutput is on in hugo.yaml, so the bytes here match what
  # statichost serves (a stale public/ would hash to the wrong values).
  hugo --quiet
fi

CHECK="$CHECK" python3 - <<'PY'
import re, pathlib, hashlib, base64, os, sys

def b64(s): return "sha256-" + base64.b64encode(hashlib.sha256(s.encode()).digest()).decode()

style_re  = re.compile(r'<style[^>]*>(.*?)</style>', re.S)
script_re = re.compile(r'<script(?![^>]*\bsrc=)(?![^>]*application/ld\+json)[^>]*>(.*?)</script>', re.S)

styles, scripts = {}, {}
for p in pathlib.Path('public').rglob('*.html'):
    html = p.read_text(errors='replace')
    for m in style_re.finditer(html):
        b = m.group(1)
        if b.strip(): styles.setdefault(b64(b), b[:60])
    for m in script_re.finditer(html):
        b = m.group(1)
        if b.strip(): scripts.setdefault(b64(b), b[:60])

if os.environ.get("CHECK") != "true":
    for name, d in (("style-src", styles), ("script-src", scripts)):
        print(f"# {name} — {len(d)} unique inline block(s)")
        for h, prev in d.items(): print(f"#   {prev!r}")
        print("'" + "' '".join(d) + "'\n")
    sys.exit(0)

# --check: compare computed hashes against those declared in static/_headers
hdr = pathlib.Path('static/_headers').read_text()
def declared(directive):
    s = set()
    for m in re.finditer(directive + r' ([^;]+);', hdr):
        s |= set(re.findall(r"sha256-[A-Za-z0-9+/=]+", m.group(1)))
    return s

problems = False
for name, comp, decl in (("style-src", styles, declared("style-src")),
                         ("script-src", scripts, declared("script-src"))):
    missing = set(comp) - decl   # in build, not in _headers -> would be BLOCKED
    extra   = decl - set(comp)   # in _headers, not in build -> stale, removable
    if missing:
        problems = True
        print(f"DRIFT {name}: {len(missing)} hash(es) in build but NOT in _headers (would be blocked):")
        for h in missing: print(f"   {h}  <- {comp[h]}")
    if extra:
        print(f"WARN  {name}: {len(extra)} hash(es) in _headers no longer used (safe to remove):")
        for h in extra: print(f"   {h}")
    if not missing and not extra:
        print(f"OK    {name}: {len(comp)} hash(es) match _headers")
sys.exit(1 if problems else 0)
PY
