# Sources and the Reading Ledger

A source is one work — a book, an article, anything cited. Each one is a page:

```
content/sources/<key>/_index.md
```

The folder name is the key posts reference, so it is a citation-style
`lastname` + `year` — `egan2023`, `mckenziejones2015` — not a title slug.

That year is the **work's first publication**, while `published_year` in the
front matter is the **edition you read**. They usually match; for a reprint they
don't, and conflating them is how you end up with `tolkien2012` for a book from
1937. An ISBN identifies an edition, so `newsource.sh` looks the work up
separately and says so when the two years differ. It is
short enough to type from memory and does not go stale when a subtitle changes.
Any name works as long as it urlizes to itself: lowercase, no spaces, no
underscores. A mismatch does not error: Hugo invents the term, publishing a
phantom source page at `/sources/<typo>/` with no title, author or year,
captioned "Book" because that is the template default — and listing it in the
bibliography — while the post's real connection to the work it meant to cite
silently does not exist. Nothing in the build notices, because the page renders
and every link to it resolves. `scripts/checks/connection-lint.py` is what
catches it, and suggests the near-miss key it probably meant.

When two works by one author share a year, the key collides. The source that
already exists keeps the bare key — its `/sources/<key>/` URL is published and
renaming it would break that — and the new one takes a letter suffix:

```
egan2023      the first one recorded
egan2023a     a second Egan title from 2023
```

`newsource.sh` proposes the next free suffix rather than leaving the convention
to be improvised, and still refuses to write over an existing folder if you type
a taken key at the prompt. This is rare at fifty sources and ordinary at five
hundred, which is the reason the convention is written down now.

That page is the single record for the work. It publishes at `/sources/<key>/`
and automatically collects every post that names it. There is no separate data
file and no key registry.

Whether it also appears on `/reading/` depends on one field:

- **with `status`** — a reading event. It joins the ledger, grouped by
  `read_year`, and emits started/finished items in the reading feed.
- **without `status`** — a bibliography entry. An archival file, a magazine run,
  a work cited but never read cover to cover. It still gets its own page, its
  own backlinks, and its own `tags`/`eras`; it simply is not a reading event.

That split is what lets the bibliography grow past the ledger without turning
the reading log into a card catalogue. Promote a bibliography entry to the
ledger at any time by adding `status:` and `read_year:`. Sources without a
status are reached from the writing that cites them — `/reading/` does not list
them, so their page omits the "All sources" link back to it.

## Finding a Work Elsewhere

`layouts/_partials/source_catalogues.html` emits the Open Library and WorldCat
links, shared by the ledger row and the source page so the two cannot drift.

The rule it follows: **link to a query, not to a record, unless the identifier
is one the service itself issued.** An ISBN identifies an edition in the world;
it is not a promise that a given catalogue holds a page for it.
`openlibrary.org/isbn/<isbn>` was exactly that kind of promise and it broke on 4
of 45 books — not because the ISBNs were wrong but because Open Library had not
catalogued those printings. Readers hit a 404 and the scheduled `lychee` run
failed, because `404` is not in `lychee.toml`'s accept list.

A search URL cannot 404: the service always has a results page, even an empty
one. So:

| Source | Open Library | WorldCat |
|---|---|---|
| has an ISBN | `search?q=<isbn>` | `isbn/<isbn>` |
| no ISBN (books only) | `search?q=<title author>` | `search?q=<title author>` |

WorldCat keeps its direct `/isbn/` form deliberately: it answers 200 with a "no
results" page rather than 404ing, so it was never the durability problem, and
the direct link is the better destination. Only `type: book` gets these — a
library catalogue search does not help with an archival file or a journal
article, and those carry `access_url` or a DOI instead. Falling back to a title
query is why 12 sources that previously offered no way off this site now do.

Two things to know about the tradeoff:

- **The link checker can no longer tell you a book is unfindable.** Reliability
  by construction means `lychee` will see 200 whether or not the search returns
  anything. If that signal is wanted back, it belongs in an advisory check
  against Open Library's `search.json` API — reporting coverage, not failing a
  build — rather than in a user-facing link that 404s.
