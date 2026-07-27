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

`external_url` is optional and points at the specific passage or edition being
discussed. It renders as a "Read online" link beside the citation; it does not
turn the post title into an outbound link.

Cross-linking between pages is handled two ways: automatically by shared tags
(the `Related writing` footer block), and deliberately by research paths. There
are no `courses`, `people`, or `categories` frontmatter fields — curated
connections go in a research path, where the reason for the connection can be
stated in prose.

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
| `scripts/newsource.sh` | Create a source page, prefilling from Open Library (ISBN) or Crossref (DOI) |
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
