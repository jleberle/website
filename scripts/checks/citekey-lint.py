#!/usr/bin/env python3
"""Cross-reference site cite keys against Zotero and the Obsidian reading vault.

Every ``cite_key`` / ``cite_keys`` value used in ``content/`` and every
``cite_key`` in ``data/reading/`` is expected to exist in the Zotero library —
that is the actual "is this ledger in sync with Zotero" contract. Missing from
Zotero means the key is a typo, a renamed citekey, or a source that was never
actually added to Zotero.

A secondary, informational report lists keys that are in Zotero but have no
vault reading note yet (``<vault>/02 Notes/01 Reading Notes/<citekey>.md``).
That's expected for casual reading (a novel doesn't need a research note) so it
is never treated as drift — only the Zotero mismatch can fail the gate.

Both the vault and the Zotero library live outside the repo and are absent in
CI, so each check skips cleanly (with a note) if its source isn't found. Pass
--strict to exit non-zero when cite keys are missing from Zotero.

Usage:
    citekey-lint.py [content_dir] [reading_dir] [--strict]

Config (env overrides):
    WEBSITE_BIBLIOGRAPHY       CSL-JSON library         (default ~/Documents/Library/Library.json)
    WEBSITE_VAULT_DIR          Obsidian vault           (default ~/Notes)
    WEBSITE_READING_NOTES_DIR  reading-notes subfolder  (default "02 Notes/01 Reading Notes")
"""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path


SINGLE = re.compile(r'^cite_key\s*:\s*(.+?)\s*$')
LIST_HEADER = re.compile(r'^cite_keys\s*:\s*(.*)$')
LIST_ITEM = re.compile(r'^\s*-\s*(.+?)\s*$')
INLINE_LIST = re.compile(r'\[(.*)\]')


def unquote(value: str) -> str:
    value = value.strip()
    if len(value) >= 2 and value[0] in "\"'" and value[-1] == value[0]:
        value = value[1:-1]
    return value.strip()


def front_matter(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    if not lines or lines[0].strip() != "---":
        return []
    block = []
    for line in lines[1:]:
        if line.strip() == "---":
            break
        block.append(line)
    return block


def keys_from_markdown(path: Path) -> set[str]:
    found: set[str] = set()
    block = front_matter(path)
    i = 0
    while i < len(block):
        line = block[i]
        m = SINGLE.match(line)
        if m:
            key = unquote(m.group(1))
            if key:
                found.add(key)
            i += 1
            continue
        m = LIST_HEADER.match(line)
        if m:
            rest = m.group(1).strip()
            inline = INLINE_LIST.match(rest)
            if inline:
                for part in inline.group(1).split(","):
                    key = unquote(part)
                    if key:
                        found.add(key)
                i += 1
                continue
            i += 1
            while i < len(block):
                item = LIST_ITEM.match(block[i])
                if not item:
                    break
                key = unquote(item.group(1))
                if key:
                    found.add(key)
                i += 1
            continue
        i += 1
    return found


def keys_from_yaml(path: Path) -> set[str]:
    found: set[str] = set()
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = SINGLE.match(line)
        if m:
            key = unquote(m.group(1))
            if key:
                found.add(key)
    return found


def zotero_keys(bib_path: Path) -> set[str] | None:
    if not bib_path.is_file():
        return None
    try:
        data = json.loads(bib_path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None
    if not isinstance(data, list):
        return None
    return {str(item.get("citation-key") or item.get("id")) for item in data if isinstance(item, dict)}


def main(argv: list[str]) -> int:
    strict = "--strict" in argv
    args = [a for a in argv if not a.startswith("--")]
    content_dir = Path(args[0]) if len(args) > 0 else Path("content")
    reading_dir = Path(args[1]) if len(args) > 1 else Path("data/reading")

    used: dict[str, list[str]] = {}
    for path in content_dir.rglob("*.md"):
        for key in keys_from_markdown(path):
            used.setdefault(key, []).append(str(path))
    for path in reading_dir.rglob("*.yaml"):
        for key in keys_from_yaml(path):
            used.setdefault(key, []).append(str(path))

    if not used:
        print("no cite keys in use")
        return 0

    exit_code = 0

    bib_path = Path(os.environ.get("WEBSITE_BIBLIOGRAPHY", str(Path.home() / "Documents/Library/Library.json")))
    in_zotero = zotero_keys(bib_path)
    if in_zotero is None:
        print(f"Zotero library not found or unreadable ({bib_path}); skipping cite-key check")
    else:
        missing = sorted(k for k in used if k not in in_zotero)
        found = sorted(k for k in used if k in in_zotero)
        if missing:
            print(f"{len(found)}/{len(used)} cite key(s) found in the Zotero library; "
                  f"{len(missing)} missing (typo, renamed key, or never added to Zotero):")
            for key in missing:
                where = sorted({Path(p).name for p in used[key]})
                print(f"  - {key}  ({', '.join(where)})")
            if strict:
                exit_code = 1
        else:
            print(f"all {len(found)} cite key(s) in use are in the Zotero library")

    vault = Path(os.environ.get("WEBSITE_VAULT_DIR", str(Path.home() / "Notes")))
    notes_sub = os.environ.get("WEBSITE_READING_NOTES_DIR", "02 Notes/01 Reading Notes")
    notes_dir = vault / notes_sub
    if not notes_dir.is_dir():
        print(f"reading-note vault not found ({notes_dir}); skipping vault cross-reference")
    else:
        available = {p.stem for p in notes_dir.glob("*.md")}
        no_note = sorted(k for k in used if k not in available)
        if no_note:
            print(f"informational: {len(no_note)} cite key(s) have no vault reading note "
                  f"(expected for casual reading, never fails):")
            for key in no_note:
                print(f"  - {key}")
        else:
            print("all cite keys in use resolve to a vault reading note")

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
