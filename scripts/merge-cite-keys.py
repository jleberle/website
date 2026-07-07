#!/usr/bin/env python3
"""Merge discovered citation keys into a post's ``cite_keys`` front matter.

Given a Markdown file and a list of citation keys (as produced by
``cite-refs.sh --keys``), add any not already present as the primary ``cite_key``
or in an existing ``cite_keys`` list. Prints the space-separated keys it added
(nothing if there was no change), so publish-draft can report them.

Usage: merge-cite-keys.py FILE key1 key2 ...
"""

from __future__ import annotations

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


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        return 0
    path = Path(argv[0])
    discovered: list[str] = []
    for key in argv[1:]:
        if key and key not in discovered:
            discovered.append(key)

    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        return 0
    fm_end = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            fm_end = i
            break
    if fm_end is None:
        return 0

    primary: str | None = None
    existing: list[str] = []
    span: tuple[int, int] | None = None   # [start, end) of the cite_keys block
    primary_idx: int | None = None

    i = 1
    while i < fm_end:
        line = lines[i]
        m = SINGLE.match(line)
        if m:
            primary = unquote(m.group(1))
            primary_idx = i
            i += 1
            continue
        m = LIST_HEADER.match(line)
        if m:
            start = i
            rest = m.group(1).strip()
            inline = INLINE_LIST.match(rest)
            if inline:
                for part in inline.group(1).split(","):
                    key = unquote(part)
                    if key:
                        existing.append(key)
                span = (start, i + 1)
                i += 1
                continue
            i += 1
            while i < fm_end:
                item = LIST_ITEM.match(lines[i])
                if not item:
                    break
                key = unquote(item.group(1))
                if key:
                    existing.append(key)
                i += 1
            span = (start, i)
            continue
        i += 1

    known = set(existing)
    if primary:
        known.add(primary)
    added = [k for k in discovered if k not in known]
    if not added:
        return 0

    final = existing + added
    block = ["cite_keys:"] + [f'  - "{k}"' for k in final]

    if span is not None:
        lines[span[0]:span[1]] = block
    elif primary_idx is not None:
        lines[primary_idx + 1:primary_idx + 1] = block
    else:
        lines[1:1] = block

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(" ".join(added))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
