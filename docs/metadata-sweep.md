# Metadata Sweep — 2026-07-31

A record of every metadata change made when the site's front matter was
restructured around a subject/period split and a source spine that articles
could actually attach to. Nothing in the writing itself was edited; this was
front matter, templates, and lints only.

Before the sweep, the graph had two halves that did not touch. All 6 reviews and
all 5 quotes named a source; **none of the 19 articles did**, and **none of the
50 source pages carried a subject term**. So the site could answer "what did I
write about this book" and "what did I read in 2015" but not "what do I have on
the American Indian Movement" — the question a knowledge base exists to answer.

## The schema

| Field | Where | Meaning |
|---|---|---|
| `tags` | posts and sources | Subject. What the piece or work is *about*. |
| `eras` | posts and sources | Period. What span it *concerns* — not when it was published. |
| `sources` | posts | Every work the piece draws on. Creates the taxonomy link both ways. |
| `about` | posts | Which of those sources the piece is *centrally* about. Optional. |
| `status` | sources | Presence puts the work in the `/reading/` ledger. Absence makes it a bibliography entry. |

Two rules follow from that, and both are enforced by
`scripts/checks/connection-lint.py`:

- every post carries at least one `sources:` or one `tags:` entry
- every `about:` key also appears in that page's `sources:`

`scripts/checks/taxonomy-facet-lint.py` separately keeps period values out of
`tags`.

### Why `about` exists

A flat `sources:` list cannot tell a review of a book from an essay that cites
it once. Without that distinction, attaching citations to articles would have
flooded every cited work's page with backlinks claiming it had been written
about — which is the actual reason articles carried no sources at all. A source
page now separates **Writing about this source** from **Cited in**.

A review or quote with one source and no `about:` is taken to be about it. An
article gets no such inference: citing a single book is the normal case there.

### Why `status` gates the ledger

`content/sources/` was the reading log, so a 1972 magazine article or an FOIA
release had nowhere to live. Now a source without `status` still gets its page,
its backlinks, and its subject terms — it simply is not a reading event. Nine
sources are currently bibliography-only. Any of them can be promoted to the
ledger later by adding `status:` and `read_year:`.

## Vocabulary

20 subject tags and 9 periods, with sources counted alongside writing:

| Tag | Posts | Sources | | Tag | Posts | Sources |
|---|--:|--:|---|---|--:|--:|
| Native American History | 10 | 16 | | Media | 1 | 2 |
| American Indian Movement | 6 | 4 | | Labor | 1 | 2 |
| Oklahoma | 4 | 9 | | Right-Wing Movements | 2 | 3 |
| Music | 4 | 3 | | Journalism | 2 | 2 |
| Historiography | 4 | 3 | | Digital Humanities | 1 | 1 |
| Folklore | 3 | 3 | | Drinking | 1 | 1 |
| Federal Law Enforcement | 3 | 3 | | Fiction | 0 | 4 |
| Rodeo | 3 | 1 | | Sports | 0 | 3 |
| Environment | 1 | 8 | | Travel | 0 | 3 |
| Tribal Recognition | 2 | 3 | | AI | 1 | 0 |

Periods: `1910s` (1), `1920s` (3), `1930s` (4), `1960s` (5), `1970s` (16),
`1990s` (6), `17th Century` (3), `19th Century` (15), `20th Century` (4).

New terms introduced: Native American History, Environment, Labor,
Right-Wing Movements, Sports, Fiction, Media, Travel, Digital Humanities, and
the periods 1910s, 1920s, 20th Century.

## New source pages (9)

All created without `status`, so none appears in the reading ledger. ISBNs were
not guessed. `scheips2005` and `smith1996` were later backfilled from Zotero and
now link to catalogues by ISBN; the rest are not in Zotero and fall back to a
title-and-author query, which works — an ISBN only sharpens it.

Eight were built from complete Chicago footnotes already in the citing
articles — author, title, publisher and year all present in the text, nothing
supplied from outside it.

| Key | Work | From |
|---|---|---|
| `banks2004` | Dennis Banks and Richard Erdoes, *Ojibwa Warrior* (University of Oklahoma Press, 2004) | thanksgiving-1970 |
| `scheips2005` | Paul J. Scheips, *The Role of Federal Military Forces in Domestic Disorders, 1945-1992* (Center of Military History, 2005) | on-abourerzks-ak-47s-at-wounded-knee |
| `miller2004` | Mark Edwin Miller, *Forgotten Tribes* (University of Nebraska Press, 2004) | bia-recognition-changes-in-connecticut |
| `lowery2010` | Malinda Lowery, *Lumbee Indians in the Jim Crow South* (University of North Carolina Press, 2010) | bia-recognition-changes-in-connecticut |
| `smith1996` | Paul Chaat Smith and Robert Allen Warrior, *Like a Hurricane* (The New Press, 1996) | whered-the-death-come-from |
| `white2017` | Richard White, *The Republic For Which It Stands* (Oxford University Press, 2017) | mary-lease-suffrage-and-prohibition |
| `postel2007` | Charles Postel, *The Populist Vision* (Oxford University Press, 2007) | mary-lease-suffrage-and-prohibition |
| `clanton1969` | Gene Clanton, *Kansas Populism: Ideas and Men* (University of Kansas Press, 1969) | mary-lease-suffrage-and-prohibition |

