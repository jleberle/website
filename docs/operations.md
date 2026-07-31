# Operations

## Remotes

Codeberg is the public canonical remote. GitHub is a private testing mirror for Actions only. Both are reached through a single `origin` remote: it fetches from Codeberg and carries two push URLs, so one `git push` updates both.

```sh
git remote -v
# origin  codeberg:jle/website.git (fetch)
# origin  codeberg:jle/website.git (push)
# origin  github:jleberle/website.git (push)
```

A pre-push hook (`~/.dotfiles/git/hooks/pre-push`, wired in via
`core.hooksPath`) runs `scripts/preflight.sh` automatically before anything
leaves this machine, so a bare `git push` is already gated. The normal path is
still to run preflight explicitly first, so failures are caught before a
commit exists rather than after:

```sh
scripts/preflight.sh && git push
```

or, to also stage, commit, and push in one step — this runs preflight itself
too, so the hook's run is a fast (~3s) second pass, not meaningful overhead:

```sh
scripts/ship.sh "Commit message"
```

Bypass the hook deliberately with `git push --no-verify`.

## Deployment

Deployment is handled by [statichost.eu](https://statichost.eu) via `statichost.yml`.

- every push deploys from the canonical repo path
- Hugo runs with `--minify`
- output is written to `public/`

## Local Preflight

The default local gate is intentionally narrower than CI. It is meant to answer:

> will this site build and publish correctly right now?

Default `scripts/preflight.sh` checks:

1. no `draft: true` files in the publishable content tree
2. period values filed under `eras`, not `tags`
3. every `tags` value is an approved subject term
4. no orphan posts; `about:` is a subset of `sources:`
5. no unoptimized JPEG, PNG, or WebP source images outside approved icons and JPEG companions
6. no EXIF/IPTC/XMP metadata left on a published raster image
7. Hugo build
8. content resource references
9. source junk files
10. generated junk files
11. feed lint
12. CSP hash drift
13. security.txt clearsignature present, valid, unexpired
14. published-reference scan
15. page-size lint
16. image display lint

Useful modes:

```sh
scripts/preflight.sh
scripts/preflight.sh --strict
scripts/preflight.sh --full
```

- `--strict` fails on Hugo warnings
- `--full` adds the slower CI-grade checks

The two new size-oriented checks are intentionally site-specific:

- page size lint warns once a normal HTML page exceeds `96 KiB` raw and fails at `128 KiB`
- `reading/index.html` gets a relaxed ceiling because it is intentionally denser
- image display lint checks generated responsive image candidates against the real slots the theme asks the browser to fill, so it can flag likely soft/blurry images before publish

### Known growth limits

Three pages render every entry into one document, so they have measured ceilings
rather than open-ended growth. All the numbers come from building synthetic
corpora, not estimates:

| Page | Limit | Headroom |
|---|---|---|
| `/reading/<year>/` | ~55 books in one year warns, ~75 fails | busiest year on record is 10 |
| `/archives/` | ~119 posts warns, ~161 fails | 30 posts, about 2/month |
| `/sources/` | ~215 sources warns, ~289 fails | 65 sources, 7–10 read a year |

The reading ledger was split by year in 2026-07 precisely because it had no such
bound — see [reading.md](reading.md). `/archives/` and `/sources/` still have
none, for the same reason in both cases: each is one page by design, because its
job is to be scanned or searched across everything, and splitting it defeats
that. At roughly two posts a month `/archives/` is about five years out;
`/sources/` is further, since the ceiling is 4.5x the current library.

**Revisit `/archives/` at 100 posts.** The fix is to move the per-entry
`data-archive-search-text` attribute (32% of each entry's markup) into a fetched
JSON index and paginate the HTML, with search running against the full index so
pagination does not break finding things. `connect-src 'self'` in
`static/_headers` already permits that fetch, so no CSP change is needed. Doing
it now would mean tuning a search index against 30 entries.

**Revisit `/sources/` at 150 sources.** The trigger is when the bibliography
stops being scannable in one pass, which arrives well before the size ceiling
does. The mechanism already exists: `assets/js/archive-filters.js` (116 lines)
does facet buttons, free-text search, URL state, an `aria-live` count, empty
state and reset for `/archives/`, and ships `hidden` so the page still works
without JS. A sources version is close to a copy against a `data-source-tags`
attribute plus one entry in the bundle list in `layouts/_partials/extend_head.html`.

Three things decided in advance, so they are not re-litigated then:

- **Lead with search over title and author, not subject facets.** You arrive at
  a bibliography knowing the author. 19 distinct subjects appear on sources
  against 65 works, so facets are a lot of chrome for not much narrowing — the
  reverse of `/archives/`, where four section buttons filter thirty posts.
- **Subject facets structurally cannot show everything.** 7 of 65 sources carry
  no subject tag, and unlike a post — where `connection-lint.py` requires a
  source or a tag — an untagged source is legitimate; nothing in the vocabulary
  fits `bacon2025` or `grann2018`. Any facet UI hides that 11% unless "Untagged"
  is itself a facet. The bibliography already derives that group
  (`where $sources "Params.tags" nil`) and labels those rows Uncategorized, so
  the affordance exists and needs only to be made filterable. Search does not
  have the problem at all.
- **If it gets search, it should get the JSON index at the same time.** Search
  text as a per-row data attribute is what makes `/archives/` expensive, and
  adding it here would lower the ceiling in the table above rather than raise
  it. Fetching the index instead removes the ceiling altogether.

Subject browsing already works from the other direction and needs nothing:
`/tags/<term>/` lists "Sources on this subject" beside the writing on it
(`layouts/term.html`). What is missing is only narrowing without leaving
`/sources/`. Filtering needs no new per-row data — the subjects are already
rendered as links in each row, which is what dropped the ceiling above from
~294 to ~215 — so the remaining cost is the UI and the script, not the markup.

## GitHub Actions

GitHub Actions runs from `.github/workflows/site-checks.yml` on:

- pushes to the private mirror
- manual dispatch
- weekly schedule

The workflow runs:

- a separate full-history Gitleaks secret scan
- `scripts/preflight.sh --strict --full`
- `npm run test:axe`

Manual and scheduled runs also perform the full external `lychee` check against the generated site.

Failure artifacts include the built `public/` directory and captured logs so CI failures can be inspected without reproducing them locally.

## Dependabot

Dependabot is configured in `.github/dependabot.yml` for grouped monthly updates covering:

- npm dependencies
- GitHub Actions

## Link Checking

Manual link-audit helper:

```sh
scripts/archive-links.sh --dry-run --all
scripts/archive-links.sh --all
```

Scheduled CI also runs broader link checking.

## Accessibility and Feed Checks

- `scripts/checks/feed-lint.py` validates generated RSS and JSON feed output
- `npm run test:axe` exercises representative rendered pages
- HTML and CSS linting run as part of the full CI suite

These are intentionally CI-backed as well as locally runnable.

## Feed Notifications

The main and reading RSS feeds advertise the public Google WebSub hub through
`atom:link rel="hub"`, alongside their canonical `rel="self"` links. The JSON
Feed advertises the same endpoint through its JSON Feed 1.1 `hubs` array. After
a successful push validation on GitHub, `scripts/notify-websub.py` waits until
StaticHost serves the exact newly built feeds and then sends one publish ping
for all three topics. It then sends Micro.blog's form-encoded `/ping` request
for each feed, allowing Micro.blog to refresh registered sources immediately.

Notification is best-effort and cannot block deployment: the workflow step
uses `continue-on-error` because the site and feeds remain fully functional
when either external service is temporarily unavailable. The two RSS URLs use
`max-age=0, must-revalidate` so the hub cannot retrieve an hour-old cached
copy after being notified.

To inspect discovery without contacting the hub:

```sh
hugo --minify
scripts/notify-websub.py --dry-run public/index.xml public/reading/index.xml public/feed.json
```

The hub URL is configured as `params.websubHub` in `hugo.yaml`. Keep the
notification script's supported publish form in mind if changing providers;
the current hub accepts repeated `hub.url` fields.
