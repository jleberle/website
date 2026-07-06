#!/usr/bin/env python3
"""Wait for deployed RSS feeds, then notify WebSub and Micro.blog."""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from collections import defaultdict
from pathlib import Path


ATOM = "{http://www.w3.org/2005/Atom}link"
USER_AGENT = "jaredeberle.org feed publisher"
MICROBLOG_PING = "https://micro.blog/ping"


def discover(path: Path) -> tuple[str, str]:
    if path.suffix == ".json":
        feed = json.loads(path.read_text(encoding="utf-8"))
        self_url = str(feed.get("feed_url", ""))
        hub_urls = [
            str(hub.get("url", ""))
            for hub in feed.get("hubs", [])
            if hub.get("type") == "WebSub"
        ]
        if not self_url or len(hub_urls) != 1 or not hub_urls[0]:
            raise ValueError(f"{path}: expected a feed_url and exactly one WebSub hub")
        return hub_urls[0], self_url

    root = ET.parse(path).getroot()
    channel = root.find("channel")
    if channel is None:
        raise ValueError(f"{path}: RSS channel missing")
    links = channel.findall(ATOM)
    self_urls = [link.get("href", "") for link in links if link.get("rel") == "self"]
    hub_urls = [link.get("href", "") for link in links if link.get("rel") == "hub"]
    if len(self_urls) != 1 or len(hub_urls) != 1 or not self_urls[0] or not hub_urls[0]:
        raise ValueError(f"{path}: expected exactly one non-empty WebSub self link and hub link")
    return hub_urls[0], self_urls[0]


def fetch(url: str) -> bytes:
    request = urllib.request.Request(
        url,
        headers={"Cache-Control": "no-cache", "User-Agent": USER_AGENT},
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        return response.read()


def wait_until_deployed(path: Path, topic: str, timeout: int, interval: int) -> None:
    expected = path.read_bytes()
    deadline = time.monotonic() + timeout
    last_error = "deployed feed did not match the build"
    while True:
        try:
            if fetch(topic) == expected:
                print(f"Deployed feed is current: {topic}")
                return
            last_error = "deployed feed does not yet match the build"
        except (OSError, urllib.error.URLError) as exc:
            last_error = str(exc)
        if time.monotonic() >= deadline:
            raise TimeoutError(f"{topic}: {last_error} after {timeout}s")
        time.sleep(interval)


def notify(hub: str, topics: list[str], dry_run: bool) -> None:
    fields: list[tuple[str, str]] = [("hub.mode", "publish")]
    fields.extend(("hub.url", topic) for topic in topics)
    if dry_run:
        print(f"Would notify {hub}: {', '.join(topics)}")
        return
    body = urllib.parse.urlencode(fields).encode()
    request = urllib.request.Request(
        hub,
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": USER_AGENT,
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status < 200 or response.status >= 300:
            raise RuntimeError(f"hub returned HTTP {response.status}")
    print(f"Notified {hub}: {', '.join(topics)}")


def notify_microblog(topic: str, dry_run: bool) -> None:
    if dry_run:
        print(f"Would notify {MICROBLOG_PING}: {topic}")
        return
    body = urllib.parse.urlencode({"url": topic}).encode()
    request = urllib.request.Request(
        MICROBLOG_PING,
        data=body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "User-Agent": USER_AGENT,
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        if response.status < 200 or response.status >= 300:
            raise RuntimeError(f"Micro.blog returned HTTP {response.status}")
    print(f"Notified Micro.blog: {topic}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("feeds", nargs="+", type=Path)
    parser.add_argument("--wait", type=int, default=0, metavar="SECONDS")
    parser.add_argument("--interval", type=int, default=10, metavar="SECONDS")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    hubs: dict[str, list[tuple[Path, str]]] = defaultdict(list)
    try:
        for path in args.feeds:
            hub, topic = discover(path)
            hubs[hub].append((path, topic))
        if args.wait:
            for entries in hubs.values():
                for path, topic in entries:
                    wait_until_deployed(path, topic, args.wait, args.interval)
        for hub, entries in hubs.items():
            notify(hub, [topic for _, topic in entries], args.dry_run)
        for entries in hubs.values():
            for _, topic in entries:
                notify_microblog(topic, args.dry_run)
    except (
        OSError,
        RuntimeError,
        ValueError,
        json.JSONDecodeError,
        ET.ParseError,
        TimeoutError,
        urllib.error.URLError,
    ) as exc:
        print(f"WebSub notification failed: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
