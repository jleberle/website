# Workflow

## Content Layout

| Directory | Description |
|---|---|
| `content/articles/` | Essays and blog posts |
| `content/reviews/` | Reviews, usually page bundles |
| `content/quotes/` | Quote posts, flat files |
| `content/cv/` | CV page |
| `content/courses/` | Course pages |
| `~/Notes/04 Blog/Drafts/` | Obsidian vault drafts (outside the repo) |

Published posts follow `YYYY-MM-DD-slug/` page-bundle naming for articles and reviews, and dated flat files for quotes. Draft front matter is stamped in the site's local timezone (`America/Chicago`) so feeds sort correctly.

## Draft and Publish Flow

Obsidian drafts live in the main `~/Notes` vault under `04 Blog/Drafts/articles/`,
`04 Blog/Drafts/reviews/`, and `04 Blog/Drafts/quotes/`. Keeping them in the vault
rather than the repo means drafting happens alongside the reading notes, Zotero
citations, and research library, and Obsidian Sync carries them between machines
without unpublished work ever entering Git. Override the location with
`WEBSITE_DRAFTS_DIR` if the vault lives elsewhere.

Use the CLI scaffolder or, in Obsidian, the Templater templates at
`~/Notes/Meta/templates/Website/` (bound to the drafting hotkeys — post/review on
the hyperkey with `P`/`R`, link/quote on `Ctrl+Cmd+L`). Those templates live only
in the vault — this repo has no `.obsidian/` setup and no template copies, so
edit them directly there:

```sh
scripts/newpost.sh article "Post Title"
scripts/newpost.sh review "Review Title"
scripts/newpost.sh quote "Quote Title"
```

When a draft is ready (the path is relative to the drafts root, or an absolute
path):

```sh
scripts/publish-draft.sh articles/2026-06-24-post-title.md
```

That script:
- moves the file into the correct published section
- preserves page bundles for articles and reviews
- leaves quotes as flat files
- flips `draft: true` to `draft: false`
- stamps `publishDate` and `lastmod` when missing

Add `--push` to run `scripts/ship.sh` immediately after publishing — preflight,
commit, and push in one step. Skip it for posts that still need
`scripts/add-images.sh` first (a cover or body images); run `scripts/ship.sh`
manually once those are in place instead:

```sh
scripts/publish-draft.sh --push articles/2026-06-24-post-title.md   # no images
scripts/publish-draft.sh reviews/2026-06-24-review-slug.md          # has a cover
scripts/add-images.sh content/reviews/2026-06-24-review-slug --cover photo.jpg
scripts/ship.sh "Review: ..."
```

## Citations

For scholarly posts, cite works with pandoc-style keys in the draft body —
`[@mckenziejones2015]` inline, or a non-rendering `<!-- cite: @allen2012 @cobb2015 -->`
comment to declare sources without printing a marker. These keys feed the
rendered bibliography only — post-to-source connections are made with the
`sources:` field, not with cite keys (see [reading.md](reading.md)).

Add `--cite` to also append a rendered Chicago "Works Cited" list (articles and
reviews only):

```sh
scripts/publish-draft.sh --cite reviews/2026-06-24-review-slug.md
```

Rendering uses `scripts/cite-refs.sh`, which reads the Zotero-exported CSL-JSON
library and CSL style. Paths default to the local Obsidian/Zotero setup and can be
overridden with `WEBSITE_BIBLIOGRAPHY` and `WEBSITE_CSL`. If pandoc or the
bibliography is unavailable, publishing still succeeds and simply skips the list.

## Metadata Conventions

`description` is the canonical public-facing and SEO blurb. `summary` is only for cases where the list/feed teaser should differ.

For a substantive revision to published writing, add a chronological
`revisions` list. Do not use it for formatting, image conversion, metadata
cleanup, or repaired site plumbing:

```yaml
revisions:
  - date: 2026-06-07
    summary: "Updated an obsolete reference and added present-day context."
```

The latest entry supplies the visible “Originally published / Revised”
provenance line and the modification date in feeds and structured metadata.
Git-derived `lastmod` remains technical build metadata and is not presented as
evidence that the writing itself changed.

When a cover is cropped in a compact presentation, `focalPoint` keeps its
important subject in view. The default is `center`; supported positions are
`top-left`, `top`, `top-right`, `left`, `center`, `right`, `bottom-left`,
`bottom`, and `bottom-right`:

```yaml
cover:
  image: "cover.avif"
  alt: "Portrait of an activist speaking at a podium"
  focalPoint: "top"
```

An unsupported value fails the Hugo build instead of silently producing an
incorrect crop. The setting has no effect where the full image is shown.

Naming the work a post is about — for reviews, quotes, and any article that
discusses a specific source:

```yaml
sources: ["mckenziejones2015"]
external_url: "https://example.org/the-passage"
```

`sources` holds the folder names of pages under `content/sources/`, which are
citation-style keys (`lastname` + `year`); the work's title,
author, publisher, and year live there and are never retyped on the post. See
[reading.md](reading.md) for the source format and what the connection produces.

