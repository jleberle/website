"""Shared YAML front-matter reading for the content lints in this directory.

Deliberately not a real YAML parser: every lint here only needs a scalar or a
flat list read off a known top-level key, and the content in this repo never
nests deeper than that. Pulling in PyYAML for that would be a dependency this
directory otherwise has none of.
"""

from __future__ import annotations

import re
from pathlib import Path

BLOCK_ITEM = re.compile(r"^(\s*)-\s+(.*\S)\s*$")


def front_matter(path: Path) -> list[str]:
    """Return the lines between the opening and closing `---` of a page's front matter."""
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
    """Read a single scalar value for `key` out of front matter lines."""
    for line in lines:
        match = re.match(rf"^{key}:\s*(.*)$", line)
        if match:
            return match.group(1).strip().strip("\"'")
    return ""


def values(lines: list[str], key: str) -> list[str]:
    """Read a block or inline list for `key` out of front matter lines."""
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
