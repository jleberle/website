#!/usr/bin/env python3
"""Build the public writing log at /writing-log.

WHY THIS EXISTS
---------------
"How much did I write, and when" has no single source of truth. The blog knows,
because Hugo content lives in git and every commit is dated. The Obsidian vault
knows nothing at all -- Obsidian keeps no history, and a file's mtime is its last
touch, not a record of when its words were written.

TWO SOURCES, TWO MECHANISMS
---------------------------
The blog is walked as *git history*: for every markdown file a commit touched,
subtract the word count before from the word count after.

The vault cannot be, because it lives on three machines that share files through
Obsidian Sync rather than through git. Giving each machine its own repo and
adding up the results counts every synced word once per machine -- Sync delivers
the same 500 words everywhere, and each repo sees them as new. So the vault is
walked as a *census* instead: each run records how long each counted file is
right now, and the deltas are derived afterwards from the merged history. The
same file observed by three machines still contributes its words once, because
the merge is over file states, not over per-machine deltas.

Each machine writes only its own observation file (data/observations/<host>.json),
so two machines syncing on the same day merge cleanly instead of conflicting.

Census entries are dated by the file's mtime, not by when the census ran. That is
what makes a manual command workable: write on the laptop Tuesday, run this on
the desktop Friday, and the words still land on Tuesday. Forgetting to run costs
you publication delay, not accuracy.

PATHS ARE HASHED, DELIBERATELY
------------------------------
The observation files are committed to a public repo. A census keyed by path
would publish the name of every unpublished archival note. The merge only needs
file *identity* to compute per-file deltas, never the name, and the same path
hashes identically on every machine -- so paths are stored as hashes and the leak
never happens. Same for the blog-draft slug list.

WHAT IT WRITES
--------------
data/writing-log.json, committed to this repo, because StaticHost builds the site
in a container that has never seen the vault. Hugo reads it from hugo.Data.

WHAT IT CANNOT SEE
------------------
Word-count deltas measure size, not effort. Rewriting a 500-word paragraph into a
better 500-word paragraph is a day's work that registers as zero. Deleting is
likewise invisible in the headline number. Both are accepted: the alternative is
counting diff churn, which rewards thrashing a file over writing well.

Census-specific: mtime is last-touch, so a file edited Tuesday and again Thursday
lands the whole week's growth on Thursday. Run more often and it sharpens. And
words written and deleted between two runs are never observed at all.

Usage:
    python3 scripts/writing-log.py observe    # census the vault on this machine
    python3 scripts/writing-log.py            # rebuild data/writing-log.json
    python3 scripts/writing-log.py --check    # non-zero exit if it would change
    python3 scripts/writing-log.py --stats    # rebuild and print a summary
"""

from __future__ import annotations

import fnmatch
import hashlib
import json
import os
import re
import socket
import subprocess
import sys
from collections import defaultdict
from datetime import date as date_type
from datetime import datetime, timezone
from pathlib import Path

try:
    import yaml
except ModuleNotFoundError:  # pragma: no cover - environment guard
    sys.exit(
        "writing-log.py needs PyYAML to read writing-log.yaml.\n"
        "  pip3 install --user pyyaml\n"
        "Only this script needs it; the StaticHost build reads the committed JSON."
    )

REPO_ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = REPO_ROOT / "writing-log.yaml"
OUTPUT_PATH = REPO_ROOT / "data" / "writing-log.json"
OBSERVATIONS_DIR = REPO_ROOT / "data" / "observations"

# Salt for path hashing. Not a secret and not doing security work -- it only has
# to be identical on every machine, or the same note hashes two ways and its
# words get counted twice. Never change it: doing so orphans every recorded
# observation and re-counts the entire vault from scratch.
HASH_SALT = "jaredeberle.org/writing-log/v1"

# Git's empty-tree object. Diffing a root commit against it is how the very
# first commit's files show up as additions rather than as nothing at all.
EMPTY_TREE = "4b825dc642cb6eb9a060e54bf8d69288fbee4904"