List every work the piece draws on, then name the one it is centrally about:

```yaml
sources: ["white2017", "postel2007", "clanton1969"]
about: ["postel2007"]
```

`about` must be a subset of `sources` — it labels those links rather than
creating new ones, so a key that appears only in `about` does nothing at all.
`scripts/checks/connection-lint.py` catches that, and three other silent
failures: a post carrying neither a source nor a subject tag, a `sources:` key
with no page under `content/sources/` (Hugo publishes an empty phantom rather
than erroring — see [reading.md](reading.md)), and a source `type` the
templates do not know.

The distinction shows up on the source page, which separates "Writing about this
source" from "Cited in". Without it, an essay citing a book once would be
indistinguishable from a review of it, and attaching citations to articles would
mean flooding every cited work with false claims of being written about. A
review or quote with one source and no `about` is taken to be about it; an
article gets no such inference, because citing one book is normal there.

`external_url` is optional and points at the specific passage or edition being
discussed. It renders as a "Read online" link beside the citation; it does not
turn the post title into an outbound link.

## Tags and Eras

Subject and period are two facets, not one list:

```yaml
tags:
- "American Indian Movement"
- "Rodeo"
eras:
- "1970s"
```

`tags` answers *what is this about*; `eras` answers *what period does it
concern*. They were a single flat vocabulary until 2026-07, when the period
values (`1970s`, `19th Century`, ...) were moved into their own taxonomy —
splitting 22 files then rather than several hundred later, and without which a
subject hub built from a term like `1970s` is really just a date filter.
Note that an era is the period a piece is *about*, not when it was published;
`publishDate` already covers that and the archive already sorts by it.

Write a period as a decade (`1970s`) or a named century (`19th Century`).
`scripts/checks/taxonomy-facet-lint.py` fails the preflight if a period-shaped
value turns up under `tags`, or if an `eras` value is not period-shaped —
guarding both directions, since a subject filed under `eras` builds a
`/eras/<subject>/` hub that answers the wrong question just as surely. Together
they are what keeps the two facets from quietly merging again. A tag that merely
contains a year — `Tulsa in 1918` — is a subject and is left alone.

The period vocabulary is closed by construction, which is why a regex can check
it. The subject vocabulary has no shape to check against, so as of 2026-07-31 it
is closed by list instead: `scripts/checks/tag-vocabulary-lint.py` holds the 22
approved terms and fails the preflight on anything else. Adding a subject is a
two-line commit — the term in the lint, the term in the front matter — which is
the point, since a new hub should be a decision rather than a side effect of
typing `rodeo` for `Rodeo`. The lint also fails when an approved term falls out
of use, so retiring a tag means retiring it from the list in the same commit.

Three rules govern what belongs on that list. A term wants **three or more
members** — below that the hub returns roughly what the page linking to it
already showed. A term must not **restate its neighbours**: `Digital Humanities`
and `Drinking` were retired into `Historiography` and `Folklore` because every
member already carried the broader term. And `Native American History` is the
**field, not a subject** — it runs to about a third of everything tagged, so it
travels with a narrower term wherever one fits. Two sources carry it alone
because nothing narrower exists for them yet, which is the right outcome;
inventing a term to satisfy the rule is the sprawl the rule exists to prevent.

A few terms name a work's **form** rather than its subject — `Fiction`,
`Autobiography` — which the "what is this about" rule does not strictly cover.
They are kept deliberately, and only for the reading log: `/reading/` records
what was read, and "what kind of book was it" is a fair question to ask of a
reading list even though it is not a research subject. Keep the subset small and
obvious. A form term that starts collecting *writing* as well as works has
drifted into being a subject and wants re-examining.

Place terms (`Oklahoma`, `Connecticut`, `Europe`) sit in `tags` rather than a
`places` facet of their own. Regional history is a subject, and three terms is
still thinner than the vocabulary a facet would be carved out of.

`Europe` is coarser than the other two, which is worth watching. Three of its
seven works are English, so an `England` term is the plausible next addition —
and the moment one exists, place inherits exactly the granularity problem
centuries have with decades. Solve it the way `era_rollup.html` does, by
deriving the wider term at render time, rather than by writing both into front
matter. That is also the point at which a `places` facet earns a second look.

Both render on a post, in separate "Topics" and "Period" rows, and both have
term pages (`/tags/<term>/`, `/eras/<term>/`). A post may carry only one facet;
five posts currently carry an era and no subject tag at all.

### Centuries roll up their decades

`eras` mixes two granularities deliberately. A piece focused on one stretch gets
a decade; one that genuinely spans gets the century — Scheips covers 1945-1992,
Iverson runs from open-range ranching to the 1990s, and asking either to name a
decade would invent a scope its author never claimed.

