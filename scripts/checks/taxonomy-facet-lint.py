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

from _frontmatter import front_matter, values

PERIOD = re.compile(r"^(?:\d{3,4}s|\d{1,2}(?:st|nd|rd|th)\s+century)$", re.IGNORECASE)


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "content")
    misfiled: list[tuple[Path, str]] = []
    unshaped: list[tuple[Path, str]] = []

    for path in sorted(root.rglob("*.md")):
        lines = front_matter(path)
        if not lines:
            continue
        for value in values(lines, "tags"):
            if PERIOD.match(value):
                misfiled.append((path, value))
        for value in values(lines, "eras"):
            if not PERIOD.match(value):
                unshaped.append((path, value))

    failed = False

    if misfiled:
        failed = True
        print("Period values found in `tags` — these belong in `eras`:")
        for path, value in misfiled:
            print(f"  {path}: {value!r}")
        print("Move them to an `eras:` list. See docs/workflow.md 'Tags and eras'.")

    # The converse check. Guarding only one direction keeps subjects out of the
    # period taxonomy by convention alone, and a subject filed under `eras`
    # fails the same way a period under `tags` does: it publishes a hub at
    # /eras/<subject>/ that answers the wrong question, and it is the kind of
    # thing that gets noticed a hundred posts later. The vocabulary is closed by
    # construction — a decade or a named century — so this is checkable where a
    # subject vocabulary would not be.
    if unshaped:
        failed = True
        if misfiled:
            print()
        print("`eras` values that are not a period — a decade (1970s) or century (19th Century):")
        for path, value in unshaped:
            print(f"  {path}: {value!r}")
        print("A subject belongs in `tags`. See docs/workflow.md 'Tags and eras'.")

    if failed:
        return 1

    tagged = sum(1 for p in root.rglob("*.md") if values(front_matter(p), "tags"))
    periodised = sum(1 for p in root.rglob("*.md") if values(front_matter(p), "eras"))
    print(f"Taxonomy facet lint clean ({tagged} tagged, {periodised} dated files scanned)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