FRONT_MATTER_RE = re.compile(r"\A---\r?\n(.*?)\r?\n---\r?\n", re.DOTALL)
FENCED_CODE_RE = re.compile(r"^[ \t]*(```|~~~).*?(?:^[ \t]*\1[ \t]*$|\Z)", re.DOTALL | re.MULTILINE)
BLOCKQUOTE_RE = re.compile(r"^[ \t]*>.*$", re.MULTILINE)
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
# Obsidian comments: hidden in the rendered note, so never counted. Also how the
# Zotero importer brackets its own bookkeeping (`%% end annotations %%`,
# `%% Import Date: ... %%`).
OBSIDIAN_COMMENT_RE = re.compile(r"%%.*?%%", re.DOTALL)
# An imported Zotero highlight. The current templates wrap these in `> [!quote]`
# callouts, which blockquote stripping already removes -- but every annotated
# note actually in the vault predates that and stores the highlight as flat
# prose with a trailing page link, which blockquote stripping does NOT catch:
#
#   Ultimately, the reason for the reluctance … [(p. 10)](zotero://open-pdf/…)
#
# The link is a machine-written fingerprint that cannot appear in composed
# prose, so the line carrying it is the source's words, not the author's. Drop
# the whole line: the highlight is the line.
ZOTERO_ANNOTATION_RE = re.compile(r"^.*zotero://open-pdf.*$", re.MULTILINE)
# Dataview inline fields (`start-date:: 1982-08-01`, `page-no:: 14`). Structured
# metadata that happens to live in the body rather than the front matter; the
# note templates emit a block of them. Never prose.
#
# The key is deliberately a single token with no spaces. Allowing spaces (as
# Dataview itself does) makes the pattern swallow any sentence that happens to
# contain `::` — "the ratio was 3::1 in the report" matched in testing and the
# whole line vanished. Every field the templates emit is one hyphenated word,
# so precision is the right trade.
DATAVIEW_FIELD_RE = re.compile(r"^[ \t]*[A-Za-z][A-Za-z0-9_-]*::.*$", re.MULTILINE)
HTML_TAG_RE = re.compile(r"</?[A-Za-z][^>]*>")
IMAGE_RE = re.compile(r"!\[[^\]]*\]\([^)]*\)")
EMBED_RE = re.compile(r"!\[\[[^\]]*\]\]")
WIKILINK_RE = re.compile(r"\[\[([^\]]+)\]\]")
MD_LINK_RE = re.compile(r"\[([^\]]*)\]\((?:[^)(]|\([^)]*\))*\)")
BARE_URL_RE = re.compile(r"https?://\S+")
INLINE_CODE_RE = re.compile(r"`[^`\n]*`")
# A token counts as a word if it contains a letter or digit. Latin-1/Extended-A
# ranges keep accented names in the Nicaragua and Mexico material countable.
WORD_RE = re.compile(r"[0-9A-Za-zÀ-ɏ][0-9A-Za-zÀ-ɏ'’‐-―-]*")
DATE_PREFIX_RE = re.compile(r"^\d{4}-\d{2}-\d{2}[-_ ]+")
NON_SLUG_RE = re.compile(r"[^a-z0-9]+")


def run_git(repo: Path, args: list[str]) -> str:
    """Run a git command in `repo` and return stdout as text."""
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        capture_output=True,
        check=True,
    )
    return result.stdout.decode("utf-8", errors="replace")


