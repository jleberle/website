# Workflow

## Content Layout

| Directory | Description |
|---|---|
| `content/articles/` | Essays and blog posts |
| `content/reviews/` | Reviews, usually page bundles |
| `content/quotes/` | Quote posts, flat files |
| `content/cv/` | CV page |
| `content/courses/` | Course pages |
| `drafts/` | Obsidian-only drafts, ignored by Git |

Published posts follow `YYYY-MM-DD-slug/` page-bundle naming for articles and reviews, and dated flat files for quotes. Draft front matter is stamped in the site's local timezone (`America/Chicago`) so feeds sort correctly.

## Draft and Publish Flow

Obsidian drafts live under `drafts/articles/`, `drafts/reviews/`, and `drafts/quotes/`. They are intentionally outside the published content tree so Obsidian Sync can carry them between machines without putting unpublished work in Git.

Use the CLI scaffolder or the Obsidian templates in `_templates/`:

```sh
scripts/newpost.sh article "Post Title"
scripts/newpost.sh review "Review Title"
scripts/newpost.sh quote "Quote Title"
```

When a draft is ready:

```sh
scripts/publish-draft.sh drafts/articles/2026-06-24-post-title.md
```

That script:
- moves the file into the correct published section
- preserves page bundles for articles and reviews
- leaves quotes as flat files
- flips `draft: true` to `draft: false`
- stamps `publishDate` and `lastmod` when missing

## Metadata Conventions

`description` is the canonical public-facing and SEO blurb. `summary` is only for cases where the list/feed teaser should differ.

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

## Scripts

| Script | Purpose |
|---|---|
| `scripts/newpost.sh` | Create an ignored article, review, or quote draft |
| `scripts/publish-draft.sh` | Move an Obsidian draft into `content/` |
| `scripts/newsource.sh` | Create a reading-ledger source entry, with prompts tailored to books or articles |
| `scripts/finishsource.sh` | Move a current reading source to read and stamp finish metadata |
| `scripts/add-images.sh` | Add bundle images, with cover/body handling |
| `scripts/preflight.sh` | Local pre-push verification gate |

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

## Adding a New Content Type

If you add a new section, for example `content/essays/`:

1. Add it to `contentSections` in `hugo.yaml`
2. Add any needed cache rules in `static/_headers`
3. Add it to the home page or list templates if it should surface there
