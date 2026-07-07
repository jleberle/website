#!/usr/bin/env python3
"""Check generated image candidates against the site's real display slots.

This is not a generic image-quality score. It focuses on one practical risk:
whether the built image candidates are too small for the slot the site asks the
browser to fill, which is the main way an image ends up looking soft or blurry.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path

SIZE_REQUIREMENTS = {
    "(max-width: 768px) 100vw, 680px": 680,
    "(max-width: 560px) calc(100vw - 44px), 520px": 520,
    "(max-width: 640px) calc(100vw - 38px), 220px": 360,
    "(max-width: 768px) calc(100vw - 28px), (max-width: 1080px) calc(100vw - 56px), 1024px": 1024,
}

SRCSET_W_RE = re.compile(r"\s+(\d+)w$")
SRCSET_X_RE = re.compile(r"\s+(\d+(?:\.\d+)?)x$")


# A candidate at >= this fraction of its slot is close enough that any softening
# is imperceptible, so it isn't reported. Below FAIL_RATIO the image is small
# enough that upscaling is obvious; in between is an advisory warning.
WARN_RATIO = 0.85
FAIL_RATIO = 0.5


@dataclass
class ImgRecord:
    page: str
    src: str
    sizes: str
    srcset: str
    width: int | None
    alt: str
    classes: str


class ImgParser(HTMLParser):
    def __init__(self, page: str) -> None:
        super().__init__()
        self.page = page
        self.images: list[ImgRecord] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "img":
            return
        data = {key: (value or "") for key, value in attrs}
        width = None
        try:
            if data.get("width"):
                width = int(float(data["width"]))
        except ValueError:
            width = None
        self.images.append(
            ImgRecord(
                page=self.page,
                src=data.get("src", ""),
                sizes=" ".join(data.get("sizes", "").split()),
                srcset=data.get("srcset", ""),
                width=width,
                alt=data.get("alt", ""),
                classes=data.get("class", ""),
            )
        )


def parse_available_width(img: ImgRecord) -> int | None:
    srcset = img.srcset.strip()
    if not srcset:
        return None

    max_w = 0
    max_x = 0.0
    for part in srcset.split(","):
        item = part.strip()
        if not item:
            continue
        w_match = SRCSET_W_RE.search(item)
        if w_match:
            max_w = max(max_w, int(w_match.group(1)))
            continue
        x_match = SRCSET_X_RE.search(item)
        if x_match:
            max_x = max(max_x, float(x_match.group(1)))

    if max_w:
        return max_w
    if max_x and img.width:
        return int(round(max_x * img.width))
    return None


def parse_required_width(img: ImgRecord) -> int | None:
    if img.sizes in SIZE_REQUIREMENTS:
        required = SIZE_REQUIREMENTS[img.sizes]
    elif img.srcset and "x" in img.srcset and img.width:
        required = img.width * 2
    else:
        return None

    # The `sizes` hint describes the widest slot the image *could* occupy, but
    # only covers (.entry-cover img { width: 100% }) actually stretch to fill it.
    # In-content images are width:auto + max-width:100%, so they never paint
    # wider than their intrinsic width — the `sizes` value overstates their real
    # slot. Cap the requirement at the intrinsic width for those, so a source
    # displayed at (or below) its native size isn't reported as too small.
    is_cover = "u-featured" in img.classes.split()
    if not is_cover and img.width:
        required = min(required, img.width)
    return required


def main() -> int:
    public_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "public")
    if not public_dir.is_dir():
        print(f"image-display-lint: generated public directory not found: {public_dir}", file=sys.stderr)
        return 2

    warnings: dict[tuple[str, int, int], list[str]] = defaultdict(list)
    failures: dict[tuple[str, int, int], list[str]] = defaultdict(list)
    checked = 0

    for path in sorted(public_dir.rglob("*.html")):
        rel = path.relative_to(public_dir).as_posix()
        parser = ImgParser(rel)
        parser.feed(path.read_text(encoding="utf-8", errors="ignore"))
        for img in parser.images:
            if not img.src or img.src.startswith(("http://", "https://", "data:")):
                continue
            required = parse_required_width(img)
            available = parse_available_width(img)
            if required is None or available is None:
                continue
            checked += 1
            ratio = available / required if required else 1
            if ratio >= WARN_RATIO:
                continue

            line = (
                img.src,
                available,
                required,
            )
            if ratio < FAIL_RATIO:
                failures[line].append(img.page)
            else:
                warnings[line].append(img.page)

    if failures:
        print("Images likely to render softly on site:")
        for (src, available, required), pages in sorted(failures.items()):
            examples = ", ".join(sorted(pages)[:3])
            extra = f" (+{len(pages) - 3} more pages)" if len(pages) > 3 else ""
            print(
                f"  - {src} provides ~{available}px for a {required}px slot "
                f"(seen on {examples}{extra})"
            )
        if warnings:
            print("\nAdditional softer-slot warnings:")
            for (src, available, required), pages in sorted(warnings.items()):
                examples = ", ".join(sorted(pages)[:3])
                extra = f" (+{len(pages) - 3} more pages)" if len(pages) > 3 else ""
                print(
                    f"  - {src} provides ~{available}px for a {required}px slot "
                    f"(seen on {examples}{extra})"
                )
        return 1

    if warnings:
        print(f"Image display lint clean enough ({checked} responsive images checked)")
        print("Warnings:")
        for (src, available, required), pages in sorted(warnings.items()):
            examples = ", ".join(sorted(pages)[:3])
            extra = f" (+{len(pages) - 3} more pages)" if len(pages) > 3 else ""
            print(
                f"  - {src} provides ~{available}px for a {required}px slot "
                f"(seen on {examples}{extra})"
            )
    else:
        print(f"Image display lint clean ({checked} responsive images checked)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