Hugo does not relate the two, so `/eras/20th Century/` once listed only the five
works filed at century granularity while the sixteen `1970s` items sat in a page
that never linked to it. `layouts/_partials/era_rollup.html` closes that: a
century term page lists the century *and* its ten decades, for writing
(`baseof.html`, where the paginator is built) and for works (`term.html`). The
rollup is one-directional — a decade page must never absorb century-tagged
items, since "20th Century" is not evidence about the 1970s specifically.

Nothing is written into front matter to make this work, which is the same choice
`source_index.html` makes when it derives "Uncategorized" from the absence of
`tags`: the redundant term never reaches the file or the rendered "Period" row,
so it cannot drift out of agreement with the term it duplicates.

Cross-linking between pages is handled two ways: automatically by shared terms
(the `Related writing` footer block), and deliberately by research paths. The
`related` config in `hugo.yaml` indexes `tags` at weight 100 and `eras` at 20,
so a shared subject always outranks a shared century, and a post whose only
term is a period still relates to something. There are no `courses`, `people`,
or `categories` frontmatter fields — curated connections go in a research path,
where the reason for the connection can be stated in prose.

## Research Paths

Research paths live in `content/research/` and provide short, intentionally
ordered routes through existing work. A path may reference a site page by its
published URL path or a source by its key:

```yaml
items:
  - page: "articles/example-article"
    note: "Why this is the useful place to begin."
  - page: "courses/1493"
    note: "The broader teaching context."
  - source: "example2026"
    note: "A source for continuing beyond the site."
```

Every item requires a short editorial `note`; the sequence should explain a
route rather than merely duplicate a tag page. Missing pages, unknown or
duplicate source keys, or malformed items fail the Hugo build. Research
paths are deliberately excluded from the main feed and writing archive; the
archive links to their own landing page.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/newpost.sh` | Create an article, review, or quote draft in the vault |
| `scripts/publish-draft.sh` | Move an Obsidian draft into `content/`; optional `--cite` Works Cited |
| `scripts/newsource.sh` | Create a source page, prefilling from the Zotero library (citation key), Open Library (ISBN), or Crossref (DOI) |
| `scripts/finishsource.sh` | Mark a source read and stamp its finish metadata |
| `scripts/cite-refs.sh` | Extract citation keys / render a Works Cited list for a draft (used by publish-draft) |
| `scripts/add-images.sh` | Add bundle images, with cover/body handling |
| `scripts/preflight.sh` | Local pre-push gate, including published-draft and source-image policy checks |
| `scripts/ship.sh` | Run preflight, then commit and push in one step (`--push` on publish-draft.sh / finishsource.sh calls this); lists all pending files and asks for confirmation first (`--yes` skips the prompt) |
| `scripts/lib.sh` | Shared bash helpers (`trim`, `field`, `list_field`, `rfc3339_now`, ...) sourced by the scripts above — not run directly |

Less frequently used maintenance and audit helpers are documented in [operations.md](operations.md) and [maintenance.md](maintenance.md).

## Shortcodes

| Shortcode | Usage | Description |
|---|---|---|
| `carousel` | `{{</* carousel "a.avif" "b.avif" */>}}` | Image carousel from page bundle resources |
| `figure` | `{{</* figure src="image.avif" alt="Description" caption="Caption text" */>}}` | Responsive figure with optional caption, title, attribution, link, and lightbox |

### Figure shortcode notes

The `figure` shortcode supports the stock Hugo/PaperMod-style options:

- `src`
- `alt`
- `caption`
- `title`
- `attr`
- `attrlink`
- `link`
- `target`
- `rel`
- `class`
- `align="center"`
- `margin=true` (wide-screen margin rail; returns to the normal flow on smaller screens and in print)

For a museum painting, a typical pattern is:

```go-html-template
{{</* figure
  src="homer-fog-warning.avif"
  alt="Winslow Homer painting of a fisherman in a small boat at sea"
  caption="Winslow Homer, The Fog Warning, 1885."
  attr="Museum of Fine Arts, Boston"
  attrlink="https://www.mfa.org/"
*/>}}
```

If `attrlink` is omitted, attribution still renders cleanly as its own italicized segment rather than collapsing awkwardly into the caption.

For an image that supports a specific passage rather than interrupting it,
add `margin=true`. On sufficiently wide screens it appears in the scholarly
margin rail alongside the prose; elsewhere it behaves like an ordinary figure:

```go-html-template
{{</* figure
  src="portrait.avif"
  margin=true
  alt="Portrait of Robert G. Ingersoll"
  caption="Robert G. Ingersoll, circa 1865–1880."
  attr="Wikimedia Commons"
  attrlink="https://commons.wikimedia.org/"
*/>}}
```

Markdown footnotes use the same rail automatically on screens at least 1280px
wide. On smaller screens they retain the tap/click popover and conventional
footnote list; printing and feeds always use the conventional list.

## Adding a New Content Type

If you add a new section, for example `content/essays/`:

1. Add it to `contentSections` in `hugo.yaml`
2. Add any needed cache rules in `static/_headers`
3. Add it to the home page or list templates if it should surface there
