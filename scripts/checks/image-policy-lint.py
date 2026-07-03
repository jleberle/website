#!/usr/bin/env python3
"""Reject unoptimized raster source images from Hugo input directories."""

from __future__ import annotations

import sys
from pathlib import Path


SOURCE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}
SITE_JPEG = Path("assets/images/card.jpg")


def allowed(path: Path, relative: Path) -> bool:
    suffix = path.suffix.lower()

    # Browser, PWA, and operating-system icons must remain PNG.
    if suffix == ".png" and relative.parts[:2] in {
        ("static", "icons"),
        ("assets", "icons"),
    }:
        return True

    # The default OpenGraph card and page-bundle JPEG companions are kept for
    # crawlers that do not support AVIF.
    if relative == SITE_JPEG:
        return True
    if suffix in {".jpg", ".jpeg"} and path.with_suffix(".avif").is_file():
        return True

    return False


def main() -> int:
    repo = Path.cwd().resolve()
    roots = [Path(arg) for arg in sys.argv[1:]] or [Path("assets"), Path("content"), Path("static")]
    images: list[tuple[Path, Path]] = []

    for root in roots:
        if not root.exists():
            continue
        for path in root.rglob("*"):
            if path.is_file() and path.suffix.lower() in SOURCE_SUFFIXES:
                images.append((path, path.resolve().relative_to(repo)))

    violations = [(path, relative) for path, relative in sorted(images) if not allowed(path, relative)]
    if violations:
        print("Unoptimized source images found:")
        for _, relative in violations:
            print(f"  {relative}")
        print("Convert them with scripts/to-avif.sh --replace or scripts/add-images.sh.")
        return 1

    print(f"Image policy lint clean ({len(images)} JPEG/PNG/WebP source files checked)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
