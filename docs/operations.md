# Operations

## Remotes

Codeberg is the public canonical remote. GitHub is a private testing mirror for Actions only.

| Remote | Purpose |
|---|---|
| `origin` | Codeberg fetch/push |
| `github` | Private GitHub testing mirror |
| `both` | Legacy helper remote |

The normal path is:

```sh
scripts/preflight.sh && git push
```

`origin` should fetch from Codeberg and carry push URLs for both Codeberg and GitHub.

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
2. no unoptimized JPEG, PNG, or WebP source images outside approved icons and JPEG companions
3. Hugo build
4. content resource references
5. source junk files
6. generated junk files
7. feed lint
8. CSP hash drift
9. published-reference scan
10. page-size lint
11. image display lint

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