- **Open Library rate-limits.** Roughly a hundred requests in a few minutes is
  enough to earn a `429` and then a temporary block. The scheduled `lychee` run
  checks ~57 of these at `max_concurrency = 8`, so it may well be throttled;
  `429` is already in the accept list, so that cannot fail the build.

## Ledger Pages

`/reading/` renders what is current: books in progress and the present year in
full. Every earlier year lives at `/reading/<year>/`, plus `/reading/undated/`
for logged sources that never got a `read_year`.

Those pages are generated by `content/reading/_content.gotmpl`, a content
adapter — no year page is ever created or maintained by hand, and a new one
appears on 1 January when `now.Year` moves on. The adapter reads each source's
`_index.md` off disk rather than through `site.GetPage`, because an adapter runs
before the site is initialized and the page collection does not exist yet.

The split exists for size. Every ledger row carries a collapsed panel repeating
its whole source page, so 69% of the old single page sat inside `<details>`
elements most readers never opened, at roughly 1.68 KiB per entry. That put it
on course to fail `page-size-lint.py` at about 96 sources. Splitting by year is
bounded rather than merely delayed: the index no longer grows with the library
at all (measured flat at ~29 KiB from 50 sources to 3,000), and a year page is
bounded by how much you read in a year rather than by how much you have read.

The new limit is roughly **55 books logged in a single year** for a soft warning
and **75 for a hard failure** — year pages take the lint's default 96/128 KiB
ceilings, not the relaxed 128/160 KiB granted to `reading/index.html`. The
busiest year on record is 10. If that ever changes, the fix is to add
`reading/<year>/index.html` to `OVERRIDES` in the lint, on the same reasoning
that granted the index its allowance: this content is intentionally dense.

## The Bibliography Index

`/sources/` lists every source, ledger and non-ledger alike; `/reading/` lists
only what was read. The taxonomy's own list page was suppressed for as long as
those were the same set, since two indexes of the same books would merely have
competed. The `status` split ended that, and the works consulted for a post but
never read through — 15 of 65 — had no index at all until this page existed.

Entries sort by source key rather than by title. A key is `lastname` + year, so
sorting on it gives author-surname order for free; `author` is free text holding
things like "Paul Chaat Smith and Robert Allen Warrior" and cannot be sorted on
without parsing names.

Each row carries the work's subjects, linked to their hubs. A source with none
shows a derived, unlinked "Uncategorized" — derived because writing that into
front matter would publish a `/tags/uncategorized/` hub answering nothing, put a
meaningless word in the Topics row of every such source page, and, being a
negation kept as data, have to be remembered and removed the day a real subject
is added. `where $sources "Params.tags" nil` cannot fall out of step. It is
deliberately not a link: real subjects go somewhere, this one has nowhere to go.

The markup is otherwise deliberately lean — no collapsed panels, no catalogue
links, no notes — because repeating each source page inline is exactly what put
`/reading/` on course to fail the page-size lint. Measured against synthetic
libraries carrying representative subject counts, a row here costs **444 bytes**
and the page grows dead linear:

| Sources | `/sources/index.html` |
|---|---|
| 65 (today) | 31.0 KiB |
| 200 | 89.6 KiB |
| 300 | 132.9 KiB |
| 400 | 176.3 KiB |

That crosses the lint's 96 KiB soft warning at roughly **215 sources** and its
128 KiB hard failure at **289**. Displaying subjects is what costs it: the row
was 321 bytes and the ceiling 294/396 before, since each tag link carries a full
href. Worth it for a bibliography that shows what its works are about, and it
means a future filter can read the subjects already in the markup rather than
adding a parallel set of data attributes. Unlike the ledger, this page is not bounded —
it grows with the library by design, because a bibliography that hides entries
behind pagination is worse at the one thing it exists to do. The ceiling is
distant enough to be worth accepting: the ledger has grown 7–10 a year, and the
soft warning arrives with about a hundred sources of headroom before anything
breaks. If it ever fires, `.Paginate` on the term list is the escape hatch, and
the honest alternative is that this page is doing a job better done by search.
Filtering and search are deferred deliberately, with the trigger and the design
decisions recorded under "Known growth limits" in
[operations.md](operations.md) — including why subject facets are the wrong
thing to lead with and why they would lower the ceiling above.

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

