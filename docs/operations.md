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

1. Hugo build
2. content resource references
3. source junk files
4. generated junk files
5. feed lint
6. CSP hash drift
7. published-reference scan

Useful modes:

```sh
scripts/preflight.sh
scripts/preflight.sh --strict
scripts/preflight.sh --full
```

- `--strict` fails on Hugo warnings
- `--full` adds the slower CI-grade checks

## GitHub Actions

GitHub Actions runs from `.github/workflows/site-checks.yml` on:

- pushes to the private mirror
- manual dispatch
- weekly schedule

The workflow runs:

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