class BlobReader:
    """Reads blob contents from a repo over one long-lived `git cat-file --batch`.

    History walking asks for thousands of blobs. Spawning `git show` per blob
    costs a process each time; --batch keeps a single pipe open and answers on
    it. Counts are memoised by blob SHA, which pays off heavily -- an unchanged
    file carries the same SHA across every commit that touched its neighbours,
    and identical boilerplate across notes hashes identically too.
    """

    def __init__(self, repo: Path) -> None:
        self.repo = repo
        self._cache: dict[str, int] = {}
        self._tags_cache: dict[str, frozenset[str]] = {}
        self._proc = subprocess.Popen(
            ["git", "-C", str(repo), "cat-file", "--batch"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
        )

    def read(self, sha: str) -> bytes:
        assert self._proc.stdin and self._proc.stdout
        self._proc.stdin.write(f"{sha}\n".encode())
        self._proc.stdin.flush()
        header = self._proc.stdout.readline().decode().strip()
        if header.endswith(("missing", "ambiguous")):
            return b""
        size = int(header.split()[2])
        body = self._proc.stdout.read(size)
        self._proc.stdout.read(1)  # trailing newline
        return body

    def text(self, sha: str) -> str:
        return self.read(sha).decode("utf-8", errors="replace")

    def close(self) -> None:
        assert self._proc.stdin
        self._proc.stdin.close()
        self._proc.wait()


def split_front_matter(text: str) -> tuple[str, str]:
    """Return (front matter body, content). Front matter is never prose."""
    match = FRONT_MATTER_RE.match(text)
    if not match:
        return "", text
    return match.group(1), text[match.end():]


def front_matter_has_any(front: str, fields: list[str]) -> bool:
    """True if front matter declares any of `fields` with a non-empty value.

    A second, independent handle on "this note came out of Zotero". The tag
    list is editable and a reorganisation could drop it; `citekey` is written by
    the importer, is what the rest of the toolchain keys on, and has no reason
    to appear in a note someone actually composed.
    """
    if not fields or not front.strip():
        return False
    try:
        data = yaml.safe_load(front)
    except yaml.YAMLError:
        return False
    if not isinstance(data, dict):
        return False
    return any(
        data.get(field) not in (None, "", [], {})
        for field in fields
    )


def front_matter_tags(front: str) -> frozenset[str]:
    """Tags declared in front matter, lowercased. Empty when unparseable.

    Historical revisions include half-finished files, so a YAML error here means
    "no tags I can prove", not a crash.
    """
    if not front.strip():
        return frozenset()
    try:
        data = yaml.safe_load(front)
    except yaml.YAMLError:
        return frozenset()
    if not isinstance(data, dict):
        return frozenset()
    raw = data.get("tags")
    if raw is None:
        return frozenset()
    if isinstance(raw, str):
        raw = [raw]
    if not isinstance(raw, list):
        return frozenset()
    return frozenset(str(tag).strip().lower() for tag in raw if tag is not None)


def front_matter_date(front: str, fields: list[str]) -> str | None:
    """First parseable date among `fields`, as YYYY-MM-DD."""
    if not front.strip():
        return None
    try:
        data = yaml.safe_load(front)
    except yaml.YAMLError:
        return None
    if not isinstance(data, dict):
        return None
    for field in fields:
        value = data.get(field)
        if value is None:
            continue
        if isinstance(value, datetime):
            return value.date().isoformat()
        if hasattr(value, "isoformat"):  # datetime.date
            return value.isoformat()
        text = str(value).strip()
        if not text:
            continue
        match = re.match(r"(\d{4}-\d{2}-\d{2})", text)
        if match:
            return match.group(1)
    return None


def count_words(text: str, *, strip_code: bool, strip_blockquotes: bool) -> int:
    """Words the author composed, with markup and quoted material removed."""
    _, body = split_front_matter(text)

    body = HTML_COMMENT_RE.sub(" ", body)
    # Before blockquote stripping, so an annotation is removed whether it is
    # flat prose (the older import format) or inside a `> [!quote]` callout.
    body = OBSIDIAN_COMMENT_RE.sub(" ", body)
    body = ZOTERO_ANNOTATION_RE.sub(" ", body)
    body = DATAVIEW_FIELD_RE.sub(" ", body)
    if strip_code:
        body = FENCED_CODE_RE.sub(" ", body)
    if strip_blockquotes:
        body = BLOCKQUOTE_RE.sub(" ", body)

    body = EMBED_RE.sub(" ", body)
    body = IMAGE_RE.sub(" ", body)
    # Keep a link's visible text, drop its target.
    body = MD_LINK_RE.sub(lambda m: f" {m.group(1)} ", body)
    # [[path/to/note|Alias]] reads as "Alias"; [[Note Title]] as its last segment.
    body = WIKILINK_RE.sub(
        lambda m: " " + (m.group(1).split("|")[-1] if "|" in m.group(1) else m.group(1).split("/")[-1]) + " ",
        body,
    )
    body = BARE_URL_RE.sub(" ", body)
    body = INLINE_CODE_RE.sub(" ", body)
    body = HTML_TAG_RE.sub(" ", body)

    return len(WORD_RE.findall(body))


def path_matches(path: str, patterns: list[str]) -> bool:
    """True if `path` matches any glob, treating `**` as spanning directories."""
    for pattern in patterns:
        if fnmatch.fnmatch(path, pattern):
            return True
        # fnmatch has no notion of `**`; "a/**/b.md" should also match "a/b.md".
        if "/**/" in pattern and fnmatch.fnmatch(path, pattern.replace("/**/", "/", 1)):
            return True
    return False


def slug_for(path: str) -> str:
    """Normalise a filename to a slug so a vault draft and its published post match.

    Hugo page bundles are `2026-05-12-some-title/index.md`, where the filename
    carries no identity at all -- the directory does. Taking the stem blindly
    would call every bundle "index" and collapse them into one slug.
    """
    candidate = Path(path)
    stem = candidate.stem
    if stem in ("index", "_index") and candidate.parent.name:
        stem = candidate.parent.name
    stem = DATE_PREFIX_RE.sub("", stem)
    return NON_SLUG_RE.sub("-", stem.lower()).strip("-")


def days_between(earlier: str, later: str) -> int:
    """Calendar days from `earlier` to `later`; negative if the order is reversed."""
    start = datetime.strptime(earlier, "%Y-%m-%d").date()
    end = datetime.strptime(later, "%Y-%m-%d").date()
    return (end - start).days


def commit_list(repo: Path) -> list[tuple[str, str]]:
    """Every commit oldest-first, as (sha, YYYY-MM-DD author date)."""
    out = run_git(repo, ["log", "--reverse", "--format=%H %ad", "--date=short"])
    commits = []
    for line in out.splitlines():
        if not line.strip():
            continue
        sha, _, date = line.partition(" ")
        commits.append((sha, date.strip()))
    return commits


def changed_files(repo: Path, sha: str, is_root: bool) -> list[tuple[str, str, str, str, str]]:
    """(old_blob, new_blob, status, old_path, new_path) per file the commit touched.

    Uses --raw -z: vault filenames contain spaces, commas and curly quotes, and
    NUL termination is the only quoting-proof way to read them back.

    Rename detection (-M) is not optional here. This repo has reorganised
    content wholesale -- the 2026-05-20 migration moved every review and quote
    to a date-prefixed path -- and without -M git reports each move as a delete
    plus an add, which reads as writing the entire post over again. With -M the
    pair collapses to one R entry whose word delta is the real edit, usually
    zero. Renames carry two paths in the stream instead of one.
    """
    args = ["diff-tree", "-r", "--no-commit-id", "--raw", "-z", "-M"]
    args += [EMPTY_TREE, sha] if is_root else [sha + "^", sha]
    raw = subprocess.run(
        ["git", "-C", str(repo), *args], capture_output=True, check=True
    ).stdout.decode("utf-8", errors="replace")

    fields = raw.split("\0")
    entries: list[tuple[str, str, str, str]] = []
    index = 0
    while index < len(fields):
        meta = fields[index]
        if not meta.startswith(":"):
            index += 1
            continue
        parts = meta[1:].split()
        if len(parts) < 5 or index + 1 >= len(fields):
            index += 1
            continue
        _, _, old_sha, new_sha, status = parts[:5]
        if status[0] in ("R", "C") and index + 2 < len(fields):
            # old path at index+1, new path at index+2. Attribute to the new
            # one, but keep the old: whether it was in scope decides whether
            # this is a move within the counted set or an arrival into it.
            entries.append((old_sha, new_sha, status, fields[index + 1], fields[index + 2]))
            index += 3
        else:
            path = fields[index + 1]
            entries.append((old_sha, new_sha, status, path, path))
            index += 2
    return entries


def is_null(sha: str) -> bool:
    """Git spells "this side did not exist" as an all-zero SHA."""
    return set(sha) == {"0"}


# --------------------------------------------------------------------------
# Census: the vault
# --------------------------------------------------------------------------


def path_hash(text: str) -> str:
    """Stable, machine-independent identifier for a path or slug.

    Sixteen hex characters of salted SHA-256. This is a privacy measure, not a
    security one: the observation files are committed to a public repo, and the
    merge needs to know that two machines are talking about the same file
    without publishing the name of every unpublished archival note.
    """
    return hashlib.sha256(f"{HASH_SALT}\0{text}".encode("utf-8")).hexdigest()[:16]


def machine_id() -> str:
    """Short, filesystem-safe name for this computer.

    Names the observation file. Each machine writes only its own, which is what
    keeps three computers from ever producing a merge conflict over the census.
    """
    raw = os.environ.get("WRITING_LOG_MACHINE") or socket.gethostname()
    raw = raw.split(".")[0].strip().lower()
    cleaned = NON_SLUG_RE.sub("-", raw).strip("-")
    return cleaned or "unknown"


def census_path(source: dict) -> Path:
    """Where the vault lives on this machine.

    The three machines need not agree on this, so an env var overrides the
    configured default rather than each one carrying a patched config.
    """
    env_key = source.get("path_env")
    raw = (os.environ.get(env_key) if env_key else None) or source["path"]
    return Path(raw).expanduser()


def iter_census_files(root: Path, include: list[str], exclude: list[str]):
    """Every in-scope markdown file in the vault, as (relative path, absolute).

    Walks the filesystem rather than git, because the vault has no git. Prunes
    dot-directories on the way down: `.obsidian` alone holds thousands of files
    and none of them are writing.
    """
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if not d.startswith("."))
        for name in sorted(filenames):
            if not name.endswith(".md") or name.startswith("."):
                continue
            absolute = Path(dirpath) / name
            relative = absolute.relative_to(root).as_posix()
            if path_matches(relative, include) and not path_matches(relative, exclude):
                yield relative, absolute


