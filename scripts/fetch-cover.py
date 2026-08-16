#!/usr/bin/env python3
"""Fetch a book cover from Apple's Books catalogue for a review post.

Replaces the manual step of running `ipic -b "search term"`, picking a
thumbnail out of the HTML page it opens in Safari, and saving/converting the
image by hand. Same API iPic uses (iTunes Search, entity=ebook) but scripted:
looks up which of the post's sources it's centrally about, reads that
source's title/author from content/sources/<slug>/_index.md, searches, and
downloads the largest artwork Apple has for the picked match — requesting an
oversized `bb` URL (10000x10000) returns the true source resolution rather
than iPic's hardcoded 600x600 cap. The result is handed straight to
add-images.sh, which already produces cover.avif + a jpeg OG fallback and
prints the front-matter snippet.

Which source a cover comes from, without --source or a search term: a review
with exactly one `sources:` entry is taken to be about it, matching the
`about:` convention newpost.sh already documents; anything else (an article
citing a source in passing, multiple sources with no `about:` singling one
out) exits with an explanation instead of guessing.

Usage:
    scripts/fetch-cover.py <post-dir>                    # resolve via about:/sources:
    scripts/fetch-cover.py <post-dir> "search term"       # search directly
    scripts/fetch-cover.py <post-dir> --source zengerle2026  # pick among multiple sources
    scripts/fetch-cover.py <post-dir> -y                  # skip the picker, take the top hit
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

SEARCH_URL = "https://itunes.apple.com/search"
USER_AGENT = "jaredeberle.org fetch-cover"
RESULT_LIMIT = 8
BLOCK_ITEM = re.compile(r"^(\s*)-\s+(.*\S)\s*$")


def front_matter(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    if not lines or lines[0].strip() != "---":
        return []
    out = []
    for line in lines[1:]:
        if line.strip() == "---":
            return out
        out.append(line)
    return []


def scalar(lines: list[str], key: str) -> str:
    for line in lines:
        match = re.match(rf"^{key}:\s*(.*)$", line)
        if match:
            return match.group(1).strip().strip("\"'")
    return ""


def values(lines: list[str], key: str) -> list[str]:
    for i, line in enumerate(lines):
        match = re.match(rf"^{key}:\s*(.*)$", line)
        if not match:
            continue
        inline = match.group(1).strip()
        if inline.startswith("["):
            return [v.strip().strip("\"'") for v in inline.strip("[]").split(",") if v.strip()]
        found = []
        for item in lines[i + 1:]:
            block = BLOCK_ITEM.match(item)
            if not block:
                break
            found.append(block.group(2).strip("\"'"))
        return found
    return []


def resolve_about_source(lines: list[str], post_dir: Path) -> str:
    """Pick the one source key a cover should come from, or exit explaining why not.

    Automatic resolution is for reviews only: a book cover is illustrative of
    the specific book being reviewed, not a generic "this piece cites this
    source" marker, so it has no meaning for an article even when the article
    names one source in `about:`. An article that wants a cover fetched still
    can — pass a search term or --source explicitly, a deliberate action
    rather than something that happens on every publish.
    """
    if post_dir.resolve().parent.name != "reviews":
        sys.exit(
            "Automatic cover lookup is for reviews only (the cover illustrates the specific "
            "book being reviewed) — pass a search term or --source to fetch one anyway."
        )

    about = values(lines, "about")
    if len(about) == 1:
        return about[0]
    if len(about) > 1:
        sys.exit("about: names more than one source — pass --source to pick which cover to fetch.")

    sources = values(lines, "sources")
    if not sources:
        sys.exit(
            f"{post_dir / 'index.md'} has no sources: entry — pass a search term or --source explicitly."
        )
    if len(sources) == 1:
        return sources[0]
    sys.exit(
        "Multiple sources: with no about: singling one out — pass --source <slug> "
        "(or add about:) to pick which cover to fetch."
    )


def search_term_from_source(repo_root: Path, slug: str) -> str:
    source_path = repo_root / "content" / "sources" / slug / "_index.md"
    if not source_path.is_file():
        sys.exit(f"No source page at content/sources/{slug}/_index.md")
    lines = front_matter(source_path)
    title = scalar(lines, "title")
    author = scalar(lines, "author")
    if not title:
        sys.exit(f"content/sources/{slug}/_index.md has no title to search with")
    print(f"Using source [{slug}]: {title} — {author or '(no author)'}", file=sys.stderr)
    return f"{title} {author}".strip()


def itunes_search(term: str) -> list[dict]:
    query = urllib.parse.urlencode(
        {"term": term, "media": "ebook", "entity": "ebook", "limit": RESULT_LIMIT}
    )
    request = urllib.request.Request(
        f"{SEARCH_URL}?{query}", headers={"User-Agent": USER_AGENT}
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        body = json.load(response)
    return body.get("results", [])


def pick_result(results: list[dict], auto_yes: bool) -> dict:
    if not auto_yes and len(results) > 1:
        print(file=sys.stderr)
        for i, r in enumerate(results, start=1):
            year = (r.get("releaseDate") or "")[:4]
            print(
                f"  {i}. {r.get('trackName')} — {r.get('artistName')} ({year})",
                file=sys.stderr,
            )
        print(file=sys.stderr)
        choice = input(f"Pick a cover [1-{len(results)}, default 1]: ").strip()
        if not choice:
            index = 0
        elif choice.isdigit() and 1 <= int(choice) <= len(results):
            index = int(choice) - 1
        else:
            sys.exit("Invalid choice.")
    else:
        index = 0
        r = results[0]
        year = (r.get("releaseDate") or "")[:4]
        print(f"Match: {r.get('trackName')} — {r.get('artistName')} ({year})", file=sys.stderr)
    return results[index]


def largest_artwork_url(result: dict) -> str:
    thumb = result.get("artworkUrl100") or result.get("artworkUrl60")
    if not thumb:
        sys.exit("Selected result has no artwork URL.")
    # Apple clamps to the true source resolution rather than erroring on an
    # oversized request, so asking for 10000x10000 always returns the best
    # available image instead of iPic's hardcoded 600x600.
    return re.sub(r"\d+x\d+bb\.\w+$", "10000x10000bb.jpg", thumb)


def download(url: str, dest: Path) -> None:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response, dest.open("wb") as f:
        f.write(response.read())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("post_dir", help="Post bundle directory (e.g. content/reviews/<slug>)")
    parser.add_argument(
        "search_term", nargs="?", default="", help="Search term (skips the sources: lookup)"
    )
    parser.add_argument(
        "--source", metavar="SLUG", help="Use this content/sources/<slug> instead of the first sources: entry"
    )
    parser.add_argument(
        "-y", "--yes", action="store_true", help="Take the top search result without prompting"
    )
    args = parser.parse_args()

    repo_root = Path(
        subprocess.run(
            ["git", "rev-parse", "--show-toplevel"], capture_output=True, text=True, check=True
        ).stdout.strip()
    )
    post_dir = Path(args.post_dir)
    index_md = post_dir / "index.md"
    if not index_md.is_file():
        sys.exit(f"Not a post bundle (no index.md): {post_dir}")
    if (post_dir / "cover.avif").exists():
        sys.exit(f"cover.avif already exists in {post_dir}")

    if args.search_term:
        term = args.search_term
    else:
        slug = args.source or resolve_about_source(front_matter(index_md), post_dir)
        term = search_term_from_source(repo_root, slug)

    try:
        results = itunes_search(term)
    except (urllib.error.URLError, TimeoutError) as exc:
        sys.exit(f"iTunes search failed: {exc}")

    if not results:
        sys.exit(f"No Apple Books results for '{term}'. Try a manual search term or ipic.")

    picked = pick_result(results, args.yes)
    artwork_url = largest_artwork_url(picked)

    with tempfile.TemporaryDirectory() as tmp:
        cover_path = Path(tmp) / "cover.jpg"
        try:
            download(artwork_url, cover_path)
        except (urllib.error.URLError, TimeoutError) as exc:
            sys.exit(f"Cover download failed: {exc}")

        add_images = repo_root / "scripts" / "add-images.sh"
        subprocess.run(
            [str(add_images), str(post_dir), "--cover", str(cover_path)], check=True
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
