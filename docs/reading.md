# Reading Ledger

The `/reading/` page is built from individual YAML files in `data/reading/books/` and `data/reading/articles/`.

Each file represents one source record. Books and articles share a common core:

```yaml
title: "Example Title"
author: "Author Name"
type: "book"            # or "article"
cite_key: "author2024"
status: "read"          # or "current"
published_year: 2024
read_year: 2026
started: "2026-06-01"
started_announced: "2026-07-02T14:37:00-05:00"
finished: "2026-06-14"
finished_announced: "2026-07-02T15:02:00-05:00"
notes: "Optional short note shown when expanded."
```

Book-specific fields:

```yaml
publisher: "University Press"
isbn: "9780000000000"
format: "Hardcover"
```

Article-specific fields:

```yaml
container_title: "The Popular Science Monthly"
volume: "50"
issue: "1"
pages: "12-19"
doi: "10.0000/example-doi"
url: "https://doi.org/10.0000/example-doi"
```

## Meaning of the Date Fields

- `started` and `finished` are the actual reading dates
- `started_announced` and `finished_announced` are feed timestamps used when the event is announced on the site

If the announcement fields are absent, the RSS feed falls back to the reading date.

That separation exists so services like Micro.blog treat a newly added reading event as new, rather than as an old midnight post.

## Creating Entries

```sh
scripts/newsource.sh book "Book Title"
scripts/newsource.sh article "Article Title"
```

The script:
- prompts for source type when omitted
- for books, prompts for ISBN first and queries Open Library when possible
- for articles, prompts for DOI first and queries Crossref when possible
- prefills metadata when lookup data is available
- writes the file in canonical key order

Compatibility wrappers still exist:

```sh
scripts/newbook.sh "Book Title"
```

`status: "current"` places a source in the currently reading section.

## Marking a Source Finished

```sh
scripts/finishsource.sh books/book-slug
scripts/finishsource.sh articles/article-slug
```

The script:
- changes `status` from `current` to `read`
- prompts for a finish date
- derives `read_year`
- stamps `finished_announced` with the current local timestamp
- preserves the rest of the metadata

If you omit the argument, it lists sources currently marked `status: "current"` and lets you choose interactively.

Compatibility wrapper:

```sh
scripts/finishbook.sh book-slug
```

## Post Linking

`cite_key` is the preferred way to connect a reading entry to posts on the site. Add the same `cite_key` to reviews, quotes, or articles and the reading page links them automatically.

Articles and other multi-source pages can also use an optional `cite_keys` array so one page can connect to several reading-ledger entries without exposing those keys to readers.

The older manual `related_posts` list still works as a fallback, but `cite_key` is the main pattern going forward.

## Feed Behavior

The reading page emits its own RSS feed:

- started sources produce a "started reading" event
- finished sources produce a "finished reading" event
- entries are intentionally content-first for Micro.blog syndication
- book titles in feed HTML link to `https://micro.blog/books/<isbn>` when ISBN is present
- article titles link to `url` or DOI targets when present

Older source records without announcement timestamps stay quiet unless you explicitly edit them, which avoids waking up the archive in downstream syndication.
