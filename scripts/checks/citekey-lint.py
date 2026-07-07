#!/usr/bin/env python3
"""Cross-reference site cite keys against the Obsidian reading-note vault.

Every ``cite_key`` / ``cite_keys`` value used in ``content/`` and every
``cite_key`` in ``data/reading/`` is expected to have a matching reading note in
the vault (``<vault>/02 Notes/01 Reading Notes/<citekey>.md``). That keeps the
site's cross-linking apparatus honest against the research library it points at.

The vault lives outside the repo and is absent in CI, so this check is advisory:
if the vault is not found it skips cleanly, and by default it reports unmatched
keys without failing. Pass --strict to exit non-zero when keys are unmatched.

Usage:
    citekey-lint.py [content_dir] [reading_dir] [--strict]

Vault location comes from WEBSITE_VAULT_DIR (default ~/Notes); the reading-notes
subfolder from WEBSITE_READING_NOTES_DIR (default "02 Notes/01 Reading Notes").
"""

from __future__ import annotations

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


def main(argv: list[str]) -> int:
    strict = "--strict" in argv
    args = [a for a in argv if not a.startswith("--")]
    content_dir = Path(args[0]) if len(args) > 0 else Path("content")
    reading_dir = Path(args[1]) if len(args) > 1 else Path("data/reading")

    vault = Path(os.environ.get("WEBSITE_VAULT_DIR", str(Path.home() / "Notes")))
    notes_sub = os.environ.get("WEBSITE_READING_NOTES_DIR", "02 Notes/01 Reading Notes")
    notes_dir = vault / notes_sub

    if not notes_dir.is_dir():
        print(f"reading-note vault not found ({notes_dir}); skipping cross-reference")
        return 0

    available = {p.stem for p in notes_dir.glob("*.md")}

    used: dict[str, list[str]] = {}
    for path in content_dir.rglob("*.md"):
        for key in keys_from_markdown(path):
            used.setdefault(key, []).append(str(path))
    for path in reading_dir.rglob("*.yaml"):
        for key in keys_from_yaml(path):
            used.setdefault(key, []).append(str(path))

    unmatched = sorted(k for k in used if k not in available)
    matched = sorted(k for k in used if k in available)

    if not used:
        print("no cite keys in use")
        return 0

    if not unmatched:
        print(f"all {len(matched)} cite key(s) in use resolve to a reading note")
        return 0

    print(f"{len(matched)}/{len(used)} cite key(s) resolve to a reading note; "
          f"{len(unmatched)} without a vault note:")
    for key in unmatched:
        where = sorted({Path(p).name for p in used[key]})
        print(f"  - {key}  ({', '.join(where)})")

    return 1 if strict else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
