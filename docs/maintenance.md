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

## Trusted Types

`static/_headers` sets `require-trusted-types-for 'script'; trusted-types 'none'`. No script on the site creates a Trusted Types policy, and `'none'` means the CSP won't let one be created even if some future or compromised script tried to. Combined with `require-trusted-types-for 'script'`, the practical effect is that a raw-string write to `innerHTML` (or any other injection sink) is unconditionally blocked, by the browser, from any script on the page — first-party or not. There's no passthrough policy standing in for it.

This used to be a `default` policy in `assets/js/trusted-types-policy.js` whose `createHTML` just returned its input unchanged — it satisfied the CSP directive without sanitizing anything, so the actual protection was narrower than it looked. `footnotes.js` and `obf-email.js` were rewritten to build DOM nodes directly (`createElement`/`textContent`/moving child nodes) instead of assembling HTML strings, which removed every `innerHTML` write on the site. Once none were left, the policy — and the CSP allowance for it — could come out entirely rather than stay around as an unused pass-through.

If a future feature ever needs to write HTML dynamically (a comments system, client-rendered remote content, etc.), that's the point to add a real, narrowly-named policy with an actual sanitizer — and add exactly that name to `static/_headers`' `trusted-types` directive. Don't reach for `'default'` or a pass-through `createHTML` again; both defeat the point of declaring one.

## Layout File Naming

`layouts/` is snake_case throughout (`post_meta.html`, `site_footer.html`, `format_date.html`, the shortcode `cv_letterhead.html`, ...), with one deliberate exception: `layouts/_markup/render-link.html`, `render-image.html`, and `render-table.html` stay kebab-case. Those are Hugo's own [markdown render hook](https://gohugo.io/render-hooks/introduction/) filenames — Hugo discovers them by exact name, not by registration, so renaming one to `render_image.html` doesn't error, it just silently stops Hugo from calling it and that hook's content quietly reverts to default rendering. Leave those three names alone; everything else under `layouts/` follows snake_case.

## Theme History

This repo no longer tracks PaperMod as a dependency. There is no `themes/` upstream relationship to diff against for active maintenance purposes.

What remains:

- `layouts/`
- `assets/css/site/00-license.css`

These originated in PaperMod and were vendored into the repo. The site-specific work lives on top of that as first-class local code; the rest of `assets/css/site/` (numbered `01-`–`99-`) is site-specific CSS with no PaperMod lineage.

Dead compatibility shims and unused PaperMod pieces were deliberately removed rather than preserved for theme-upgrade compatibility.

## Operational Notes

- StaticHost deploys independently of GitHub Actions, so local preflight remains the real pre-push gate.
- Secret scanning is the global Git pre-commit hook's only responsibility. The repository preflight owns publish policy, including draft and source-image checks, without modifying the Git index.
- If macOS metadata files ever reappear, `scripts/preflight.sh` now checks both Hugo source directories and generated output for `.DS_Store` and similar junk.
- Preflight also includes site-specific growth guards: oversized built HTML pages and responsive image candidates that are too small for the slots the theme renders.
