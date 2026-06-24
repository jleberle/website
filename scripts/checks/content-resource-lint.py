#!/usr/bin/env python3
"""Validate source-content resource references before publishing.

This intentionally checks the Markdown source, not the generated site. The
preflight reference scan catches broken output URLs after Hugo runs; this catches
authoring mistakes earlier, especially a cover block left in front matter before
cover.avif has been added to the page bundle.
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path


FRONT_MATTER_RE = re.compile(r"\A---\n(?P<body>.*?)(?:\n---\n|\n---\Z)", re.DOTALL)
COVER_BLOCK_RE = re.compile(r"^cover:\s*$\n(?P<body>(?:^[ \t]+.*(?:\n|$))+)", re.MULTILINE)
COVER_IMAGE_RE = re.compile(r"^[ \t]+image:\s*[\"']?(?P<image>[^\"'\n#]+)", re.MULTILINE)


def is_external(value: str) -> bool:
    return bool(re.match(r"^[a-z][a-z0-9+.-]*://", value, re.IGNORECASE))


def existing_cover_paths(content_file: Path, image: str, repo_root: Path) -> list[Path]:
    image = image.strip()
    if is_external(image) or image.startswith("//"):
        return []

    if image.startswith("/"):
        rel = image.lstrip("/")
        return [repo_root / "static" / rel, repo_root / "assets" / rel, repo_root / "content" / rel]

    return [content_file.parent / image]


def validate_file(path: Path, repo_root: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="ignore")
    front_matter = FRONT_MATTER_RE.match(text)
    if not front_matter:
        return []

    errors: list[str] = []
    cover_block = COVER_BLOCK_RE.search(front_matter.group("body"))
    if not cover_block:
        return errors

    image_match = COVER_IMAGE_RE.search(cover_block.group("body"))
    if not image_match:
        errors.append(f"{path.relative_to(repo_root)}: cover block is missing cover.image")
        return errors

    image = image_match.group("image").strip()
    candidates = existing_cover_paths(path, image, repo_root)
    if candidates and not any(candidate.exists() for candidate in candidates):
        checked = ", ".join(str(candidate.relative_to(repo_root)) for candidate in candidates)
        errors.append(
            f"{path.relative_to(repo_root)}: cover.image '{image}' does not exist "
            f"(checked {checked})"
        )

    return errors


def markdown_files(root: Path) -> list[Path]:
    ignored_parts = {".git", "node_modules", "public", "resources", "themes"}
    return sorted(
        path
        for path in root.rglob("*.md")
        if not any(part in ignored_parts for part in path.relative_to(root).parts)
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate Hugo content resource references.")
    parser.add_argument("root", nargs="?", default="content", help="Path to scan, default: content")
    args = parser.parse_args()

    repo_root = Path.cwd()
    scan_root = (repo_root / args.root).resolve()
    if not scan_root.exists():
        print(f"Path not found: {scan_root}", file=sys.stderr)
        return 1

    files = [scan_root] if scan_root.is_file() else markdown_files(scan_root)
    errors: list[str] = []
    for path in files:
        errors.extend(validate_file(path.resolve(), repo_root))

    if errors:
        print("Content resource lint failed:")
        for error in errors:
            print(f"  {error}")
        return 1

    print(f"Content resource lint clean ({len(files)} Markdown files scanned)")
    return 0


if __name__ == "__main__":
    os.chdir(Path(__file__).resolve().parents[2])
    raise SystemExit(main())