def observe(source: dict, options: dict) -> tuple[int, int]:
    """Record how long every counted vault file is right now.

    Returns (files in scope, entries written). Writes this machine's observation
    file only, and only where something actually changed -- a run that finds no
    new writing leaves the file byte-identical, so it never produces a commit.
    """
    root = census_path(source)
    if not root.is_dir():
        sys.exit(f"writing-log: vault not found at {root}")

    include = source.get("include", ["**/*.md"])
    exclude = source.get("exclude", [])
    excluded_tags = {t.lower() for t in source.get("exclude_frontmatter_tags", [])}
    excluded_fields = list(source.get("exclude_frontmatter_fields", []))
    draft_patterns = source.get("draft_paths", [])

    path = OBSERVATIONS_DIR / f"{machine_id()}.json"
    if path.exists():
        record = json.loads(path.read_text(encoding="utf-8"))
    else:
        record = {"machine": machine_id(), "files": {}, "draft_slugs": []}
    files: dict[str, dict[str, int]] = record.get("files", {})
    draft_slugs = set(record.get("draft_slugs", []))

    today = date_type.today()
    scanned = 0
    written = 0

    for relative, absolute in iter_census_files(root, include, exclude):
        try:
            text = absolute.read_text(encoding="utf-8", errors="replace")
        except OSError:
            continue

        front, _ = split_front_matter(text)
        if excluded_tags and front_matter_tags(front) & excluded_tags:
            continue
        if front_matter_has_any(front, excluded_fields):
            continue

        scanned += 1
        if draft_patterns and path_matches(relative, draft_patterns):
            draft_slugs.add(path_hash(slug_for(relative)))

        words = count_words(
            text,
            strip_code=options["strip_code"],
            strip_blockquotes=options["strip_blockquotes"],
        )

        # mtime, not now(): this is the whole reason a manual command works
        # across machines. Clamped to today because a clock skew or a restored
        # backup can date a file in the future, and a chart with a row three
        # months ahead is worse than one that is a day coarse.
        stamp = date_type.fromtimestamp(absolute.stat().st_mtime)
        when = min(stamp, today).isoformat()

        timeline = files.setdefault(path_hash(relative), {})
        # Nothing to say unless the length changed since this machine last
        # looked. Without this the file would grow by every scanned note on
        # every run, and every run would produce a commit.
        latest = timeline[max(timeline)] if timeline else None
        if latest == words and (not timeline or when >= max(timeline)):
            continue
        if timeline.get(when) == words:
            continue
        timeline[when] = words
        written += 1

    record["machine"] = machine_id()
    record["files"] = {key: dict(sorted(value.items())) for key, value in sorted(files.items())}
    record["draft_slugs"] = sorted(draft_slugs)

    OBSERVATIONS_DIR.mkdir(parents=True, exist_ok=True)
    rendered = json.dumps(record, indent=2, ensure_ascii=False) + "\n"
    if not path.exists() or path.read_text(encoding="utf-8") != rendered:
        path.write_text(rendered, encoding="utf-8")
    return scanned, written


