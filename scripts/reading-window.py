#!/usr/bin/env python3
"""Show which reading events Micro.blog can currently re-import.

WHY THIS EXISTS
---------------
Micro.blog re-creates any feed item it cannot find a post for. Deleting an
imported post on eberle.blog does NOT tell the importer to forget it — on the
next poll the item is still in the feed, there is no matching post, so it is
imported again. A deletion only sticks once the item has aged out of the feed
window (services.rss.limit in hugo.yaml).

That check was the one missing from the 2026-08 duplicate cleanup: 15 posts
were deleted on the assumption it would hold, and holding was luck — they
happened to be outside the window. This answers the question directly, before
deleting anything.

It reads the LIVE feed by default, not public/, because what Micro.blog can see
is what matters — a local build may be ahead of what has been deployed.

Usage:
    python3 scripts/reading-window.py                  # live feed
    python3 scripts/reading-window.py public           # a local build
    python3 scripts/reading-window.py --url https://…  # some other feed
"""

from __future__ import annotations

import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from email.utils import parsedate_to_datetime
from pathlib import Path

LIVE_FEED = "https://jaredeberle.org/reading/index.xml"
READING_FEED_REL = "reading/index.xml"
TIMEOUT = 20


def load_feed(source: str) -> tuple[bytes, str]:
    """Return (xml bytes, human label). `source` is a URL or a public/ dir."""
    if source.startswith(("http://", "https://")):
        request = urllib.request.Request(
            source, headers={"User-Agent": "jaredeberle.org reading-window"}
        )
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            return response.read(), source

    path = Path(source)
    if path.is_dir():
        path = path / READING_FEED_REL
    return path.read_bytes(), str(path)


def main() -> int:
    args = sys.argv[1:]
    if "--url" in args:
        source = args[args.index("--url") + 1]
    elif args and not args[0].startswith("-"):
        source = args[0]
    else:
        source = LIVE_FEED

    try:
        raw, label = load_feed(source)
    except (urllib.error.URLError, OSError) as exc:
        print(f"reading-window: could not read {source}: {exc}", file=sys.stderr)
        return 2

    try:
        channel = ET.fromstring(raw).find("channel")
    except ET.ParseError as exc:
        print(f"reading-window: {label} is not valid XML: {exc}", file=sys.stderr)
        return 2
    if channel is None:
        print(f"reading-window: no <channel> in {label}", file=sys.stderr)
        return 2

    rows = []
    for item in channel.findall("item"):
        link = (item.findtext("link") or "").strip()
        desc = (item.findtext("description") or "").strip()
        raw_date = (item.findtext("pubDate") or "").strip()
        try:
            when = parsedate_to_datetime(raw_date).strftime("%Y-%m-%d")
        except (TypeError, ValueError):
            when = "????-??-??"
        # The description opens "Started reading: <title> by <author>. 📚 …";
        # everything from the emoji on is the note, which is noise here.
        headline = desc.split("📚")[0].strip().rstrip(".")
        rows.append((when, headline, link))

    if not rows:
        print(f"No reading events in {label}.")
        return 0

    print(f"{len(rows)} event(s) currently in the feed window — {label}\n")
    for when, headline, link in rows:
        print(f"  {when}  {headline}")
        print(f"              {link}")

    oldest = min(row[0] for row in rows)
    newest = max(row[0] for row in rows)
    print()
    print(f"Window spans {oldest} → {newest}.")
    print()
    print("Deleting the eberle.blog post for ANY event above will NOT stick — Micro.blog")
    print("re-imports every feed item it cannot find a post for. Wait for it to age out,")
    print("or accept that it will come back. Anything not listed is safe to delete.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