The ninth, `fbi1973banks`, is the Dennis Banks FBI file — an archival source
(`type: archive`) described from the article that hosts the scanned PDFs.

## Needs your review

1. ~~**`smith1996` author.**~~ **Resolved 2026-07-31.** The footnote's "Pat Chaat
   Smith" was a typo; both it and the source page now read Paul Chaat Smith.
2. ~~**`smith1996` subtitle.**~~ **Resolved 2026-07-31.** The published subtitle
   is *The Indian Movement from Alcatraz to Wounded Knee*, confirmed against the
   Zotero record (sourced from WorldCat, OCLC 33897927). The footnote was
   corrected first; the source page had kept the sweep's *Native Rights
   Movement* reading and now matches.
3. ~~**Works cited but not created.**~~ **Resolved 2026-07-31.** Citations were
   added to Zotero and imported with `newsource.sh zotero`: `cramer2005`,
   `cattelino2008`, `fromson2004`, `eisler2002`, `orr2006`. All five are
   bibliography entries (no `status`), wired into
   `bia-recognition-changes-in-connecticut`, `mary-lease-suffrage-and-prohibition`,
   and `bob-engelharts-golden-hill-paugussett-cartoon` — the last of which now
   carries `about: ["cramer2005"]`, since the post exists to chase down a
   cartoon Cramer mentions in a footnote. The sixth, MaryJo Wagner's 1986
   dissertation, followed on the same day as `wagner1986` once it had a Zotero
   record, and is cited from `mary-lease-suffrage-and-prohibition`.
4. **Subject terms on unread books.** Assignments for the 45 existing sources
   were inferred from title, author and publisher. They are conservative, but
   you have read these books and I have not. `Environment` (8 sources, 1 post)
   and `Fiction`/`Sports`/`Travel` (no posts at all) are the ones most worth a
   glance.
5. ~~**`about:` is used on exactly one post.**~~ **Resolved 2026-07-31.** Now
   three: `dennis-banks-fbi-file`, `bob-engelharts-golden-hill-paugussett-cartoon`,
   and `bia-recognition-changes-in-connecticut`, where `about: ["miller2004"]`
   was confirmed. Everything else remains a citation, which is the expected
   ratio — most posts cite without being about.
6. ~~**Nine bibliography sources have no index page.**~~ **Resolved 2026-07-31.**
   `/sources/` is un-suppressed and renders a full bibliography — all 65 works,
   sorted by key so they fall in author order, with the 15 non-ledger ones no
   longer reachable only from the writing that cites them. Sources now link back
   to whichever index lists them. Measured ceiling and the reasoning for leaving
   the page unbounded are in [reading.md](reading.md).

## Deliberately left alone

Seven sources carry no subject tag: `bacon2025`, `elmhirst2025`, `grann2018`,
`healey2025`, `jacobsen2024`, `raddenkeefe2026`, `roosevelt1928` — plus the
quote `let-them-have-cake`. Nothing in the vocabulary fits them, and inventing a
single-member tag per book is vocabulary sprawl, not a hub. `healey2025` and
`roosevelt1928` still carry periods.

They show as "Uncategorized" on `/sources/`, derived from the absence of `tags`
rather than stored, so the label disappears the moment a real subject is added
and can never contradict the front matter. See [reading.md](reading.md).

Added 2026-07-31: **`Populism`**, covering `clanton1969`, `postel2007`,
`wagner1986` and `white2017` plus `mary-lease-suffrage-and-prohibition`. The
first three arrived untagged with the Zotero import; they were never a judgment
call, only a backlog. The post was tagged at the same time so the hub connects
writing to works rather than being another subject with sources and no writing.

## Per-file changes

### Source pages — subject and period added

