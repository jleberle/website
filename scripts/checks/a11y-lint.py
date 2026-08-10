#!/usr/bin/env python3
"""Content-accessibility lint over the built site (public/).

Catches per-content issues that automated scanners (Lighthouse/axe) and
html-validate don't reliably cover:

  * images with a missing or empty alt attribute (the decorative site logo,
    apple-touch-icon, is intentionally exempt)
  * heading-level skips within a page (e.g. h1 -> h3)

Exits non-zero if any issues are found, so it can gate CI after `hugo`.

Usage: python3 scripts/checks/a11y-lint.py [public ...]
"""
import sys
import glob
import re

IMG_RE = re.compile(r"<img\b[^>]*>", re.I)
ALT_RE = re.compile(r"""\balt\s*=\s*("[^"]*"|'[^']*'|\S+)""", re.I)
SRC_RE = re.compile(r"""\bsrc\s*=\s*("([^"]*)"|'([^']*)'|(\S+))""", re.I)
HEAD_RE = re.compile(r"<h([1-6])\b", re.I)

# The logo is a decorative icon sitting beside the "Home" text label, so an
# empty alt is correct there (avoids double announcement).
DECORATIVE_HINTS = ("apple-touch-icon",)


def check(html):
    errors = []

    for m in IMG_RE.finditer(html):
        tag = m.group(0)
        srcm = SRC_RE.search(tag)
        src = ""
        if srcm:
            src = srcm.group(2) or srcm.group(3) or srcm.group(4) or ""
        if any(h in src for h in DECORATIVE_HINTS):
            continue
        altm = ALT_RE.search(tag)
        alt = altm.group(1).strip("\"'").strip() if altm else None
        if not alt:
            errors.append(f"<img> missing/empty alt: {src or tag[:70]}")

    prev = 0
    for m in HEAD_RE.finditer(html):
        level = int(m.group(1))
        if prev and level > prev + 1:
            errors.append(f"heading skip: h{prev} -> h{level}")
        prev = level

    return errors


def main(argv):
    roots = argv[1:] or ["public"]
    files = []
    for root in roots:
        if root.endswith(".html"):
            files.append(root)
        else:
            files += glob.glob(f"{root}/**/*.html", recursive=True)

    total = 0
    for path in sorted(set(files)):
        try:
            html = open(path, encoding="utf-8").read()
        except OSError as e:
            print(f"{path}: read error: {e}")
            total += 1
            continue
        for err in check(html):
            print(f"{path}: {err}")
            total += 1

    if total:
        print(f"\na11y-lint: {total} issue(s) found")
        print(
            "\nThese are the pages a screen-reader user cannot navigate.\n"
            "  missing alt  — describe what the image SHOWS, in the Markdown:\n"
            "                 ![A crowd outside the courthouse](photo.avif)\n"
            "                 If the image is purely decorative, alt=\"\" is correct.\n"
            "  heading skip — do not jump from ## straight to ####. Headings are\n"
            "                 how screen readers build a table of contents, so a\n"
            "                 skipped level reads as a missing section."
        )
        return 1
    print(f"a11y-lint: clean ({len(files)} pages)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