def load_observations() -> list[dict]:
    """Every machine's observation file."""
    if not OBSERVATIONS_DIR.is_dir():
        return []
    records = []
    for path in sorted(OBSERVATIONS_DIR.glob("*.json")):
        try:
            records.append(json.loads(path.read_text(encoding="utf-8")))
        except json.JSONDecodeError:
            sys.exit(f"writing-log: {path} is not valid JSON")
    return records


def census_draft_slugs(records: list[dict]) -> set[str]:
    """Hashed slugs of every blog draft any machine has ever seen in the vault."""
    slugs: set[str] = set()
    for record in records:
        slugs.update(record.get("draft_slugs", []))
    return slugs


def walk_census(source: dict, records: list[dict]) -> dict:
    """Daily word deltas for the vault, merged across every machine.

    The merge is over file *states*, never over per-machine deltas. Three
    machines observing the same synced file all report the same length for the
    same day, so the timeline collapses to one entry and the words are counted
    once. Adding up per-machine deltas instead would multiply by the number of
    machines -- that is the bug this whole mechanism exists to avoid.

    Where two machines disagree about one day, the larger count wins. A machine
    whose Obsidian Sync is behind reports a stale, shorter file, and treating
    that as a deletion would invent negative days out of a sync lag. The cost is
    that a genuine deletion stays invisible until every machine has caught up,
    at which point the next run corrects it -- the whole timeline is recomputed
    from scratch every time, so nothing is baked in.
    """
    start = str(source.get("census_start", "1970-01-01"))

    timelines: defaultdict[str, dict[str, int]] = defaultdict(dict)
    for record in records:
        for key, entries in record.get("files", {}).items():
            for when, words in entries.items():
                timelines[key][when] = max(timelines[key].get(when, 0), int(words))

    days_added: defaultdict[str, int] = defaultdict(int)
    days_net: defaultdict[str, int] = defaultdict(int)
    days_files: defaultdict[str, set[str]] = defaultdict(set)

    for key, timeline in timelines.items():
        previous = 0
        for when in sorted(timeline):
            words = timeline[when]
            # Everything at or before census_start is the starting position, not
            # a day's work: the vault held years of writing before the first
            # census ran, and crediting it to whatever mtime it happens to carry
            # would bury every real day under a handful of enormous ones. A file
            # first seen after census_start is genuinely new and counts in full.
            if when <= start:
                previous = max(previous, words)
                continue
            delta = words - previous
            previous = words
            if delta == 0:
                continue
            if delta > 0:
                days_added[when] += delta
            days_net[when] += delta
            days_files[when].add(key)

    return {
        "added": dict(days_added),
        "net": dict(days_net),
        "files": {day: len(keys) for day, keys in days_files.items()},
    }


