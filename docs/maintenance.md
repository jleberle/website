# Maintenance

## After Upgrading Hugo

Two independent places pin the Hugo version, and both are manual:

1. `.hugo-version` in this repo — bump it to the new version once the
   matching `.deb` is actually published on Hugo's GitHub releases (bumping
   early 404s CI's download; see `.github/workflows/site-checks.yml`, which
   derives its own Hugo version from this file at run time). `scripts/doctor.sh`
   flags a mismatch between this pin and your local Hugo.
2. Cloudflare Workers Builds' own `HUGO_VERSION` build variable
   (dashboard-managed, not read from this repo — see
   [operations.md](operations.md)) — update this to match, or the live build
   drifts from what CI validated.

There used to be a script (`sync-hugo-version.sh`) that automated step 1. It's
gone: step 2 was always manual regardless, so automating only half the sync
didn't save the trip — both get updated by hand now, in the same sitting.

## CSP

The `Content-Security-Policy` header in `static/_headers` is `script-src
'self'; style-src 'self'` — no `'unsafe-inline'`, and no per-build hash list to
maintain. There are no inline `<script>` or `<style>` blocks anywhere in
`layouts/`; everything is either a fingerprinted external file under
`/js/*` (see `extend_head.html`'s JS bundle) or, for the Speculation Rules
block, `static/speculation-rules.json` loaded via `src=`. `'self'` already
covers both, so nothing here needs regenerating after a Hugo upgrade or a
template change.

If a future template reintroduces an inline `<script>` or `<style>` block,
either move it to an external file the same way, or reintroduce a hash-based
CSP exception (a former `scripts/csp-hashes.sh` did this by computing
SHA-256 hashes from the built output — check history if you need the
approach back).

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

- Cloudflare Workers Builds deploys independently of GitHub Actions, so local preflight remains the real pre-push gate.
- Secret scanning is the global Git pre-commit hook's only responsibility. The repository preflight owns publish policy, including draft and source-image checks, without modifying the Git index.
- `scripts/preflight.sh` scans Hugo source directories for `Thumbs.db` and `desktop.ini`. It no longer scans for `.DS_Store` (in `.gitignore`, so it cannot be committed) or scans `public/` at all (untracked, and Cloudflare builds from a fresh clone) — neither could detect anything that could reach the live site. See [operations.md](operations.md).
- Preflight also includes site-specific growth guards: oversized built HTML pages and responsive image candidates that are too small for the slots the theme renders. Both are advisories — they print but do not block a push, and CI fails on them.
