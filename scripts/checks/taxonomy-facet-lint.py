#!/usr/bin/env python3
"""Keep the `tags` and `eras` taxonomies from collapsing back into one list.

`tags` names what a piece is about; `eras` names the period it concerns. The
two were a single flat vocabulary until they were split, and the split only
stays split if nothing quietly re-adds "1970s" as a tag. The cost of catching
that here is one regex; the cost of catching it after a hundred more posts is
a hundred front-matter edits plus every /tags/<period>/ URL that got indexed
in the meantime.

Period-shaped means a decade (1970s) or a named century (19th Century). A tag
that merely contains a year ("Tulsa in 1918") is a subject and is left alone.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

PERIOD = re.compile(r"^(?:\d{3,4}s|\d{1,2}(?:st|nd|rd|th)\s+century)$", re.IGNORECASE)
BLOCK_ITEM = re.compile(r"^(\s*)-\s+(.*\S)\s*$")


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


def values(lines: list[str], key: str) -> list[str]:
    """Read a block or inline list for `key` out of front matter."""
    for i, line in enumerate(lines):
        match = re.match(rf"^{key}:\s*(.*)$", line)
        if not match:
            continue
        inline = match.group(1).strip()
        if inline.startswith("["):
            return [v.strip().strip("\"'") for v in inline.strip("[]").split(",") if v.strip()]
        found = []
        for item in lines[i + 1:]:
            block = BLOCK_ITEM.match(item)
            if not block:
                break
            found.append(block.group(2).strip("\"'"))
        return found
    return []


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "content")
    misfiled: list[tuple[Path, str]] = []

    for path in sorted(root.rglob("*.md")):
        lines = front_matter(path)
        if not lines:
            continue
        for value in values(lines, "tags"):
            if PERIOD.match(value):
                misfiled.append((path, value))

    if misfiled:
        print("Period values found in `tags` — these belong in `eras`:")
        for path, value in misfiled:
            print(f"  {path}: {value!r}")
        print("Move them to an `eras:` list. See docs/workflow.md 'Tags and eras'.")
        return 1

    tagged = sum(1 for p in root.rglob("*.md") if values(front_matter(p), "tags"))
    print(f"Taxonomy facet lint clean ({tagged} tagged files scanned)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