# --------------------------------------------------------------------------
# Git history: the blog
# --------------------------------------------------------------------------


def walk_source(source: dict, options: dict, skip_slugs: set[str]) -> dict:
    """Daily word deltas for one repo."""
    repo = resolve_repo(source)
    if not (repo / ".git").exists():
        sys.exit(f"writing-log: {repo} is not a git repository")

    include = source.get("include", ["**/*.md"])
    exclude = source.get("exclude", [])
    excluded_tags = {t.lower() for t in source.get("exclude_frontmatter_tags", [])}
    excluded_fields = list(source.get("exclude_frontmatter_fields", []))
    initial_mode = source.get("initial_commit", "count")
    backfill = source.get("backfill_added") == "frontmatter-date"
    backfill_threshold = int(source.get("backfill_threshold_days", 3))
    date_fields = source.get("date_fields", ["date", "publishDate"])

    blobs = BlobReader(repo)
    counts: dict[str, int] = {}
    tags: dict[str, frozenset[str]] = {}
    fronts: dict[str, str] = {}

    def measure(sha: str) -> int:
        if is_null(sha):
            return 0
        if sha not in counts:
            text = blobs.text(sha)
            front, _ = split_front_matter(text)
            fronts[sha] = front
            tags[sha] = front_matter_tags(front)
            counts[sha] = count_words(
                text,
                strip_code=options["strip_code"],
                strip_blockquotes=options["strip_blockquotes"],
            )
        return counts[sha]

    def tags_for(sha: str) -> frozenset[str]:
        if is_null(sha):
            return frozenset()
        measure(sha)
        return tags.get(sha, frozenset())

    def is_source_note(sha: str) -> bool:
        if is_null(sha) or not excluded_fields:
            return False
        measure(sha)
        return front_matter_has_any(fronts.get(sha, ""), excluded_fields)

    days_added: defaultdict[str, int] = defaultdict(int)
    days_net: defaultdict[str, int] = defaultdict(int)
    days_files: defaultdict[str, set[str]] = defaultdict(set)
    seen_paths: set[str] = set()

    commits = commit_list(repo)
    for position, (sha, date) in enumerate(commits):
        is_root = position == 0
        if is_root and initial_mode == "baseline":
            # A snapshot of what already existed. Record the paths so later
            # commits still register as modifications, but count nothing.
            for _, new_sha, _status, _old, path in changed_files(repo, sha, True):
                if not is_null(new_sha):
                    seen_paths.add(path)
            continue

        for old_sha, new_sha, _status, old_path, path in changed_files(repo, sha, is_root):
            if not path.endswith(".md"):
                continue

            def in_scope(candidate: str) -> bool:
                return path_matches(candidate, include) and not path_matches(candidate, exclude)

            if not in_scope(path):
                # Moved out of the counted set, or never in it. Either way this
                # is not a deletion of writing, so it registers as nothing --
                # reorganising must not show up as a day of negative words.
                continue
            if excluded_tags and (tags_for(new_sha) | tags_for(old_sha)) & excluded_tags:
                continue
            if is_source_note(new_sha) or is_source_note(old_sha):
                continue

            # A file moved INTO scope from outside it. Its words were written
            # somewhere the log wasn't watching, so the "before" side has to
            # count as zero -- otherwise the rename nets to nothing and the
            # words are never counted anywhere, silently. This is the path an
            # archival note takes when it is filed from 01 Inbox into a project.
            moved_into_scope = not is_null(old_sha) and not in_scope(old_path)

            is_new_file = (is_null(old_sha) or moved_into_scope) and path not in seen_paths
            # A published draft: the vault already counted these words. Hashed,
            # because the census that supplies the slug list is public.
            if is_new_file and skip_slugs and path_hash(slug_for(path)) in skip_slugs:
                seen_paths.add(path)
                continue

            delta = measure(new_sha) - (0 if moved_into_scope else measure(old_sha))
            seen_paths.add(path)
            if delta == 0:
                continue

            # Where a day's words belong. Normally the commit date -- but git
            # only knows when a file arrived in the repo, which for imported
            # back catalogue is years after it was written. A quote dated
            # 2011-07-28 that git first saw on 2026-06-03 was written in 2011,
            # and charting it as a 2026 writing day is simply wrong.
            #
            # So: when a file is added and its front matter date predates the
            # commit by more than backfill_threshold_days, trust the front
            # matter. The threshold keeps ordinary publishing on the commit
            # date, where a post written this week may carry a date a day or
            # two off; only a real gap reads as import.
            bucket = date
            if backfill and is_new_file:
                declared = front_matter_date(fronts.get(new_sha, ""), date_fields)
                if declared and days_between(declared, date) > backfill_threshold:
                    bucket = declared

            if delta > 0:
                days_added[bucket] += delta
            days_net[bucket] += delta
            days_files[bucket].add(path)

    blobs.close()
    return {
        "added": dict(days_added),
        "net": dict(days_net),
        "files": {day: len(paths) for day, paths in days_files.items()},
    }