`type` is one of `book`, `article`, `archive`, `thesis`, or `dissertation`, and
defaults to `book`. It sets the kicker above the title and decides whether the
source is offered the catalogue links below — only `book` is, because a library
search does not help with a journal article, an archival file, or unpublished
degree work. Nothing else in the templates enumerates the values, so a new kind
of source costs one word here and one in `newsource.sh`'s accepted list.

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

Item guids are `urn:reading-event:<type>:<key>:<event>`, where `<key>` is a
sanitized `isbn`/`doi`/`access_url` — the work's own identifier, not the
source's folder name. Renaming a folder no longer changes it, so it survives
a rename for any source that has one of those three fields (nearly all of
them; `newsource.sh` records an ISBN for most books automatically). Only a
source with none of the three falls back to the folder slug, in which case a
rename still rewrites its guids and Micro.blog will re-import any event still
inside the feed window — that is the real cost of renaming a key
after it has been published, now scoped to that small remainder instead of
every source. (This replaced a slug-only guid in 2026-07 after renames had
produced ~45 groups of duplicate imported posts on eberle.blog.)

### The ISBN has to be one Micro.blog can resolve

Because a book event's title links to `https://micro.blog/books/<isbn>`,
Micro.blog builds the book record behind eberle.blog's `/reading/` page and its
reading goals from that ISBN. An ISBN it cannot resolve produces a placeholder
cover over there and no signal at all here — nothing on this site looks wrong.

The two ledgers do **not** have to agree on the ISBN. Micro.blog creates its
record from whatever this feed publishes, so this repo stays the source of
truth. Duplicate book records only appear when the same work is *also* added by
hand in Epilogue under a different edition's ISBN; leaving RSS-imported books
off the Finished Reading shelf avoids that entirely.

What does have to hold is that the ISBN resolves to real cover art, and that is
checkable from here without visiting Micro.blog:

```sh
python3 scripts/checks/book-cover-lint.py content
```

`https://cdn.micro.blog/books/<isbn>/cover.jpg` answers unauthenticated, in
three shapes: an ~81-byte stub (unknown ISBN), a 6287-byte placeholder image
(known ISBN, no cover art), or the cover itself. `newsource.sh` runs the same
check the moment an ISBN is typed and offers to take another edition's; the lint
sweeps the whole ledger, caching successes in `scripts/checks/book-covers.json`
so repeat runs only probe what is new or still failing.

This is cover availability, not correctness — the catalogue returns *some* image
for a well-formed but wrong number, so a pass means "this will look right", not
"this is the edition you read". It is also the only check here that needs the
network, which is why it stays out of `preflight.sh`.

### Published links are immutable

**Micro.blog decides whether a feed item is new by its `<link>`, not its
`<guid>`.** The 2026-07 guid fix above was necessary but not sufficient: a
stable guid does not stop a duplicate if the link moves. Established twice —
once when a started and a finished event sharing one link caused the second to
be silently dropped, and again in 2026-08 when 15 duplicate posts turned out to
carry three different Micro.blog slug generations for the same book, one per
historical URL scheme.

Two consequences worth internalising:

1. **Once an item has gone out in the feed, its `<link>` can never change.**
   Change it and every affected item still inside the window is imported again
   as a brand-new post. A folder rename, a permalink restructure, or adding or
   removing a `#started` / `#finished` suffix all count.
2. **Deleting an imported post does not stick while its item is still in the
   feed.** Micro.blog re-creates any item it cannot find a post for, so a
   deletion only holds once the item has aged out of the window. Ask before
   cleaning up duplicates:

   ```sh
   python3 scripts/reading-window.py
   ```

   It reads the **live** feed — what Micro.blog can actually see, which a local
   build may be ahead of — and lists every event currently inside the window.
   Anything listed will come back if you delete its post; anything absent is
   safe to delete. This is the check that was missing during the 2026-08
   cleanup, where 15 deletions held only because those events happened to have
   aged out already.

`scripts/checks/feed-lint.py` enforces the first point.
`scripts/checks/reading-feed-links.json` records the link each event has been
published with; the lint fails when one changes, naming each affected event and
stating how many duplicate posts the change would create. It records links only
as they appear in the built feed — an event that has never been inside the
window has never been offered to Micro.blog, so its link carries no history to
protect — and never prunes, so an event that ages out and later returns is
still checked against what it was first published with.

