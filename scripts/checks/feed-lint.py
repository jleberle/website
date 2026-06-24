#!/usr/bin/env python3
"""Offline checks for generated RSS and JSON Feed output.

This intentionally avoids network validators. It catches the feed portability
issues most likely to regress locally: malformed XML/JSON, localhost URLs, and
relative URLs inside syndicated HTML content.
"""

from __future__ import annotations

import json
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from html.parser import HTMLParser
from pathlib import Path
from typing import Iterable
from urllib.parse import urlparse


ALLOWED_SCHEMES = {"http", "https", "mailto", "tel"}
LOCAL_HOSTS = {"localhost", "127.0.0.1", "::1"}
RSS_NS = {
    "atom": "http://www.w3.org/2005/Atom",
    "content": "http://purl.org/rss/1.0/modules/content/",
}


@dataclass(frozen=True)
class Problem:
    source: str
    message: str


class LinkExtractor(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.links: list[tuple[str, str]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for name, value in attrs:
            if value is None:
                continue
            if name in {"href", "src", "poster", "data-lightbox-src"}:
                self.links.append((name, value))
            elif name == "srcset":
                for candidate in value.split(","):
                    url = candidate.strip().split(" ", 1)[0]
                    if url:
                        self.links.append((name, url))


def is_localhost(url: str) -> bool:
    parsed = urlparse(url)
    return (parsed.hostname or "").lower() in LOCAL_HOSTS


def is_absolute_url(url: str) -> bool:
    parsed = urlparse(url)
    if parsed.scheme:
        return parsed.scheme.lower() in ALLOWED_SCHEMES
    return False


def check_absolute_url(url: str, source: str, context: str) -> list[Problem]:
    if not url or url.startswith("{"):
        return []
    problems: list[Problem] = []
    if is_localhost(url):
        problems.append(Problem(source, f"{context} points at localhost: {url}"))
    if not is_absolute_url(url):
        problems.append(Problem(source, f"{context} is not absolute: {url}"))
    return problems


def check_html_links(html: str, source: str) -> list[Problem]:
    parser = LinkExtractor()
    parser.feed(html)
    problems: list[Problem] = []
    for attr, url in parser.links:
        problems.extend(check_absolute_url(url, source, attr))
    return problems


def text_of(node: ET.Element | None) -> str:
    return (node.text or "").strip() if node is not None else ""


def rss_files(public_dir: Path) -> Iterable[Path]:
    for path in sorted(public_dir.rglob("*.xml")):
        if path.name == "sitemap.xml":
            continue
        yield path


def check_rss(path: Path, public_dir: Path) -> list[Problem]:
    rel = str(path.relative_to(public_dir))
    try:
        tree = ET.parse(path)
    except ET.ParseError as exc:
        return [Problem(rel, f"malformed XML: {exc}")]

    root = tree.getroot()
    if root.tag != "rss":
        return []

    problems: list[Problem] = []
    channel = root.find("channel")
    if channel is None:
        return [Problem(rel, "RSS feed has no channel")]

    for field in ("link",):
        problems.extend(check_absolute_url(text_of(channel.find(field)), rel, f"channel {field}"))

    atom_link = channel.find("atom:link", RSS_NS)
    if atom_link is not None:
        problems.extend(check_absolute_url(atom_link.get("href", ""), rel, "atom:link href"))

    image = channel.find("image")
    if image is not None:
        for field in ("url", "link"):
            problems.extend(check_absolute_url(text_of(image.find(field)), rel, f"image {field}"))

    for item in channel.findall("item"):
        title = text_of(item.find("title")) or "(untitled item)"
        item_source = f"{rel} :: {title}"
        for field in ("link", "guid"):
            value = text_of(item.find(field))
            if value:
                problems.extend(check_absolute_url(value, item_source, field))

        description = text_of(item.find("description"))
        if description:
            problems.extend(check_html_links(description, f"{item_source} description"))

        content = item.find("content:encoded", RSS_NS)
        if content is not None and content.text:
            problems.extend(check_html_links(content.text, f"{item_source} content:encoded"))

    return problems


def check_json_feed(path: Path, public_dir: Path) -> list[Problem]:
    rel = str(path.relative_to(public_dir))
    try:
        feed = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return [Problem(rel, f"malformed JSON: {exc}")]

    problems: list[Problem] = []
    for field in ("home_page_url", "feed_url", "icon", "favicon"):
        value = feed.get(field)
        if value:
            problems.extend(check_absolute_url(str(value), rel, field))

    for index, item in enumerate(feed.get("items", []), start=1):
        title = item.get("title") or f"item {index}"
        item_source = f"{rel} :: {title}"
        for field in ("id", "url", "external_url", "image", "banner_image"):
            value = item.get(field)
            if value:
                problems.extend(check_absolute_url(str(value), item_source, field))
        content_html = item.get("content_html")
        if content_html:
            problems.extend(check_html_links(str(content_html), f"{item_source} content_html"))
    return problems


def main() -> int:
    public_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "public")
    if not public_dir.is_dir():
        print(f"feed-lint: generated public directory not found: {public_dir}", file=sys.stderr)
        return 2

    problems: list[Problem] = []
    rss_count = 0
    for path in rss_files(public_dir):
        rss_count += 1
        problems.extend(check_rss(path, public_dir))

    json_path = public_dir / "feed.json"
    if json_path.exists():
        problems.extend(check_json_feed(json_path, public_dir))
    else:
        problems.append(Problem("feed.json", "JSON Feed file is missing"))

    if problems:
        for problem in problems:
            print(f"{problem.source}: {problem.message}")
        return 1

    print(f"Feed lint clean ({rss_count} RSS feeds + feed.json)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
