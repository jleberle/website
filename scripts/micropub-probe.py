#!/usr/bin/env python3
"""Probe Micro.blog's Micropub API to decide whether it beats the RSS import.

WHY
---
Every duplicate-post incident on eberle.blog traces to one property of the RSS
path: we do not control the write. Micro.blog decides what is new by matching a
<link>, which is why a published link is immutable, why deleting a post does not
stick while its item is in the window, and why book association has to be
smuggled through an ISBN link in the post body.

Micropub would invert all of that — but the one thing that matters most is
undocumented. help.micro.blog/t/books-books-books/1424 says only:

    "Micro.blog's version of the Micropub API understands read-of properties.
     If the property has name and uid, Micro.blog will format the blog post
     with a Markdown link to the book."

It does not say what `uid` should contain, whether the post gets associated with
a book RECORD (the thing reading goals are built from), or whether the book
lands on a bookshelf. The books JSON API page documents REST endpoints only and
says nothing about read-of. So this is settled by experiment or not at all.

WHAT IT DOES
------------
Read-only by default. It reports the Micropub config and the token's scopes,
which is enough to confirm the channel works at all.

With --post it creates ONE post as a DRAFT, inspects what Micro.blog made of
it, and deletes it again. The q=config probe confirmed `post-status` is a
supported property of the note type, so the experiment never publishes
anything. Check the output before assuming the delete succeeded.

USAGE
-----
    export MICROBLOG_TOKEN=...        # micro.blog/account/apps → new token
    python3 scripts/micropub-probe.py              # read-only
    python3 scripts/micropub-probe.py --post       # the live experiment
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

MICROPUB = "https://micro.blog/micropub"
TIMEOUT = 30

# A real book with a known-good ISBN, so a failure is about read-of rather than
# about the catalogue not recognising the number.
PROBE_ISBN = "9781639732159"
PROBE_NAME = "The Blood Countess"


def request(url: str, token: str, data: bytes | None = None,
            content_type: str | None = None, method: str | None = None):
    headers = {"Authorization": f"Bearer {token}"}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as response:
            return response.status, dict(response.headers), response.read()
    except urllib.error.HTTPError as exc:
        return exc.code, dict(exc.headers), exc.read()


def show(label: str, status: int, body: bytes) -> None:
    print(f"\n--- {label} — HTTP {status}")
    text = body.decode("utf-8", "replace").strip()
    try:
        print(json.dumps(json.loads(text), indent=2)[:2000])
    except ValueError:
        print(text[:2000] or "(empty body)")


def probe_config(token: str) -> None:
    for query in ("config", "source"):
        status, _, body = request(f"{MICROPUB}?q={query}", token)
        show(f"q={query}", status, body)


def bookshelf_snapshot(token: str) -> str:
    """Books currently on every shelf, as a comparable blob."""
    status, _, body = request("https://micro.blog/books/bookshelves", token)
    if status != 200:
        return f"(bookshelves unavailable — HTTP {status})"
    return body.decode("utf-8", "replace")


def probe_post(token: str) -> None:
    """Create one draft with read-of, inspect it, then delete it."""
    # Captured first so a new book record is visible as a DIFFERENCE rather
    # than guessed at from the after-state alone. Whether read-of shelves the
    # book is the question that decides the whole migration.
    before = bookshelf_snapshot(token)

    payload = json.dumps({
        "type": ["h-entry"],
        "properties": {
            "content": ["Micropub probe — verifying read-of handling. "
                        "Draft; deleted automatically."],
            # q=config lists post-status among the note type's properties, so
            # the probe never publishes.
            "post-status": ["draft"],
            "read-of": [{
                "type": ["h-cite"],
                "properties": {
                    "name": [PROBE_NAME],
                    # The open question. If Micro.blog wants a bare ISBN this
                    # will read wrong in the output and we will see it.
                    "uid": [f"https://micro.blog/books/{PROBE_ISBN}"],
                },
            }],
            "read-status": ["finished"],
        },
    }).encode("utf-8")

    status, headers, body = request(MICROPUB, token, payload, "application/json")
    show("POST h-entry with read-of", status, body)

    location = headers.get("Location")
    if not location:
        print("\nNo Location header — nothing was created, so nothing to clean up.")
        return
    print(f"\nCreated: {location}")

    # Give the platform a moment to render and associate before reading back.
    time.sleep(5)

    # A draft has no public URL, so a 404 here is expected and not a failure.
    try:
        with urllib.request.urlopen(location, timeout=TIMEOUT) as response:
            html = response.read().decode("utf-8", "replace")
        print(f"\n--- rendered post ({len(html)} bytes)")
        print(f"links to /books/{PROBE_ISBN}: {f'/books/{PROBE_ISBN}' in html}")
    except (urllib.error.URLError, OSError) as exc:
        print(f"\nCreated post not publicly fetchable ({exc}) — expected for a draft.")

    # What the post itself became: does the ISBN survive as an association?
    status, _, body = request(f"{MICROPUB}?q=source&url={urllib.parse.quote(location)}", token)
    show("q=source for the probe post", status, body)

    # THE decisive comparison: did read-of create a book record / shelf entry?
    after = bookshelf_snapshot(token)
    print("\n--- bookshelves")
    print("changed by this post: "
          f"{'YES — read-of shelves the book' if after != before else 'no — read-of does not shelve'}")
    if after != before:
        show("bookshelves after", 200, after.encode())

    delete = urllib.parse.urlencode({"action": "delete", "url": location}).encode()
    status, _, body = request(MICROPUB, token, delete,
                              "application/x-www-form-urlencoded")
    show("DELETE the probe post", status, body)
    if status not in (200, 202, 204):
        print(f"\n!! DELETE FAILED — remove {location} by hand.")


def main() -> int:
    token = os.environ.get("MICROBLOG_TOKEN", "").strip()
    if not token:
        print("Set MICROBLOG_TOKEN first (micro.blog/account/apps → new token).",
              file=sys.stderr)
        return 2

    probe_config(token)

    if "--post" in sys.argv[1:]:
        probe_post(token)
    else:
        print("\nRead-only probe complete. Re-run with --post to create, inspect "
              "and delete one real post — the only way to see what Micro.blog "
              "does with read-of.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
