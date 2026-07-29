#!/usr/bin/env python3
"""Fail when a published raster image still carries EXIF/XMP/IPTC metadata.

scripts/to-avif.sh already strips this on every conversion it runs, but
image-policy-lint.py only checks file *pairing* (a .jpg needs a sibling
.avif) — it never inspects .avif files or metadata content. This is the
actual enforcement: it catches an image that reached content/, static/, or
assets/ without going through the helper, where EXIF can carry GPS
coordinates, device identifiers, or timestamps that were never meant to be
public.
"""

from __future__ import annotations

import shutil
import subprocess
import sys
from pathlib import Path

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".avif", ".webp"}


def has_metadata(path: Path) -> bool:
    for kind in ("EXIF", "IPTC", "XMP"):
        result = subprocess.run(
            ["identify", "-format", f"%[{kind}:*]", str(path)],
            capture_output=True,
            text=True,
            check=False,
        )
        if result.stdout.strip():
            return True
    return False


def main() -> int:
    # `identify` exists under every ImageMagick major version (v6 apt
    # packages ship it as the primary binary; v7 installs, including this
    # site's local Homebrew one, keep it alongside `magick`), unlike the
    # unified `magick` binary, which Ubuntu's `imagemagick` apt package does
    # not provide — verified against a real CI failure before switching.
    if not shutil.which("identify"):
        print("Error: ImageMagick (identify) not found; required to check image metadata.", file=sys.stderr)
        return 2

    roots = [Path(arg) for arg in sys.argv[1:]] or [Path("assets"), Path("content"), Path("static")]
    images: list[Path] = []
    for root in roots:
        if not root.exists():
            continue
        images.extend(path for path in root.rglob("*") if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES)

    violations = [path for path in sorted(images) if has_metadata(path)]
    if violations:
        print("Images with embedded EXIF/IPTC/XMP metadata found:")
        for path in violations:
            print(f"  {path}")
        print("Strip metadata with scripts/to-avif.sh (which runs -strip on every conversion).")
        return 1

    print(f"Image metadata lint clean ({len(images)} raster files checked)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
