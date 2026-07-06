#!/usr/bin/env python3
"""Report oversized built HTML pages for this site.

The site is mostly text and modestly templated, so raw HTML beyond ~100 KiB is
usually a sign that a page is accreting too much inline structure, too many
entries, or a repeated fragment that should be simplified.

Thresholds are intentionally conservative and based on the current build:
  * most pages soft-warn at 96 KiB, fail at 128 KiB
  * the reading ledger is intentionally denser, so it gets a higher ceiling
"""

from __future__ import annotations

import sys
from pathlib import Path

KIB = 1024
DEFAULT_SOFT = 96 * KIB
DEFAULT_HARD = 128 * KIB
OVERRIDES: dict[str, tuple[int, int]] = {
    "reading/index.html": (128 * KIB, 160 * KIB),
}


def fmt_bytes(size: int) -> str:
    if size >= KIB:
        return f"{size / KIB:.1f} KiB"
    return f"{size} B"


def thresholds_for(rel: str) -> tuple[int, int]:
    return OVERRIDES.get(rel, (DEFAULT_SOFT, DEFAULT_HARD))


def main() -> int:
    public_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "public")
    if not public_dir.is_dir():
        print(f"page-size-lint: generated public directory not found: {public_dir}", file=sys.stderr)
        return 2

    pages = sorted(public_dir.rglob("*.html"))
    if not pages:
        print("page-size-lint: no HTML pages found")
        return 2

    warnings: list[str] = []
    failures: list[str] = []

    largest = max(pages, key=lambda path: path.stat().st_size)
    top = sorted(pages, key=lambda path: path.stat().st_size, reverse=True)[:5]

    for path in pages:
        rel = path.relative_to(public_dir).as_posix()
        size = path.stat().st_size
        soft, hard = thresholds_for(rel)
        if size > hard:
            failures.append(
                f"{rel}: {fmt_bytes(size)} exceeds hard limit {fmt_bytes(hard)}"
            )
        elif size > soft:
            warnings.append(
                f"{rel}: {fmt_bytes(size)} exceeds soft limit {fmt_bytes(soft)}"
            )

    if failures:
        print("Oversized HTML pages:")
        for line in failures:
            print(f"  - {line}")
        print("\nLargest built pages:")
        for path in top:
            rel = path.relative_to(public_dir).as_posix()
            print(f"  - {rel}: {fmt_bytes(path.stat().st_size)}")
        return 1

    largest_rel = largest.relative_to(public_dir).as_posix()
    summary = (
        f"Page size lint clean ({len(pages)} pages; largest {largest_rel} at "
        f"{fmt_bytes(largest.stat().st_size)})"
    )
    if warnings:
        print(summary)
        print("Soft-limit warnings:")
        for line in warnings:
            print(f"  - {line}")
    else:
        print(summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
