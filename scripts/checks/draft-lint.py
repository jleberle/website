#!/usr/bin/env python3
"""Fail when publishable content still has draft mode enabled."""

from __future__ import annotations

import re
import sys
from pathlib import Path


YAML_DRAFT = re.compile(r"^\s*draft\s*:\s*true\s*(?:#.*)?$", re.IGNORECASE)
TOML_DRAFT = re.compile(r"^\s*draft\s*=\s*true\s*(?:#.*)?$", re.IGNORECASE)


def is_draft(path: Path) -> bool:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    if not lines:
        return False

    delimiter = lines[0].strip()
    if delimiter not in {"---", "+++"}:
        return False

    pattern = YAML_DRAFT if delimiter == "---" else TOML_DRAFT
    for line in lines[1:]:
        if line.strip() == delimiter:
            break
        if pattern.match(line):
            return True
    return False


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else "content")
    drafts = [path for path in sorted(root.rglob("*.md")) if is_draft(path)]

    if drafts:
        print("Publishable content still marked as draft:")
        for path in drafts:
            print(f"  {path}")
        print("Move unfinished work to drafts/ or publish it with scripts/publish-draft.sh.")
        return 1

    count = sum(1 for _ in root.rglob("*.md"))
    print(f"Draft lint clean ({count} publishable Markdown files scanned)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
