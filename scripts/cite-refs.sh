#!/usr/bin/env bash
# Citation helpers for scholarly drafts.
#
#   cite-refs.sh --keys FILE           Print the citation keys used in FILE, one per line.
#   cite-refs.sh --bibliography FILE   Render a Chicago "Works Cited" list (Markdown) for
#                                      the keys used in FILE, using the Zotero-exported
#                                      CSL-JSON bibliography and CSL style.
#
# Recognized citation syntax in a draft body (front matter is ignored):
#   * Pandoc-style bracketed citations:  [@mckenziejones2015], [see @allen2012 p. 4]
#   * An explicit declaration comment:   <!-- cite: @allen2012 @cobb2015 -->
# Bare, unbracketed @keys in prose are intentionally NOT harvested, since Hugo renders
# them as literal text; use the bracket or comment form to declare a citation.
#
# Configuration (env overrides, defaults match the local Obsidian/Zotero setup):
#   WEBSITE_BIBLIOGRAPHY  CSL-JSON library   (default ~/Documents/Library/Library.json)
#   WEBSITE_CSL           CSL style file     (default Chicago notes-bibliography 18th)
#   PANDOC                pandoc binary      (default: pandoc on PATH)

set -euo pipefail

usage() {
  echo "Usage: $(basename "$0") --keys|--bibliography FILE" >&2
  exit 1
}

[[ $# -eq 2 ]] || usage
MODE="$1"
FILE="$2"
[[ -f "$FILE" ]] || { echo "File not found: $FILE" >&2; exit 1; }

BIB="${WEBSITE_BIBLIOGRAPHY:-$HOME/Documents/Library/Library.json}"
CSL="${WEBSITE_CSL:-$HOME/git/dotfiles/writing/pandoc/chicago-notes-bibliography-18th-edition.csl}"
PANDOC="${PANDOC:-pandoc}"

case "$MODE" in
  --keys)
    python3 - "$FILE" <<'PY'
import re, sys, pathlib
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
body = re.sub(r"^---\n.*?\n---\n", "", text, count=1, flags=re.S)
key = r"@([A-Za-z0-9_][\w:.#$%&+?<>~/-]*)"
found = []
seen = set()
def add(k):
    k = k.rstrip(".,;:")
    if k and k not in seen:
        seen.add(k); found.append(k)
# Bracketed pandoc citations: any [...] segment containing an @key.
for seg in re.findall(r"\[[^\]]*\]", body):
    if "@" in seg:
        for k in re.findall(key, seg):
            add(k)
# Explicit declaration comments: <!-- cite: @a @b --> or <!-- cite: a, b -->
for seg in re.findall(r"<!--\s*cite:\s*(.*?)-->", body, flags=re.S | re.I):
    for k in re.findall(r"@?([A-Za-z0-9_][\w:.#$%&+?<>~/-]*)", seg):
        add(k)
for k in found:
    print(k)
PY
    ;;
  --bibliography)
    command -v "$PANDOC" >/dev/null 2>&1 || { echo "pandoc not found (set PANDOC)" >&2; exit 3; }
    [[ -f "$BIB" ]] || { echo "Bibliography not found: $BIB (set WEBSITE_BIBLIOGRAPHY)" >&2; exit 3; }
    KEYS="$("$0" --keys "$FILE")"
    [[ -n "$KEYS" ]] || exit 0
    NOCITE="$(printf '@%s, ' $KEYS)"
    NOCITE="${NOCITE%, }"
    CSL_ARG=()
    [[ -f "$CSL" ]] && CSL_ARG=(--csl "$CSL")
    # markdown_strict emits the bibliography as plain paragraphs (no pandoc fenced
    # divs / csl-entry wrappers), which Hugo renders cleanly.
    printf -- '---\nnocite: |\n  %s\n---\n' "$NOCITE" | \
      "$PANDOC" --citeproc --bibliography "$BIB" "${CSL_ARG[@]}" \
        -f markdown -t markdown_strict 2>/dev/null
    ;;
  *)
    usage
    ;;
esac
