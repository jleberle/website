# Maintenance

## After Upgrading Hugo

When local Hugo changes, run:

```sh
scripts/sync-hugo-version.sh
```

That updates the Hugo versions referenced in:

- `statichost.yml`
- `.github/workflows/site-checks.yml`

After a Hugo upgrade, also verify CSP hashes:

```sh
scripts/csp-hashes.sh --check
```

## CSP Hashes

The `Content-Security-Policy` header in `static/_headers` allows inline `<style>` and `<script>` blocks by exact SHA-256 hash. There is no `'unsafe-inline'` in `script-src` or `style-src`.

That means hashes can drift when:

- an inline script or style changes
- Hugo's minifier changes how those blocks are emitted

Commands:

```sh
scripts/csp-hashes.sh
scripts/csp-hashes.sh --check
scripts/csp-hashes.sh --check --no-build
```

When drift appears:

1. run `scripts/csp-hashes.sh`
2. update both CSP blocks in `static/_headers`
3. commit the result

## Theme History

This repo no longer tracks PaperMod as a dependency. There is no `themes/` upstream relationship to diff against for active maintenance purposes.

What remains:

- `layouts/`
- `assets/css/base/`
- `assets/css/license.css`

These originated in PaperMod and were vendored into the repo. The site-specific work lives on top of that as first-class local code.

Dead compatibility shims and unused PaperMod pieces were deliberately removed rather than preserved for theme-upgrade compatibility.

## Operational Notes

- StaticHost deploys independently of GitHub Actions, so local preflight remains the real pre-push gate.
- Secret scanning is enforced by the global Git pre-commit hook in the dotfiles setup rather than by a repo-local hook.
- If macOS metadata files ever reappear, `scripts/preflight.sh` now checks both Hugo source directories and generated output for `.DS_Store` and similar junk.
