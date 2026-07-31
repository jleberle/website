#!/usr/bin/env python3
"""Keep published writing attached to the knowledge graph.

Two rules, both cheap to satisfy at the moment a post is written and expensive
to satisfy years later when you no longer remember what the piece was drawing on:

  1. No orphans. Every post in a publishable section carries at least one
     `sources:` entry or one subject `tags:` entry. A post with neither is
     reachable only by scrolling to its date in the archive — it exists on the
     site but not in the graph.

  2. `about:` is a subset of `sources:`. A key in `about:` that is not also in
     `sources:` does nothing at all: `about` only reorders and labels the
     taxonomy links that `sources` creates. The failure is silent, so it has to
     be caught here.

Sections are read from `contentSections` in hugo.yaml rather than hardcoded, so
adding a section does not quietly opt it out of both rules.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

BLOCK_ITEM = re.compile(r"^(\s*)-\s+(.*\S)\s*$")


def front_matter(path: Path) -> str:
    text = path.read_text(encoding="utf-8", errors="replace")
    match = re.match(r"^---\n(.*?)\n---", text, re.S)
    return match.group(1) if match else ""


def values(fm: str, key: str) -> list[str]:
    """Read an inline (`[a, b]`) or block (`- a`) list for `key`."""
    match = re.search(rf"^{key}:[ \t]*(.*)$", fm, re.M)
    if not match:
        return []
    inline = match.group(1).strip()
    if inline.startswith("["):
        return [v.strip().strip("\"'") for v in inline.strip("[]").split(",") if v.strip()]
    found = []
    for line in fm[match.end():].split("\n")[1:]:
        item = BLOCK_ITEM.match(line)
        if not item:
            break
        found.append(item.group(2).strip("\"'"))
    return found


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

    orphans: list[Path] = []
    dangling: list[tuple[Path, str]] = []
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

    if failed:
        return 1

    print(f"Connection lint clean ({checked} posts scanned)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