It also catches **guid churn**, which is why the guid alone cannot carry this
record. A guid is derived from the work's `isbn`/`doi`/`access_url`, so
correcting an ISBN gives the same event a new one. The link does not move, so no
duplicate is created — but the recorded entry orphans under the old guid and the
new guid matches nothing, silently leaving that event unprotected against a
*later* link change. The lint matches on the link to spot this and asks for a
re-record, which restores the guard. Three ISBN corrections on 2026-08-06 put us
one step into exactly that sequence.

If a link change is deliberate and the duplicates are acceptable:

```sh
hugo --gc --minify
python3 scripts/checks/feed-lint.py public --update   # re-record
git add scripts/checks/reading-feed-links.json
```

The window size (`services.rss.limit` in `hugo.yaml`, currently 10) is the blast
radius for all of this — see the comment there before changing it, since it is
also the delivery slack and the ceiling on a one-time backfill.

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
scripts/newsource.sh zotero cramer2005          # import from the Zotero library
scripts/newsource.sh zotero "cramer colonialism" # search when the key is unknown
```

### From Zotero

The scholarly half of the library already lives in Zotero, and its records were
curated when the work was read rather than reconstructed from a catalogue
afterwards. The import reads the CSL-JSON export — `WEBSITE_BIBLIOGRAPHY`,
default `~/Documents/Library/Library.json`, the same file `cite-refs.sh` uses —
and prefills title, author, publisher, year, ISBN, DOI, access URL, and type.
It is offline and needs no network.

It also supplies the one field no catalogue lookup can: `citation-key`, which
becomes the source folder name, so importing a work and naming its page are a
single act. Give it an unknown key and it searches author, title, year and key,
then asks which one you meant.

Three things it does deliberately:

- **Takes only the first ISBN.** Zotero packs every ISBN an edition ever had
  into one space-separated field — 39 of 94 entries here do. The templates strip
  non-alphanumerics to build catalogue links, so passing the field through whole
  would fuse two ISBNs into a bogus 26-digit number and produce dead links.
- **Converts the title to title case.** Zotero stores sentence case; every
  source page here is title case. The conversion only ever raises a word's first
  letter, so a token already carrying a capital — `Pequots`, `U.S.`,
  `McKenzie-Jones` — passes through untouched.
- **Defaults `status` to `none`.** The usual reason to import from Zotero is a
  work cited in a footnote years ago, which is a bibliography entry, not a
  reading event. Answer `read` and it joins the ledger like anything else.

Three type mappings are less obvious than the rest:

- **Degree level comes from `genre`, not the CSL type.** CSL has a single
  `thesis` type for work at every level, and Zotero keeps the level in the
  item's own Type field, exported as `genre`. A doctoral dissertation is not a
  master's thesis, and the kicker is the only place the page says which it is,
  so a `genre` matching dissertation/doctoral/PhD yields `dissertation` and
  everything else stays `thesis` — which absorbs the several master's spellings
  in the library (`M.S.`, `Master's Thesis`) without enumerating them.
- **Some records aren't typed `thesis` at all.** Older and imported ones land on
  the generic `document` and carry the kind in `genre` alone, where trusting the
  CSL type would label a dissertation "Archive".
- **Neither has a publisher.** Zotero files the granting institution under
  `publisher-place`, read only for those two types, since for anything else that
  field is a city and would put Boston where the press belongs.

Zotero is a prefill, never a requirement: 23 of 59 sources are in it, and the
casual reading is not and should not be. That is the whole point of the sources
taxonomy replacing the old cite-key ledger — a book read on holiday still costs
one file, with no round trip through Zotero.

An auto-generated key (`zotero-item-602`) is worth fixing in Zotero before
importing rather than publishing as a permanent URL.

The script prompts for an ISBN first and prefills title, author, publisher, and
year from Open Library; articles prompt for a DOI and prefill from Crossref. A
second Open Library call resolves the work's first publication year, so the
proposed key cites the work even when the ISBN describes a later printing. Every
value, the key included, is an editable default.
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
