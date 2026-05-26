#!/usr/bin/env bash
# Recomputes SHA-256 hashes of every unique inline <style> block in the built
# site, formatted for the Content-Security-Policy style-src directive in
# _headers. Run after Hugo/PaperMod upgrades or theme changes that touch
# inline styles; copy the output into _headers and rebuild.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d public ]; then
  hugo --quiet
fi
python3 - <<'PY'
import re, pathlib, hashlib, base64
seen = {}
for p in pathlib.Path('public').rglob('*.html'):
    html = p.read_text(errors='replace')
    for m in re.finditer(r'<style[^>]*>(.*?)</style>', html, re.DOTALL):
        body = m.group(1)
        h = base64.b64encode(hashlib.sha256(body.encode()).digest()).decode()
        seen.setdefault(h, body[:60])
print(f"# {len(seen)} unique inline <style> block(s)")
for h, preview in seen.items():
    print(f"#   {preview!r}")
print("'" + "' '".join(f"sha256-{h}" for h in seen) + "'")
PY
