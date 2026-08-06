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
    python3 scripts/micropub-probe.py --post       # three draft variants
    python3 scripts/micropub-probe.py --delete URL # remove a stray probe post
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


def created_url(headers: dict, body: bytes) -> str | None:
    """The URL of a just-created post.

    The Micropub spec says a server returns 201 with a Location header.
    Micro.blog returns 202 with NO Location and the URL in a JSON body
    ({"url": ..., "preview": ..., "edit": ...}) — verified against the live
    endpoint on 2026-08-06. Reading only the header made this probe report
    "nothing was created" while a draft had in fact been created and left
    behind, so both are checked.
    """
    if headers.get("Location"):
        return headers["Location"]
    try:
        payload = json.loads(body.decode("utf-8", "replace"))
    except ValueError:
        return None
    url = payload.get("url") if isinstance(payload, dict) else None
    return url if isinstance(url, str) and url.startswith("http") else None


def delete_post(token: str, url: str) -> bool:
    form = urllib.parse.urlencode({"action": "delete", "url": url}).encode()
    status, _, body = request(MICROPUB, token, form,
                              "application/x-www-form-urlencoded")
    show(f"DELETE {url}", status, body)
    if status not in (200, 202, 204):
        print(f"\n!! DELETE FAILED — remove {url} by hand at micro.blog/account/posts.")
        return False
    return True


def bookshelf_snapshot(token: str) -> str:
    """Books currently on every shelf, as a comparable blob."""
    status, _, body = request("https://micro.blog/books/bookshelves", token)
    if status != 200:
        return f"(bookshelves unavailable — HTTP {status})"
    return body.decode("utf-8", "replace")


def probe_post(token: str, variant: str = "supplied") -> None:
    """Create one draft with read-of, inspect it, then delete it.

    `variant` selects which open question this run answers:

      "supplied"  content we wrote + read-of. The first live run (2026-08-06)
                  returned our text verbatim with a 📚 appended and category
                  ["Books"] — recognised as a book post, but NO Markdown link
                  and no shelf change.
      "empty"     read-of with NO content. help.micro.blog says Micro.blog
                  "will format the blog post with a Markdown link to the book",
                  which the supplied-content run did not do — the likeliest
                  reading is that it only GENERATES that text when there is
                  nothing to overwrite. This is the test of that.
      "isbn"      uid as a bare ISBN rather than a micro.blog URL. The docs
                  never say which form uid takes.
    """
    # Captured first so a new book record is visible as a DIFFERENCE rather
    # than guessed at from the after-state alone. Whether read-of shelves the
    # book is the question that decides the whole migration.
    before = bookshelf_snapshot(token)

    properties = {
        # q=config lists post-status among the note type's properties, so the
        # probe never publishes. NOTE: association may not fire until publish;
        # a negative result here is not proof it fails for a published post.
        "post-status": ["draft"],
        "read-of": [{
            "type": ["h-cite"],
            "properties": {
                "name": [PROBE_NAME],
                "uid": [PROBE_ISBN if variant == "isbn"
                        else f"https://micro.blog/books/{PROBE_ISBN}"],
            },
        }],
        "read-status": ["finished"],
    }
    if variant != "empty":
        properties["content"] = [
            f"Micropub probe ({variant}) — verifying read-of handling. "
            "Draft; deleted automatically."
        ]

    payload = json.dumps({"type": ["h-entry"], "properties": properties}).encode("utf-8")

    status, headers, body = request(MICROPUB, token, payload, "application/json")
    show(f"POST h-entry with read-of [{variant}]", status, body)

    location = created_url(headers, body)
    if not location:
        print("\nNo post URL in the Location header OR the response body. If the "
              "status above was 2xx a post may still exist — check "
              "micro.blog/account/posts before re-running.")
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

    delete_post(token, location)


def main() -> int:
    token = os.environ.get("MICROBLOG_TOKEN", "").strip()
    if not token:
        print("Set MICROBLOG_TOKEN first (micro.blog/account/apps → new token).",
              file=sys.stderr)
        return 2

    args = sys.argv[1:]

    # Clean up a probe post left behind by an earlier run, without creating a
    # new one. Needed because the first live run reported "nothing was created"
    # when a draft had been — see created_url().
    if "--delete" in args:
        try:
            url = args[args.index("--delete") + 1]
        except IndexError:
            print("--delete needs the post URL to remove.", file=sys.stderr)
            return 2
        return 0 if delete_post(token, url) else 1

    probe_config(token)

    if "--post" in args:
        # Each variant is one draft, created and deleted in turn. Running them
        # together matters: the answers only mean something side by side.
        for variant in ("supplied", "empty", "isbn"):
            print(f"\n{'=' * 70}\n=== variant: {variant}\n{'=' * 70}")
            probe_post(token, variant)
    else:
        print("\nRead-only probe complete. Re-run with --post to create, inspect "
              "and delete one real post — the only way to see what Micro.blog "
              "does with read-of.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