def iso_week_key(date: str) -> str:
    year, week, _ = datetime.strptime(date, "%Y-%m-%d").date().isocalendar()
    return f"{year}-W{week:02d}"


def week_start(date: str) -> str:
    day = datetime.strptime(date, "%Y-%m-%d").date()
    return (day.fromordinal(day.toordinal() - day.weekday())).isoformat()


def rollup(days: list[dict], key_fn, label_fn) -> list[dict]:
    """Group daily records into periods, newest first."""
    buckets: dict[str, dict] = {}
    for day in days:
        key = key_fn(day["date"])
        entry = buckets.setdefault(
            key,
            {"key": key, "label": label_fn(day["date"]), "words": 0, "days": 0, "start": day["date"], "end": day["date"]},
        )
        entry["words"] += day["words"]
        entry["days"] += 1
        entry["start"] = min(entry["start"], day["date"])
        entry["end"] = max(entry["end"], day["date"])
    ordered = sorted(buckets.values(), key=lambda item: item["start"], reverse=True)
    for entry in ordered:
        entry["average"] = round(entry["words"] / entry["days"]) if entry["days"] else 0
    return ordered


def longest_streak(dates: list[str]) -> dict:
    """Longest run of consecutive calendar days with writing on them."""
    if not dates:
        return {"length": 0, "start": None, "end": None}
    ordinals = sorted(datetime.strptime(d, "%Y-%m-%d").date().toordinal() for d in dates)
    best_len, best_end = 1, ordinals[0]
    run_len = 1
    for previous, current in zip(ordinals, ordinals[1:]):
        run_len = run_len + 1 if current == previous + 1 else 1
        if run_len > best_len:
            best_len, best_end = run_len, current
    end = datetime.fromordinal(best_end).date()
    start = datetime.fromordinal(best_end - best_len + 1).date()
    return {"length": best_len, "start": start.isoformat(), "end": end.isoformat()}


def resolve_repo(source: dict) -> Path:
    repo = Path(source["repo"]).expanduser()
    if not repo.is_absolute():
        repo = (REPO_ROOT / repo).resolve()
    return repo


def missing_repos(sources: list[dict]) -> list[str]:
    """Configured git sources whose repo is not on this machine.

    Census sources are deliberately not checked. Their input is the committed
    observation files, not the vault, so a machine without the vault -- CI, or a
    laptop with Obsidian not yet installed -- can still rebuild the log
    correctly and completely. Only `observe` needs the vault itself.
    """
    return [
        f"{s['name']} ({resolve_repo(s)})"
        for s in sources
        if s.get("kind", "git") == "git" and not (resolve_repo(s) / ".git").exists()
    ]


def load_config() -> dict:
    return yaml.safe_load(CONFIG_PATH.read_text(encoding="utf-8"))


def census_source(config: dict) -> dict:
    for source in config["sources"]:
        if source.get("kind") == "census":
            return source
    sys.exit("writing-log: no census source configured in writing-log.yaml")


