#!/usr/bin/env python3
"""Keep published writing attached to the knowledge graph.

Three rules, all cheap to satisfy at the moment a post is written and expensive
to satisfy years later when you no longer remember what the piece was drawing on:

  1. No orphans. Every post in a publishable section carries at least one
     `sources:` entry or one subject `tags:` entry. A post with neither is
     reachable only by scrolling to its date in the archive — it exists on the
     site but not in the graph.

  2. `about:` is a subset of `sources:`. A key in `about:` that is not also in
     `sources:` does nothing at all: `about` only reorders and labels the
     taxonomy links that `sources` creates. The failure is silent, so it has to
     be caught here.

  3. Every `sources:` key resolves to a real page under content/sources/. This
     is the expensive one to miss. Hugo does not error on an unknown taxonomy
     term — it invents one, so a typo publishes a phantom source page at
     /sources/<typo>/ with no title, author or year, captioned "Book" because
     that is the template default. Since /sources/ became a real bibliography
     the phantom is listed there too, and the post's genuine connection to the
     work it meant to cite silently does not exist. Nothing else in the build
     notices: the page renders, the links resolve, the link checker sees 200.

  4. Every source's `type` is one the templates know. `newsource.sh` validates
     this on creation, but writing the file by hand is documented as equally
     valid, and the templates only ever compare against "book" — anything else
     is humanized straight into the page kicker. So `type: bok` renders a source
     captioned "Bok" and silently withholds the catalogue links.

Sections are read from `contentSections` in hugo.yaml rather than hardcoded, so
adding a section does not quietly opt it out of the rules.
"""

from __future__ import annotations

import difflib
import re
import sys
from pathlib import Path

from _frontmatter import BLOCK_ITEM, front_matter, scalar, values

# Kept in step with the accepted list in scripts/newsource.sh and the table in
# docs/reading.md. Adding a kind is deliberate in all three places.
SOURCE_TYPES = {"book", "article", "archive", "thesis", "dissertation"}


def content_sections(repo: Path) -> list[str]:
    config = (repo / "hugo.yaml").read_text(encoding="utf-8", errors="replace")
    match = re.search(r"^\s*contentSections:\s*$", config, re.M)
    if not match:
        return ["articles", "reviews", "quotes"]
    sections = []
    for line in config[match.end():].split("\n")[1:]:
        item = BLOCK_ITEM.match(line)
        if not item:
            break
        sections.append(item.group(2).strip("\"'"))
    return sections


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "content")
    repo = root.parent if root.name == "content" else Path(".")

    known = {p.parent.name for p in (root / "sources").glob("*/_index.md")}

    badtypes: list[tuple[Path, str]] = []
    for path in sorted((root / "sources").glob("*/_index.md")):
        value = scalar(front_matter(path), "type")
        if value and value not in SOURCE_TYPES:
            badtypes.append((path, value))

    orphans: list[Path] = []
    dangling: list[tuple[Path, str]] = []
    phantoms: list[tuple[Path, str]] = []
    checked = 0

    for section in content_sections(repo):
        for path in sorted((root / section).rglob("*.md")):
            if path.name == "_index.md":
                continue
            checked += 1
            fm = front_matter(path)
            sources = values(fm, "sources")
            if not sources and not values(fm, "tags"):
                orphans.append(path)
            for key in values(fm, "about"):
                if key not in sources:
                    dangling.append((path, key))
            for key in sources:
                if key not in known:
                    phantoms.append((path, key))

    failed = False

    if orphans:
        failed = True
        print("Posts with neither a source nor a subject tag (unreachable except by date):")
        for path in orphans:
            print(f"  {path}")
        print("Add a `sources:` entry or a subject `tags:` entry.")

    if dangling:
        failed = True
        if orphans:
            print()
        print("`about:` keys missing from the same page's `sources:` (these do nothing):")
        for path, key in dangling:
            print(f"  {path}: {key!r}")
        print("Every `about:` key must also appear in `sources:`.")

    if phantoms:
        failed = True
        if orphans or dangling:
            print()
        print("`sources:` keys with no page under content/sources/ (Hugo will publish an empty one):")
        for path, key in phantoms:
            near = difflib.get_close_matches(key, known, n=3, cutoff=0.6)
            hint = f"  did you mean {', '.join(repr(n) for n in near)}?" if near else ""
            print(f"  {path}: {key!r}{hint}")
        print("Create content/sources/<key>/_index.md, or fix the key on the post.")

    if badtypes:
        failed = True
        if orphans or dangling or phantoms:
            print()
        print("Source `type` values the templates do not know:")
        for path, value in badtypes:
            print(f"  {path}: {value!r}")
        print(f"Use one of: {', '.join(sorted(SOURCE_TYPES))}.")

    if failed:
        return 1

    print(f"Connection lint clean ({checked} posts scanned, {len(known)} sources)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
