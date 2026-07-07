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

Use the CLI scaffolder or, in Obsidian, the Templater templates installed at
`Meta/templates/Website/` (bound to the drafting hotkeys — post/review on the
hyperkey with `P`/`R`, link/quote on `Ctrl+Cmd+L`):

```sh
scripts/newpost.sh article "Post Title"
scripts/newpost.sh review "Review Title"
scripts/newpost.sh quote "Quote Title"
```

The canonical copies of those templates live in the repo at `_templates/`; after
editing one there, copy it into the vault's `Meta/templates/Website/` folder.

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
- merges any citation keys used in the body into `cite_keys` (see Citations below)

## Citations

For scholarly posts, cite works with pandoc-style keys in the draft body —
`[@mckenziejones2015]` inline, or a non-rendering `<!-- cite: @allen2012 @cobb2015 -->`
comment to declare sources without printing a marker. On publish, those keys are
merged into `cite_keys` front matter automatically, wiring the post into the
reading page's cross-linking without retyping keys.

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

Optional review metadata:

- `reviewed_type`
- `reviewed_title`
- `reviewed_author`
- `reviewed_publisher`
- `reviewed_year`
- `external_url`

Optional quote/source metadata:

- `source_title`
- `source_author`
- `source_year`
- `external_url`

`external_url` links the reviewed/source title in the context line. It does not turn the post title into an outbound link.

`cite_key` is the preferred primary cross-linking key between reading-ledger entries and site posts. The expected format matches Zotero style, e.g. `mckenziejones2015`.

For multi-source pages, especially articles, add an optional `cite_keys` array:

```yaml
cite_key: "mckenziejones2015"
cite_keys:
  - "iverson1994"
  - "gardiner2015"
```

`cite_key` remains the primary work; `cite_keys` adds additional related books or sources. Neither field is displayed publicly.

For teaching-specific cross-linking, use a separate `courses` array keyed by course slugs:

```yaml
courses:
  - "1493"
  - "3793"
```

This is distinct from tags. Tags stay conceptual; `courses` is only for linking material into course pages and surfacing `Teaching connection` blocks on related posts.

For recurring historical figures or actors, use a `people` array keyed by slug:

```yaml
people:
  - "theodore-roosevelt"
  - "clyde-warrior"
```

Authority records live in `data/people/`. At minimum, add `name`; other fields are optional. This keeps person names consistent and allows the footer apparatus to surface `People` and `Elsewhere on these figures` blocks without exposing backend-only keys.

## Research Paths

Research paths live in `content/research/` and provide short, intentionally
ordered routes through existing work. A path may reference a site page by its
published URL path or a reading-ledger source by `cite_key`:

```yaml
items:
  - page: "articles/example-article"
    note: "Why this is the useful place to begin."
  - page: "courses/1493"
    note: "The broader teaching context."
  - reading: "example2026"
    note: "A source for continuing beyond the site."
```

Every item requires a short editorial `note`; the sequence should explain a
route rather than merely duplicate a tag page. Missing pages, unknown reading
keys, duplicate reading keys, or malformed items fail the Hugo build. Research
paths are deliberately excluded from the main feed and writing archive; the
archive links to their own landing page.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/newpost.sh` | Create an article, review, or quote draft in the vault |
| `scripts/publish-draft.sh` | Move an Obsidian draft into `content/`; merge `cite_keys`; optional `--cite` Works Cited |
| `scripts/newsource.sh` | Create a reading-ledger source entry, with prompts tailored to books or articles |
| `scripts/sync-reading.sh` | Scaffold a reading-ledger entry from a vault reading note + the Zotero library |
| `scripts/cite-refs.sh` | Extract citation keys / render a Works Cited list for a draft (used by publish-draft) |
| `scripts/finishsource.sh` | Move a current reading source to read and stamp finish metadata |
| `scripts/add-images.sh` | Add bundle images, with cover/body handling |
| `scripts/preflight.sh` | Local pre-push gate, including published-draft and source-image policy checks |

Less frequently used maintenance and audit helpers are documented in [operations.md](operations.md) and [maintenance.md](maintenance.md).

## Shortcodes

| Shortcode | Usage | Description |
|---|---|---|
| `youtube` | `{{</* youtube VIDEO_ID */>}}` | Click-to-load YouTube embed |
| `bluesky` | `{{</* bluesky "https://bsky.app/..." */>}}` | Click-to-load Bluesky embed |
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
