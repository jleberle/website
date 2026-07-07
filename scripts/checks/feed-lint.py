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
    "dc": "http://purl.org/dc/elements/1.1/",
    "media": "http://search.yahoo.com/mrss/",
}

# Cross-repo contract: Micro.blog imports this reading feed as posts on
# eberle.blog, and ~/git/micro-theme's homepage builds its Currently/Finished
# Reading sections by matching these literal prefixes in the imported post
# text (see layouts/reading.rss.xml's $action / $plainBody). A rendering
# change here silently empties that homepage section without breaking this
# site's own build, so it's asserted here rather than left undetected.
READING_EVENT_PREFIXES = {
    "started-reading": "Started reading: ",
    "finished-reading": "Finished reading: ",
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

    atom_links = channel.findall("atom:link", RSS_NS)
    self_links = [link for link in atom_links if link.get("rel") == "self"]
    hub_links = [link for link in atom_links if link.get("rel") == "hub"]
    if len(self_links) != 1:
        problems.append(Problem(rel, f"expected exactly one atom:link rel=self, found {len(self_links)}"))
    if not hub_links:
        problems.append(Problem(rel, "WebSub atom:link rel=hub is missing"))
    for atom_link in atom_links:
        relation = atom_link.get("rel", "(missing rel)")
        problems.extend(check_absolute_url(atom_link.get("href", ""), rel, f"atom:link rel={relation} href"))

    image = channel.find("image")
    if image is not None:
        for field in ("url", "link"):
            problems.extend(check_absolute_url(text_of(image.find(field)), rel, f"image {field}"))

    for item in channel.findall("item"):
        title = text_of(item.find("title")) or "(untitled item)"
        item_source = f"{rel} :: {title}"
        link = text_of(item.find("link"))
        if link:
            problems.extend(check_absolute_url(link, item_source, "link"))

        guid = item.find("guid")
        guid_value = text_of(guid)
        if guid_value and (guid is None or guid.get("isPermaLink", "").lower() != "false"):
            problems.extend(check_absolute_url(guid_value, item_source, "guid"))
        if guid_value == link and guid is not None and guid.get("isPermaLink", "").lower() == "false":
            problems.append(Problem(item_source, "URL-valued guid is incorrectly marked isPermaLink=false"))

        creator = text_of(item.find("dc:creator", RSS_NS))
        if not creator:
            problems.append(Problem(item_source, "dc:creator is missing"))

        media = item.find("media:content", RSS_NS)
        if media is not None:
            problems.extend(check_absolute_url(media.get("url", ""), item_source, "media:content url"))

        description = text_of(item.find("description"))
        if description:
            problems.extend(check_html_links(description, f"{item_source} description"))
            categories = {text_of(c) for c in item.findall("category")}
            for category, prefix in READING_EVENT_PREFIXES.items():
                if category in categories and not description.startswith(prefix):
                    problems.append(Problem(
                        item_source,
                        f"reading-feed contract: description does not start with {prefix!r} "
                        "(~/git/micro-theme's eberle.blog homepage matches this prefix to "
                        "build its Currently/Finished Reading sections)",
                    ))

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
    if not feed.get("language"):
        problems.append(Problem(rel, "language is missing"))
    websub_hubs = [hub for hub in feed.get("hubs", []) if hub.get("type") == "WebSub"]
    if not websub_hubs:
        problems.append(Problem(rel, "WebSub hub is missing"))
    for hub in websub_hubs:
        problems.extend(check_absolute_url(str(hub.get("url", "")), rel, "WebSub hub url"))
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
