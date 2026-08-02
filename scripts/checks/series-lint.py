#!/usr/bin/env python3
"""Catch case/whitespace drift in the `series` taxonomy.

`tags` has a closed vocabulary (tag-vocabulary-lint.py) and `eras` is
shape-checked by regex (taxonomy-facet-lint.py) precisely because an open,
unchecked text field lets a typo publish a silent second page that nothing
links to and no one notices. `series` is the one taxonomy left with neither
guard: it is free text — `series: "A Series Name"` on every part of a
multi-part post (see docs/workflow.md) — feeding a real Hugo taxonomy the same
way tags do.

Unlike tags, series names cannot be a closed list: each one is invented once,
by whichever post starts it, and there is no vocabulary to check new values
against. What CAN be checked is internal consistency — every part of the same
series should spell its `series:` value identically, because
`layouts/_partials/series_nav.html` groups parts by exact taxonomy term. "My
Summer With Claude" and "My summer with Claude" are two different terms to
Hugo, so part 2 would silently stop appearing in part 1's "Part 1 of 2" nav
(and vice versa) — no build error, no warning, just a series that quietly
split in half. This lint fails when two or more distinct `series:` spellings
normalize (case-folded, whitespace-collapsed) to the same thing, which is
almost never intentional: nobody names two unrelated series identically up to
case and spacing.

A series with only one member is not flagged — that is simply the normal,
expected state of a series whose next part has not been written yet.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path


def front_matter(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    if not lines or lines[0].strip() != "---":
        return []
    out = []
    for line in lines[1:]:
        if line.strip() == "---":
            return out
        out.append(line)
    return []


def scalar(lines: list[str], key: str) -> str:
    for line in lines:
        match = re.match(rf"^{key}:\s*(.*)$", line)
        if match:
            return match.group(1).strip().strip("\"'")
    return ""


def normalize(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip().casefold()


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "content")
    by_norm: dict[str, dict[str, list[Path]]] = defaultdict(lambda: defaultdict(list))

    for path in sorted(root.rglob("*.md")):
        value = scalar(front_matter(path), "series")
        if not value:
            continue
        by_norm[normalize(value)][value].append(path)

    failed = False
    for norm, spellings in sorted(by_norm.items()):
        if len(spellings) <= 1:
            continue
        failed = True
        print(f"Series name spelled {len(spellings)} different ways:")
        for spelling, paths in sorted(spellings.items()):
            for path in paths:
                print(f"  {path}: {spelling!r}")
        print("  Make every part use the exact same `series:` value.")

    if failed:
        return 1

    total = sum(len(spellings) for spellings in by_norm.values())
    print(f"Series lint clean ({len(by_norm)} series, {total} spelling(s) used)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
