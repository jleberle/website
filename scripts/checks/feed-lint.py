#!/usr/bin/env python3
"""Offline checks for generated RSS and JSON Feed output.

This intentionally avoids network validators. It catches the feed portability
issues most likely to regress locally: malformed XML/JSON, localhost URLs, and
relative URLs inside syndicated HTML content.

It also guards READING-FEED LINK STABILITY — see check_reading_link_stability.
Run with --update after a deliberate link change to re-record the snapshot.
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

# Path of the reading feed within public/, and the committed record of which
# <link> each reading event has already been published with.
READING_FEED_REL = "reading/index.xml"
LINK_SNAPSHOT_PATH = Path(__file__).resolve().parent / "reading-feed-links.json"


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


def read_reading_events(public_dir: Path) -> dict[str, str]:
    """Map guid -> <link> for every item in the built reading feed."""
    path = public_dir / READING_FEED_REL
    if not path.is_file():
        return {}
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return {}  # malformed XML is already reported by check_rss
    channel = root.find("channel")
    if channel is None:
        return {}
    events: dict[str, str] = {}
    for item in channel.findall("item"):
        guid = text_of(item.find("guid"))
        link = text_of(item.find("link"))
        if guid and link:
            events[guid] = link
    return events


def load_link_snapshot() -> dict[str, str]:
    if not LINK_SNAPSHOT_PATH.is_file():
        return {}
    try:
        data = json.loads(LINK_SNAPSHOT_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {}
    return dict(data.get("links", {}))


def write_link_snapshot(links: dict[str, str]) -> None:
    payload = {
        "_comment": (
            "guid -> the <link> that reading event has been published with. "
            "Micro.blog dedupes imported items on <link>, not <guid>, so changing "
            "a published link creates a duplicate post on eberle.blog. Maintained "
            "by scripts/checks/feed-lint.py; re-record with --update only when a "
            "link change is deliberate and the duplicate cost is accepted."
        ),
        "links": dict(sorted(links.items())),
    }
    LINK_SNAPSHOT_PATH.write_text(
        json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )


def check_reading_link_stability(public_dir: Path) -> list[Problem]:
    """Fail when a reading event's <link> changes after it has been published.

    Micro.blog imports this feed as posts on eberle.blog and decides whether an
    item is new by its <link>, NOT its <guid> (established when a started and a
    finished event sharing one link caused the second to be silently dropped).
    So a link that has already gone out is effectively immutable: change it and
    every affected item still inside the feed window is imported AGAIN as a new
    post. That is what produced both the 2026-07 (~60 posts) and 2026-08 (15
    posts) duplicate cleanups on eberle.blog.

    The snapshot deliberately records links only as they appear in the BUILT
    feed, which is capped by services.rss.limit in hugo.yaml. That is the
    correct scope, not a shortcut: an event that has never been inside the
    window has never been offered to Micro.blog, so its link carries no history
    to protect. Entries are never pruned, so an event that ages out and later
    returns (a bumped *_announced date) is still checked against what it was
    published with the first time.
    """
    current = read_reading_events(public_dir)
    if not current:
        return []

    recorded = load_link_snapshot()
    if not recorded:
        return [Problem(
            READING_FEED_REL,
            "reading-feed link snapshot is missing or empty — seed it with "
            "`python3 scripts/checks/feed-lint.py public --update`",
        )]

    changed = [
        (guid, recorded[guid], link)
        for guid, link in current.items()
        if guid in recorded and recorded[guid] != link
    ]
    if not changed:
        return []

    problems = [Problem(
        READING_FEED_REL,
        f"{len(changed)} published reading link(s) changed — Micro.blog will import "
        f"{len(changed)} DUPLICATE post(s) on eberle.blog, one per item below, because "
        "it dedupes on <link>. Every one of these is inside the current feed window, "
        "so the cost is immediate, not theoretical.",
    )]
    for guid, was, now in sorted(changed):
        problems.append(Problem(f"{READING_FEED_REL} :: {guid}", f"was  {was}"))
        problems.append(Problem(f"{READING_FEED_REL} :: {guid}", f"now  {now}"))
    problems.append(Problem(
        READING_FEED_REL,
        "If the change is deliberate and the duplicates are acceptable, re-record with "
        "`python3 scripts/checks/feed-lint.py public --update` and commit the snapshot. "
        "If not, restore the old link — for a source with an isbn/doi/access_url the "
        "usual cause is a renamed content/sources/<slug>/ folder.",
    ))
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
    args = [a for a in sys.argv[1:] if a != "--update"]
    update = "--update" in sys.argv[1:]
    public_dir = Path(args[0] if args else "public")
    if not public_dir.is_dir():
        print(f"feed-lint: generated public directory not found: {public_dir}", file=sys.stderr)
        return 2

    # --update re-records the reading-link snapshot from the current build and
    # exits. Deliberately a separate mode: it is the switch that says "yes, I
    # accept the duplicate posts this link change will create on eberle.blog".
    if update:
        current = read_reading_events(public_dir)
        if not current:
            print(f"feed-lint: no reading events found in {public_dir / READING_FEED_REL}", file=sys.stderr)
            return 2
        merged = load_link_snapshot()
        added = {g: l for g, l in current.items() if g not in merged}
        rewritten = {g: (merged[g], l) for g, l in current.items() if g in merged and merged[g] != l}
        merged.update(current)
        write_link_snapshot(merged)
        print(f"Recorded {len(merged)} reading link(s) in {LINK_SNAPSHOT_PATH.name} "
              f"({len(added)} new, {len(rewritten)} rewritten)")
        for guid, (was, now) in sorted(rewritten.items()):
            print(f"  rewritten {guid}\n    was {was}\n    now {now}")
        return 0

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

    problems.extend(check_reading_link_stability(public_dir))

    if problems:
        for problem in problems:
            print(f"{problem.source}: {problem.message}")
        return 1

    tracked = len(load_link_snapshot())
    print(f"Feed lint clean ({rss_count} RSS feeds + feed.json; "
          f"{tracked} reading link(s) stable)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
