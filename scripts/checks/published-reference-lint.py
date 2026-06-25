#!/usr/bin/env python3
"""Validate that generated internal references resolve to published output.

This guards the `build.publishResources = false` setup in hugo.yaml. If a
template builds a page-bundle URL as a string instead of invoking the resource,
the output may link to a file Hugo never published.
"""

from __future__ import annotations

import argparse
import html
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse


ATTR_RE = re.compile(r'(?:src|href|poster|content|data-lightbox-src)=(?:"([^"]+)"|([^ >"\']+))')
SRCSET_RE = re.compile(r'srcset=(?:"([^"]+)"|\'([^\']+)\')')
ABSOLUTE_SITE_RE = re.compile(r'https://jaredeberle\.org(/[^"\\\s<>)]+)')
SCAN_SUFFIXES = {".html", ".xml", ".json"}


def published_files(public_dir: Path) -> set[str]:
    return {
        str(path.relative_to(public_dir))
        for path in public_dir.rglob("*")
        if path.is_file()
    }


def candidate_paths(path: str) -> list[str]:
    return [path, f"{path}index.html", f"{path.rstrip('/')}/index.html"]


def should_check(url: str) -> str | None:
    parsed = urlparse(url)
    if parsed.scheme and parsed.netloc not in {"", "jaredeberle.org"}:
        return None
    path = unquote(parsed.path)
    if not path.startswith("/"):
        return None
    return path.lstrip("/")


def missing_references(public_dir: Path) -> list[tuple[str, str]]:
    files = published_files(public_dir)
    missing: set[tuple[str, str]] = set()

    for path in public_dir.rglob("*"):
        if not path.is_file() or path.suffix not in SCAN_SUFFIXES:
            continue

        rel = str(path.relative_to(public_dir))
        text = html.unescape(path.read_text(encoding="utf-8", errors="ignore"))

        for match in ATTR_RE.findall(text):
            url = match[0] or match[1]
            resolved = should_check(url)
            if resolved and not any(candidate in files for candidate in candidate_paths(resolved)):
                missing.add((rel, url))

        for match in SRCSET_RE.findall(text):
            raw = match[0] or match[1]
            for item in raw.split(","):
                url = item.strip().split(" ", 1)[0]
                resolved = should_check(url)
                if resolved and not any(candidate in files for candidate in candidate_paths(resolved)):
                    missing.add((rel, url))

        for match in ABSOLUTE_SITE_RE.findall(text):
            resolved = should_check(match)
            if resolved and not any(candidate in files for candidate in candidate_paths(resolved)):
                missing.add((rel, match))

    return sorted(missing)


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate generated internal references.")
    parser.add_argument("public", nargs="?", default="public", help="Built site directory (default: public)")
    args = parser.parse_args()

    public_dir = Path(args.public).resolve()
    if not public_dir.exists():
        print(f"Path not found: {public_dir}", file=sys.stderr)
        return 1

    missing = missing_references(public_dir)
    if missing:
        for source, url in missing:
            print(f"  {source}  ->  {url}")
        return 1

    print("every internal reference resolves to a published file")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
