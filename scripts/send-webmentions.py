#!/usr/bin/env python3
"""Send outbound webmentions for links found in the built site.

Runs after deploy (see .github/workflows/site-checks.yml, right after the
WebSub notify step waits for the live site to match this build) so a
receiver fetching the source URL to verify the link finds it there. Scans
only the post body (the element carrying a "post-content" class, matching
layouts/single.html) so nav/header/footer chrome never gets treated as a
citation.

A minimal complement to the inbound side (scripts/fetch-webmentions.py):
outbound webmention receivers are rare among the sites this blog cites
(archives, news, historical sources), so this deliberately does the least
that's useful rather than tracking retries or partial failures per target.
Each (source, target) pair is attempted once, ever, and recorded in the
state file regardless of outcome -- if a target adds webmention support
later, it won't get a mention from an old post until that post is edited
(which clears the pair from the state file, since it hashes off the source
URL and target URL, not the post content).
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

USER_AGENT = "jaredeberle.org webmention sender"
VOID_ELEMENTS = {
    "area", "base", "br", "col", "embed", "hr", "img", "input",
    "link", "meta", "param", "source", "track", "wbr",
}
LINK_REL_RE = re.compile(r'<(?:link|a)\b[^>]*\brel=["\']?[^"\'>]*\bwebmention\b[^>]*>', re.IGNORECASE)
HREF_RE = re.compile(r'\bhref=["\']([^"\']+)["\']', re.IGNORECASE)


class ContentLinkExtractor(HTMLParser):
    """Collects hrefs from <a> tags nested inside a .post-content element."""

    def __init__(self) -> None:
        super().__init__()
        self.stack: list[str] = []
        self.content_depth: int | None = None
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        attrs_d = dict(attrs)
        if tag not in VOID_ELEMENTS:
            self.stack.append(tag)
        if self.content_depth is None and tag == "div":
            classes = (attrs_d.get("class") or "").split()
            if "post-content" in classes:
                self.content_depth = len(self.stack)
        if self.content_depth is not None and tag == "a" and attrs_d.get("href"):
            self.links.append(attrs_d["href"])

    def handle_endtag(self, tag: str) -> None:
        if self.stack and self.stack[-1] == tag:
            self.stack.pop()
        if self.content_depth is not None and len(self.stack) < self.content_depth:
            self.content_depth = None


def extract_links(html: str) -> list[str]:
    parser = ContentLinkExtractor()
    parser.feed(html)
    return parser.links


def external_targets(links: list[str], own_domain: str) -> list[str]:
    targets = []
    for href in links:
        parsed = urllib.parse.urlparse(href)
        if parsed.scheme not in ("http", "https"):
            continue
        if parsed.netloc == own_domain:
            continue
        targets.append(urllib.parse.urlunparse(parsed._replace(fragment="")))
    return targets


def fetch(url: str) -> tuple[str, list[str]]:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=20) as response:
        links = response.getheader("Link", "")
        body = response.read(1_000_000).decode("utf-8", errors="replace")
        return body, response.headers.get_all("Link") or ([links] if links else [])


def discover_endpoint(target: str) -> str | None:
    try:
        body, link_headers = fetch(target)
    except (OSError, urllib.error.URLError, UnicodeDecodeError):
        return None
    for header in link_headers:
        for part in header.split(","):
            if "rel=" not in part or "webmention" not in part:
                continue
            match = re.search(r"<([^>]+)>", part)
            if match:
                return urllib.parse.urljoin(target, match.group(1))
    match = LINK_REL_RE.search(body)
    if match:
        href = HREF_RE.search(match.group(0))
        if href:
            return urllib.parse.urljoin(target, href.group(1))
    return None


def send(endpoint: str, source: str, target: str) -> bool:
    body = urllib.parse.urlencode({"source": source, "target": target}).encode()
    request = urllib.request.Request(
        endpoint,
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": USER_AGENT,
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            return 200 <= response.status < 300
    except (OSError, urllib.error.URLError):
        return False


def source_url(html_path: Path, public_root: Path, base_url: str) -> str:
    rel = html_path.parent.relative_to(public_root)
    suffix = "" if str(rel) == "." else f"{rel}/"
    return f"{base_url.rstrip('/')}/{suffix}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("dirs", nargs="+", type=Path, help="public/ subdirectories to scan for index.html")
    parser.add_argument("--public-root", type=Path, required=True)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--state", type=Path, default=Path("data/webmentions-sent.json"))
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    own_domain = urllib.parse.urlparse(args.base_url).netloc
    state: dict[str, bool] = {}
    if args.state.exists():
        state = json.loads(args.state.read_text(encoding="utf-8"))

    sent = 0
    for directory in args.dirs:
        for html_path in sorted(directory.glob("*/index.html")):
            source = source_url(html_path, args.public_root, args.base_url)
            html = html_path.read_text(encoding="utf-8", errors="replace")
            for target in external_targets(extract_links(html), own_domain):
                key = f"{source}|{target}"
                if key in state:
                    continue
                state[key] = True
                endpoint = discover_endpoint(target)
                if not endpoint:
                    continue
                if args.dry_run:
                    print(f"Would send: {source} -> {target} via {endpoint}")
                    sent += 1
                    continue
                if send(endpoint, source, target):
                    print(f"Sent: {source} -> {target} via {endpoint}")
                    sent += 1
                else:
                    print(f"Failed: {source} -> {target} via {endpoint}", file=sys.stderr)

    args.state.parent.mkdir(parents=True, exist_ok=True)
    args.state.write_text(json.dumps(state, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Sent {sent} webmention(s); {len(state)} pair(s) recorded")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