| Source | tags | eras |
|---|---|---|
| `andrews2008` | Environment, Labor | 1910s |
| `binelli2012` | Travel | — |
| `blackhawk2008` | Native American History | 19th Century |
| `carpio2011` | Native American History | 20th Century |
| `clegg2018` | Sports | 1990s |
| `coates2016` | Travel | — |
| `coates2024` | Journalism | — |
| `cobb2020` | Oklahoma | — |
| `cobb2024` | Native American History, Oklahoma | 1920s |
| `dickey2016` | Folklore | — |
| `dylan2004` | Music | 1960s |
| `egan2006` | Environment | 1930s |
| `egan2023` | Right-Wing Movements | 1920s |
| `everett2024` | Fiction | 19th Century |
| `fixico2025` | Native American History, Oklahoma | 19th Century |
| `gardiner2015` | Digital Humanities, Historiography | — |
| `grann2017` | Native American History, Oklahoma | 1920s |
| `hamalainen2023` | Native American History, Historiography | — |
| `healey2025` | — | 17th Century |
| `iverson1994` | Native American History, Rodeo | 20th Century |
| `jacoby2005` | Environment | 19th Century |
| `jennings2026` | Right-Wing Movements, Federal Law Enforcement | 1990s |
| `johnson2011` | Fiction | — |
| `jones2019` | Sports | — |
| `kerr2002` | Travel | — |
| `king2011` | Fiction | 1960s |
| `klosterman2022` | Media | 1990s |
| `kurlansky1999` | Environment | — |
| `mckenziejones2015` | Native American History, American Indian Movement, Oklahoma | 1960s |
| `mcphee1971` | Environment | 1970s |
| `mcphee1975` | Environment | — |
| `miller2024` | Native American History, Music, Oklahoma | 1970s |
| `nagle2024` | Native American History, Tribal Recognition, Oklahoma | — |
| `nussbaum2024` | Media | — |
| `proulx2023` | Environment | — |
| `puhak2026` | Folklore, Drinking | 17th Century |
| `roberts2021` | Native American History, Oklahoma | 19th Century |
| `roosevelt1928` | — | 19th Century |
| `stetson1896` | Folklore | 19th Century |
| `tolkien1937` | Fiction | — |
| `weigel2017` | Music | 1970s |
| `weisiger2009` | Native American History, Environment | 1930s |
| `winner2005` | Sports | — |
| `wyman2010` | Labor | — |
| `zengerle2026` | Right-Wing Movements, Journalism | 1990s |

### Articles

| Article | Added |
|---|---|
| `early-70s-airport-security` | tags: Federal Law Enforcement **(was an orphan)** |
| `saturday-night-in-a-saloon…` | tags: Media **(was an orphan)** |
| `thanksgiving-1970` | sources: banks2004; tags: Native American History |
| `on-abourerzks-ak-47s-at-wounded-knee` | sources: scheips2005; tags: Native American History |
| `bia-recognition-changes-in-connecticut` | sources: miller2004, lowery2010; tags: Native American History |
| `always-take-first-hand-accounts…` | tags: Native American History |
| `bob-engelharts-golden-hill-paugussett-cartoon` | tags: Native American History |
| `whered-the-death-come-from` | sources: smith1996; tags: Native American History |
| `peter-lafarge-the-singing-protest-cowboy` | tags: Native American History |
| `past-and-future-of-indian-rodeo-in-las-vegas` | tags: Native American History |
| `from-the-archives-indian-prison-rodeo` | tags: Native American History |
| `from-the-archives-the-vanishing-americans` | tags: Native American History |
| `dennis-banks-fbi-file` | sources: fbi1973banks; about: fbi1973banks |
| `mary-lease-suffrage-and-prohibition` | sources: white2017, postel2007, clanton1969; tags: Historiography **(was an orphan)** |

Unchanged: `the-ghosts-of-louisianas-johnson-gosset-plantation`, `tulsa-in-1918`,
`i-got-sick-of-watching-the-tulsa-world-die`,
`the-unified-theory-of-bruce-springsteen-the-character`,
`my-summer-with-claude-pt-1-maintenance`.

### Reviews and quotes

| Page | Added |
|---|---|
| `warrior-mckenzie-jones` | tags: Native American History |
| `blurring-the-lines-indians-cowboys-and-ranching…` | tags: Native American History, Rodeo (had none) |
| `gardner-musto-digital-humanities` | tags: Digital Humanities |
| `jennings-ruby-ridge` | tags: Right-Wing Movements |
| `zengerle-tucker-carlson` | tags: Right-Wing Movements |
| `even-the-entertainment-was-traumatic` | tags: Environment |
| `hoboes-tramps-and-bums` | tags: Labor (had none) |
| `a-sober-aristocrat` | tags: Folklore |

Unchanged: `weigel-show-that-never-ends`, `let-them-have-cake`,
`at-least-its-only-a-belief-in-vampirism`.

## Template changes this required

- `layouts/reading.html` — the ledger now lists only sources with a `status`.
- `layouts/_partials/source_page.html` — backlinks split into "Writing about
  this source" and "Cited in"; the "All sources" link is shown only for ledger
  sources, since `/reading/` does not list the others.
- `layouts/_partials/related_posts.html` — a post's sources are ordered with its
  `about:` works first.
- `layouts/term.html` — a subject or period page now lists the works carrying
  that term, not just the writing.

That last one has a Hugo wrinkle worth knowing. A source is itself a taxonomy
term, and while `.GetTerms "tags"` on a source resolves its subjects correctly,
the reverse index on a `tags` term page lists only `kind=page` members — a
term-kind source silently never appeared. The template therefore queries the
sources section and filters on the facet param rather than reading the term's
own `.Pages`.

## Verification

`scripts/preflight.sh` passes clean: 237 pages built with no Hugo warnings,
both new lints green, feeds valid, every internal reference resolving, and
`/reading/` unchanged at 84.3 KiB against its 128 KiB soft ceiling.
