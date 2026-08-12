# Operations

## Remotes

GitHub is the sole canonical remote, reached through `origin`. Codeberg was
dropped in 2026-07 after sustained reliability problems (88% uptime over the
prior two weeks).

```sh
git remote -v
# origin  github:jleberle/website.git (fetch)
# origin  github:jleberle/website.git (push)
```

A pre-push hook (`~/git/dotfiles/git/hooks/pre-push`, wired in via
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

Deployment is handled by Cloudflare Workers Builds, which watches the GitHub
repo directly — this is dashboard-managed config, not anything in this repo.

- every push to `main` triggers a build and deploy; other branches build to
  preview URLs
- build command: `hugo --minify && scripts/digest-fields.sh --no-build`
- deploy command: `npx wrangler deploy` (`npx wrangler versions upload` for
  previews)
- the Hugo version is pinned via a `HUGO_VERSION` build variable in
  Cloudflare's build config, kept in sync with this repo's `.hugo-version`
  (see [maintenance.md](maintenance.md)) — the two are independent and can
  drift if one is updated without the other
- `wrangler.jsonc`'s `assets.directory` (`./public`) is served via Workers
  Assets, which honors `public/_headers` the same way Cloudflare Pages did

## Local Preflight

`scripts/preflight.sh` splits its checks by one question:

> if this reaches the live site wrong, can it be taken back?

That question, and not check runtime, is what decides the tiers. The whole
default gate runs in about 7 seconds, so speed was never the constraint. What
matters is that **StaticHost deploys on every push, independently of GitHub
Actions, and `public/` is untracked** — CI is not a gate, it is a report that
arrives after the site is already live. So a check only earns the right to stop
a push if pushing past it does damage a follow-up commit cannot undo.

### Blocking — a push cannot proceed

| Check | Why it can't be walked back |
|---|---|
| published drafts | a post you believe is live and isn't; fails silently by nature |
| image metadata | EXIF/IPTC/XMP (incl. GPS) on a published raster is scraped, syndicated and archived the moment it is served |
| `hugo --minify` | a build error means StaticHost publishes nothing |
| content resources | cover blocks pointing at files that don't exist |
| source junk files | `Thumbs.db`/`desktop.ini` in Hugo inputs get copied into the build |
| feed lint | the sharpest one — Micro.blog dedupes on `<link>`, so a changed link creates duplicate posts on eberle.blog that must be deleted by hand (see `services.rss` in `hugo.yaml`) |
| published-reference scan | dangling internal URLs; guards the `build.publishResources=false` pattern |

### Regenerated, not checked

The correct value is fully determined by the build that just ran, so producing
it beats failing and making a human retype it. `ship.sh` commits with
`git add -A`, so the refreshed files ride along with the push:

- `data/writing-log.json` — `writing-log.py`
- `static/_headers` CSP hashes — `csp-hashes.sh --write`
- `public/_headers` Content-Digest — `digest-fields.sh`

CSP drift is live-breaking (a stale hash means the browser blocks a real inline
script in production), so it can't be an advisory — but it also can't justify
blocking, since the script already knows the answer. Writing it keeps the push
unblocked *and* production correct, which checking could only do one of.
`--write` prints every hash it adds or removes alongside the source that
produced it, so a newly introduced inline script still surfaces in the output
rather than being blessed silently.

### Advisory — printed, never blocking

Taxonomy facets, tag vocabulary, series naming, graph connections, image
policy, page size, and image display are all real defects that a follow-up
commit fixes with no trace. They print as `⚠` and do not affect the exit code.

They are deferred, not forgiven: `--full` promotes every advisory to a
failure, and that is what CI runs. Running `--full` locally therefore answers
"what will CI say about this?" without pushing.

- page size lint warns once a normal HTML page exceeds `96 KiB` raw and fails at `128 KiB`
- `reading/index.html` gets a relaxed ceiling because it is intentionally denser
- image display lint checks generated responsive image candidates against the real slots the theme asks the browser to fill, so it can flag likely soft/blurry images before publish

### Not on the push path at all

The **security.txt clearsignature** is verified in CI, not preflight. Nothing
in a commit can invalidate it — only the calendar — so gating a push on it
stops the wrong person at the wrong moment: a writer without the private key
can neither fix it nor publish around it. Every CI run verifies the signature
against the published `static/key.asc`; the weekly schedule adds
`--days 60`, so "re-sign this" arrives with two months of lead time instead of
on the morning it expires. Current expiry: **2027-05-26**.

```sh
scripts/sign-security-txt.sh --check            # signed, unexpired?
scripts/sign-security-txt.sh --check --days 60  # what the weekly schedule runs
scripts/sign-security-txt.sh                    # re-sign (needs the private key)
```

Two checks were removed rather than retiered. The `public/` junk-file scan
could not detect anything that could reach the live site: `public/` is
untracked and StaticHost builds from a fresh clone in a clean container. The
`.DS_Store` half of the source junk scan was equally unreachable — it is in
`.gitignore`, so it cannot be committed. `Thumbs.db` and `desktop.ini` are not
gitignored, so those remain checked.

### Modes

```sh
scripts/preflight.sh            # blocking tier + advisories
scripts/preflight.sh --strict   # also fail on Hugo WARN lines
scripts/preflight.sh --full     # the CI gate: advisories become failures
```

### Failure messages

Every result in `preflight.sh` carries a fix line, and this is enforced by the
shape of the helper rather than by discipline — `fail` and `warn` both take two
arguments:

```sh
fail "what is wrong, in plain words"  "what to do about it"
```

A check's own output already names the files. What it cannot say is what the
person reading it should do next, and a diagnosis with no next step is the same
as no message at all for anyone who did not write the check. Because the fix
line is a positional argument, a new check cannot be added without answering
that question.

The wording rules that follow from it: say what is wrong and what it costs
before naming the mechanism; assume the reader is a writer, not the person who
wrote the linter; and never make the fix "read the source of the check." The
reading-link stability failure in `scripts/checks/feed-lint.py` is the model —
it states the consequence in posts-created-on-eberle.blog, names the usual
cause (a renamed `content/sources/<slug>/` folder), and gives the command for
each of the two cases.

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

- pushes to the canonical repo
- pull requests
- manual dispatch
- weekly schedule

Three jobs:

- **Secret scan** (required check) — full-history Gitleaks scan
- **Build, validate, and audit** (required check) — `scripts/preflight.sh --strict --full` and `npm run test:axe`. Read-only; never pushes.
- **Post-deploy and maintenance** (not a required check; `needs: verify`, skipped on `pull_request`) — feed/WebSub notification and outbound webmentions on every push to `main`; on manual dispatch or the weekly schedule, also the full external `lychee` check and dead-link archiving to Wayback snapshots. The only job that pushes (outbound webmention state, archived link rewrites), using the `PUSH_TOKEN` PAT — see the Webmentions section above.

Failure artifacts include the built `public/` directory and captured logs so CI failures can be inspected without reproducing them locally.

## Webmentions

`.github/workflows/webmentions.yml` fetches received webmentions from
webmention.io on a daily schedule and writes `data/webmentions.json`,
overwriting it in full each run — webmention.io is the source of truth, not
the file. To remove a mention from the site, delete it in the webmention.io
dashboard first, then re-run the workflow (`gh workflow run webmentions.yml`)
or wait for the next scheduled run; editing `data/webmentions.json` directly
is not durable.

That workflow, plus two steps inside `site-checks.yml` (outbound webmention
state, archived link rewrites), push commits straight to `main`. `main`
requires 2 status checks to pass before a push lands, and `enforce_admins` is
off, so pushes authenticated as an admin (e.g. Jared's own commits) bypass
that requirement — but the default `GITHUB_TOKEN` used by Actions is not an
admin and gets rejected with `GH006: Protected branch update failed`. All
three steps instead authenticate with the `PUSH_TOKEN` repo secret, a
fine-grained PAT owned by an admin, scoped to this repo only with Contents:
Read and write.

To rotate `PUSH_TOKEN` before it expires:

1. Go to <https://github.com/settings/personal-access-tokens>, regenerate (or
   create a new) fine-grained token scoped to `jleberle/website` only, with
   Contents: Read and write and nothing else.
2. Run `gh secret set PUSH_TOKEN --repo jleberle/website` and paste the new
   value when prompted.

`gh secret list --repo jleberle/website` only lists secrets and shows when
they were last updated — it does not renew or rotate anything.

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
