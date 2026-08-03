#!/usr/bin/env python3
"""Pull received webmentions from webmention.io and write them as Hugo data.

Runs on a schedule (see .github/workflows/webmentions.yml), independent of
when posts are published, so mentions stay fresh without needing a
client-side widget or CSP changes. Output groups mentions by the exact
target path they were sent to (webmention.io records the URL the sender
discovered your rel="webmention" link on, which matches the page's own
permalink), so a template can look them up with
`index hugo.Data.webmentions .RelPermalink`.
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

API_URL = "https://webmention.io/api/mentions.jf2"
USER_AGENT = "jaredeberle.org webmention fetcher"
PER_PAGE = 1000
MAX_PAGES = 20
CONTENT_LIMIT = 500


def fetch_page(token: str, page: int) -> list[dict]:
    query = urllib.parse.urlencode({"token": token, "per-page": PER_PAGE, "page": page})
    request = urllib.request.Request(
        f"{API_URL}?{query}",
        headers={"User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status < 200 or response.status >= 300:
            raise RuntimeError(f"webmention.io returned HTTP {response.status}")
        body = json.loads(response.read())
    return body.get("children", [])


def fetch_all(token: str) -> list[dict]:
    mentions: list[dict] = []
    for page in range(MAX_PAGES):
        batch = fetch_page(token, page)
        if not batch:
            break
        mentions.extend(batch)
        if len(batch) < PER_PAGE:
            break
    else:
        raise RuntimeError(f"stopped after {MAX_PAGES} pages; webmention.io may have more")
    return mentions


def target_path(target_url: str) -> str | None:
    parsed = urllib.parse.urlparse(target_url)
    return parsed.path or None


def summarize(entry: dict) -> dict:
    author = entry.get("author") or {}
    content = (entry.get("content") or {}).get("text", "")
    summary = {
        "type": entry.get("wm-property", "mention-of"),
        "url": entry.get("url", ""),
        "published": entry.get("published") or entry.get("wm-received", ""),
        "author": {
            "name": author.get("name", ""),
            "url": author.get("url", ""),
            "photo": author.get("photo", ""),
        },
    }
    if content:
        summary["content"] = content[:CONTENT_LIMIT]
    return summary


def group(mentions: list[dict]) -> dict[str, list[dict]]:
    grouped: dict[str, list[dict]] = {}
    for entry in mentions:
        path = target_path(entry.get("wm-target", ""))
        if not path:
            continue
        grouped.setdefault(path, []).append(summarize(entry))
    for entries in grouped.values():
        entries.sort(key=lambda e: (e["published"], e["url"]), reverse=True)
    return dict(sorted(grouped.items()))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--token", required=True)
    parser.add_argument("--out", type=Path, default=Path("data/webmentions.json"))
    args = parser.parse_args()

    try:
        mentions = fetch_all(args.token)
    except (OSError, urllib.error.URLError, RuntimeError, json.JSONDecodeError) as exc:
        print(f"Fetching webmentions failed: {exc}", file=sys.stderr)
        return 1

    grouped = group(mentions)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(grouped, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {sum(len(v) for v in grouped.values())} mentions across {len(grouped)} pages to {args.out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