def build() -> dict:
    config = load_config()
    options = {
        "strip_code": config.get("strip_code", True),
        "strip_blockquotes": config.get("strip_blockquotes", True),
    }
    sources = config["sources"]
    observations = load_observations()

    # Drafts are written in the vault and published on the blog. The vault knows
    # the day the words were written, so it wins and the blog skips the commit
    # that first publishes a matching slug.
    skip_slugs = census_draft_slugs(observations)

    per_source: dict[str, dict] = {}
    for source in sources:
        if source.get("kind") == "census":
            per_source[source["name"]] = walk_census(source, observations)
        else:
            per_source[source["name"]] = walk_source(source, options, skip_slugs)

    all_dates = sorted({date for result in per_source.values() for date in result["added"]})
    days = []
    for date in all_dates:
        by_source = {
            name: result["added"].get(date, 0)
            for name, result in per_source.items()
            if result["added"].get(date, 0)
        }
        words = sum(by_source.values())
        if not words:
            continue
        days.append(
            {
                "date": date,
                "words": words,
                "net": sum(result["net"].get(date, 0) for result in per_source.values()),
                "files": sum(result["files"].get(date, 0) for result in per_source.values()),
                "sources": by_source,
            }
        )

    days_desc = list(reversed(days))
    total_words = sum(day["words"] for day in days)
    source_totals = {
        source["name"]: sum(per_source[source["name"]]["added"].values()) for source in sources
    }

    return {
        "generated": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
        "sources": [
            {"name": s["name"], "label": s.get("label", s["name"]), "words": source_totals[s["name"]]}
            for s in sources
        ],
        "totals": {
            "words": total_words,
            "days": len(days),
            "first": days[0]["date"] if days else None,
            "last": days[-1]["date"] if days else None,
            "average": round(total_words / len(days)) if days else 0,
            "best_day": max(days, key=lambda d: d["words"]) if days else None,
            "streak": longest_streak([day["date"] for day in days]),
        },
        "days": days_desc,
        "weeks": rollup(days, week_start, lambda d: f"Week of {datetime.strptime(d, '%Y-%m-%d'):%b %-d, %Y}"),
        "months": rollup(days, lambda d: d[:7], lambda d: f"{datetime.strptime(d, '%Y-%m-%d'):%B %Y}"),
        "years": rollup(days, lambda d: d[:4], lambda d: d[:4]),
    }


def totals_line(data: dict) -> str:
    totals = data["totals"]
    return f"{totals['words']:,} words across {totals['days']:,} days"


def main() -> int:
    args = sys.argv[1:]
    check = "--check" in args
    stats = "--stats" in args
    allow_missing = "--allow-missing" in args

    if args and args[0] == "observe":
        config = load_config()
        options = {
            "strip_code": config.get("strip_code", True),
            "strip_blockquotes": config.get("strip_blockquotes", True),
        }
        source = census_source(config)
        scanned, written = observe(source, options)
        noun = "file" if written == 1 else "files"
        print(
            f"writing-log: observed {scanned:,} in scope on {machine_id()}; "
            f"{written:,} changed {noun}"
        )
        return 0

    if allow_missing:
        config = load_config()
        absent = missing_repos(config["sources"])
        if absent:
            print(f"writing-log: skipped — source repo unavailable: {', '.join(absent)}")
            # Exit 3, distinct from a real failure, so preflight can treat "not
            # on this machine" as a skip and keep the committed JSON as-is.
            return 3

    data = build()
    # `generated` changes every run; excluding it from the comparison keeps
    # --check honest about whether the *counts* moved.
    rendered = json.dumps(data, indent=2, ensure_ascii=False) + "\n"

    if check:
        if not OUTPUT_PATH.exists():
            print("writing-log: data/writing-log.json is missing", file=sys.stderr)
            return 1
        current = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        fresh = dict(data)
        current.pop("generated", None)
        fresh.pop("generated", None)
        if current != fresh:
            print("writing-log: data/writing-log.json is stale — run scripts/writing-log.py", file=sys.stderr)
            return 1
        print("writing-log: up to date")
        return 0

    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    # Leave the file alone when only `generated` would move.
    #
    # That timestamp changes on every run, so a naive write makes the file
    # always-dirty: preflight regenerates on each push, and the nightly sync job
    # would commit a timestamp-only change every night forever, burying real
    # writing days in noise. Compare on the counts instead, which is the same
    # thing --check does.
    unchanged = False
    if OUTPUT_PATH.exists():
        try:
            existing = json.loads(OUTPUT_PATH.read_text(encoding="utf-8"))
        except json.JSONDecodeError:
            existing = None
        if existing is not None:
            before = dict(existing)
            after = dict(data)
            before.pop("generated", None)
            after.pop("generated", None)
            unchanged = before == after

    if unchanged:
        print(f"writing-log: unchanged ({totals_line(data)})")
    else:
        OUTPUT_PATH.write_text(rendered, encoding="utf-8")
        print(f"writing-log: {totals_line(data)} -> {OUTPUT_PATH.relative_to(REPO_ROOT)}")

    if stats:
        totals = data["totals"]
        for source in data["sources"]:
            print(f"  {source['label']:<8} {source['words']:>9,}")
        print(f"  first    {totals['first']}   last {totals['last']}")
        print(f"  average  {totals['average']:,} words per writing day")
        if totals["best_day"]:
            print(f"  best     {totals['best_day']['words']:,} on {totals['best_day']['date']}")
        streak = totals["streak"]
        print(f"  streak   {streak['length']} days ({streak['start']} to {streak['end']})")
        print("  recent months:")
        for month in data["months"][:6]:
            print(f"    {month['label']:<16} {month['words']:>8,}  ({month['days']} days)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
