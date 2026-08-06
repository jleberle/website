#!/usr/bin/env python3
"""Check that every book source's ISBN resolves to a real cover on Micro.blog.

WHY THIS EXISTS
---------------
The reading feed emits `https://micro.blog/books/<isbn>` for each book event,
and Micro.blog associates the imported post with a book record by that link.
The ISBN in `content/sources/<slug>/_index.md` is therefore not just local
metadata — it is the identifier the other half of the "one entry, two places"
setup keys on. An ISBN that Micro.blog cannot resolve yields a book record with
a placeholder cover on eberle.blog's /reading/ page and in its reading goals,
and nothing on this site reveals that.

`https://cdn.micro.blog/books/<isbn>/cover.jpg` answers the question without
authentication, so the ISBN can be validated from here rather than by going to
Micro.blog to look one up — which would defeat the point of entering a work
once, in this repo.

WHAT IT IS NOT
--------------
This checks COVER AVAILABILITY, not ISBN correctness. The upstream catalogue
will happily return some cover for a well-formed but wrong number (a synthetic
`1234567890123` returns a real image), so a pass means "this will look right",
not "this is the edition you read". Nothing automated can check the latter.

NETWORK
-------
This makes one HTTP request per uncached ISBN, so it is deliberately NOT part
of scripts/preflight.sh, which stays offline. Results are cached in
book-covers.json next to this file, keyed by ISBN, so repeat runs only probe
ISBNs that are new or previously failing. Pass --recheck to ignore the cache.

Usage:
    python3 scripts/checks/book-cover-lint.py [content] [--recheck]
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path


COVER_URL = "https://cdn.micro.blog/books/{isbn}/cover.jpg"
CACHE_PATH = Path(__file__).resolve().parent / "book-covers.json"
TIMEOUT = 20

# Three responses distinguish the outcomes, established empirically against the
# live endpoint (2026-08-05):
#   ~81 bytes                  the ISBN is unknown; a stub, not an image
#   6287 bytes, md5 below      known ISBN, but the catalogue has no cover art
#   anything else              a real cover
# Size alone is not enough to tell the middle case from a small real cover, so
# the placeholder is matched by digest.
PLACEHOLDER_MD5 = "15677f7d458bc161a2b3a8597e290f39"
STUB_MAX_BYTES = 1000

ISBN_LINE = re.compile(r"^isbn\s*:\s*[\"']?([0-9Xx]+)[\"']?\s*$", re.MULTILINE)

OK = "ok"
NO_COVER = "no-cover"
UNKNOWN = "unknown-isbn"
UNREACHABLE = "unreachable"


def read_isbn(path: Path) -> str | None:
    text = path.read_text(encoding="utf-8", errors="replace")
    match = ISBN_LINE.search(text)
    return match.group(1) if match else None


def probe(isbn: str) -> str:
    """Classify one ISBN. Never raises — a network failure is its own state."""
    request = urllib.request.Request(
        COVER_URL.format(isbn=isbn),
        headers={"User-Agent": "jaredeberle.org book-cover-lint"},
    )
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
            body = response.read()
    except urllib.error.HTTPError as exc:
        return UNKNOWN if exc.code == 404 else UNREACHABLE
    except (urllib.error.URLError, OSError):
        return UNREACHABLE

    if len(body) < STUB_MAX_BYTES:
        return UNKNOWN
    if hashlib.md5(body).hexdigest() == PLACEHOLDER_MD5:
        return NO_COVER
    return OK


def load_cache() -> dict[str, str]:
    try:
        data = json.loads(CACHE_PATH.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return {k: v for k, v in data.items() if isinstance(v, str)} if isinstance(data, dict) else {}


def save_cache(cache: dict[str, str]) -> None:
    CACHE_PATH.write_text(
        json.dumps(dict(sorted(cache.items())), indent=2) + "\n", encoding="utf-8"
    )


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    recheck = "--recheck" in sys.argv[1:]
    root = Path(args[0] if args else "content") / "sources"

    if not root.is_dir():
        print(f"No sources directory at {root}")
        return 1

    cache = {} if recheck else load_cache()
    # Only successes are cached. A failure is a state the ledger is expected to
    # move out of, and re-probing it every run is what makes the fix visible.
    cache = {isbn: state for isbn, state in cache.items() if state == OK}

    problems: list[tuple[str, str, str]] = []
    checked = 0

    for index_path in sorted(root.glob("*/_index.md")):
        isbn = read_isbn(index_path)
        if not isbn:
            continue
        checked += 1
        state = cache.get(isbn)
        if state is None:
            state = probe(isbn)
            if state == OK:
                cache[isbn] = state
        if state != OK:
            problems.append((index_path.parent.name, isbn, state))

    save_cache(cache)

    if problems:
        print("Book ISBNs that will not render a cover on Micro.blog:")
        for slug, isbn, state in problems:
            print(f"  {slug:<20} {isbn}  {state}")
        print()
        print("  unknown-isbn  Micro.blog cannot resolve this ISBN at all.")
        print("  no-cover      Resolves, but the catalogue holds no cover art.")
        print("  unreachable   Network or endpoint failure — not a ledger problem.")
        print()
        print("Fix by putting a different edition's ISBN in the source page; check a")
        print("candidate with:")
        print("  curl -sIL https://cdn.micro.blog/books/<isbn>/cover.jpg")
        return 1 if any(state != UNREACHABLE for _, _, state in problems) else 0

    print(f"Book cover lint clean ({checked} ISBNs verified against Micro.blog)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
