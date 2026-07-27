# Sources and the Reading Ledger

A source is one work — a book, an article, anything cited. Each one is a page:

```
content/sources/<key>/_index.md
```

The folder name is the key posts reference, so it is a citation-style
`lastname` + `year` — `egan2023`, `mckenziejones2015` — not a title slug. It is
short enough to type from memory and does not go stale when a subtitle changes.
Any name works as long as it urlizes to itself: lowercase, no spaces, no
underscores. A mismatch does not error, it silently creates a second empty
source, so `preflight.sh` is what catches a typo.

That page is the single record for the work. It publishes at `/sources/<key>/`,
it is listed on `/reading/`, and it automatically collects every post that names
it. There is no separate data file and no key registry.

```yaml
---
title: "Clyde Warrior: Tradition, Community, and Red Power"
author: "Paul McKenzie-Jones"
type: "book"              # optional; defaults to book
status: "read"            # or "reading"
published_year: 2015
read_year: 2015
publisher: "University of Oklahoma Press"
format: "Hardcover"
isbn: "9780806147055"
finished: "2015-07-14"
access_url: "https://example.org/full-text"
---

Anything below the front matter is shown on the source page as notes.
```

`access_url` is spelled that way because `url` is reserved by Hugo — setting it
would move the page.

## Connecting Writing to a Source

Add the key to any article, review, or quote:

```yaml
sources: ["mckenziejones2015"]
```

That is the whole mechanism. Hugo's taxonomy index does the rest:

- the post shows the work's citation, linked to the source page
- the source page lists the post under "Writing about this source"
- other posts on the same work appear under "Elsewhere on this source"

A post can list several sources. A source with nothing written about it still
gets a page and still appears in the ledger — that is the normal case for most
of the ledger.

If a connection isn't appearing, the post is missing its `sources:` entry. There
is deliberately no fuzzy title matching to fall back on.

## Status and Dates

- `status: reading` puts the source in "Currently reading" on `/reading/`
- `status: read` files it under `read_year`; a source with no `read_year` lands
  in the "Undated" group
- `started` and `finished` are the actual reading dates
- `started_announced` / `finished_announced` are optional feed timestamps, used
  when an event is announced later than it happened; the feed falls back to the
  reading date

That separation exists so Micro.blog treats a newly added reading event as new,
rather than as an old midnight post. Older records without announcement
timestamps stay quiet unless you edit them, which avoids waking up the archive
in downstream syndication.

## The Reading Feed

`/reading/index.xml` emits one item per started/finished event:

- book titles link to `https://micro.blog/books/<isbn>` when an ISBN is present
- otherwise the title links to `access_url`, then a DOI, if either is set
- an item's `<link>` is the source's own page

Its `started-reading` / `finished-reading` categories and the literal
"Started reading: " / "Finished reading: " description prefixes are a cross-repo
contract: `~/git/micro-theme` matches them to build eberle.blog's reading
sections. `scripts/checks/feed-lint.py` asserts this, so the build catches a
rendering change that would otherwise silently empty that homepage section.

Item guids are `urn:reading-event:<type>:<key>:<event>`. They are stable only
as long as the source's folder name is: renaming a source rewrites its guids,
and Micro.blog re-imports any event still inside the 20-item feed window. That
is the real cost of renaming a key after it has been published.

## Cite Keys

There is no `cite_key` field: the folder name is the citation key, so the fact is
recorded once. Where a source came from Zotero, its folder keeps the Zotero key
verbatim.

`scripts/cite-refs.sh` still renders a Chicago "Works Cited" list from
pandoc-style `[@key]` citations in a draft body via `publish-draft.sh --cite`.
It reads those keys from the post body and resolves them against the Zotero
library, independently of anything here.

The substantive change from the old model: a source no longer has to exist in
Zotero to be linkable, so connecting a quote to a book you read casually costs
one file instead of a round trip through Zotero and Obsidian.

## Creating a Source

```sh
scripts/newsource.sh book "Book Title"
scripts/newsource.sh article "Article Title"
```

The script prompts for an ISBN first and prefills title, author, publisher, and
year from Open Library; articles prompt for a DOI and prefill from Crossref. It
then proposes the `lastname`+`year` key as an editable default.
Both lookups are best-effort — if the network is down or the record is missing,
it says so and falls through to manual entry with nothing lost. Every prefilled
value is still shown as an editable default.

The front matter above is the whole format, so writing the file by hand is
equally valid when you already have the details.

## Finishing a Source

```sh
scripts/finishsource.sh puhak2026
scripts/finishsource.sh                      # lists what is currently reading
scripts/finishsource.sh --push puhak2026     # then preflight, commit, push
```

It flips `status` to `read`, stamps `finished`, derives `read_year`, and records
`finished_announced` so the feed treats the event as new.
