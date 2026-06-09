# JaredEberle.org

Source for [jaredeberle.org](https://jaredeberle.org), the personal and academic site of Jared L. Eberle — historian of late 20th century Indigenous activism and lecturer at Oklahoma State University.

Built with [Hugo](https://gohugo.io) using the [PaperMod](https://github.com/adityatelange/hugo-PaperMod) theme.

## Prerequisites

- [Hugo](https://gohugo.io/installation/) (extended edition, see version in `statichost.yml`)
- [Lychee](https://lychee.cli.rs) for link checking (optional)

## Local development

```sh
hugo server
```

The site will be available at `http://localhost:1313`.

## Content

| Directory | Description |
|---|---|
| `content/articles/` | Blog posts and essays |
| `content/reviews/` | Book and film reviews |
| `content/cv/` | Curriculum vitae |
| `content/courses/` | Course listings |
| `content/quotes/` | Short quote and link posts |

New posts follow the naming convention `YYYY-MM-DD-slug/index.md`. Use the Obsidian templates in `_templates/` or the Hugo archetypes.

## Shortcodes

| Shortcode | Usage | Description |
|---|---|---|
| `youtube` | `{{</* youtube VIDEO_ID */>}}` | Click-to-load YouTube embed. Thumbnail is self-hosted at build time via `resources.GetRemote`. Video only loads on click. |
| `bluesky` | `{{</* bluesky "https://bsky.app/..." */>}}` | Click-to-load Bluesky embed. Embed script only loads on click. |
| `carousel` | `{{</* carousel "a.avif" "b.avif" */>}}` | Image carousel from page bundle files. Supports keyboard navigation and dot indicators. |

## Images

Two stages, two tools:

**1. Authoring — convert sources to AVIF with `scripts/to-avif.sh` (ImageMagick).** Drop the resulting `.avif` into the page bundle (or `assets/`) and reference it. The script also writes a `.jpg` companion for OpenGraph crawlers. Don't pre-generate resized variants — that's Hugo's job (next stage). Author images at a sensible max width (covers/in-body ~1500px is plenty; the build only downscales, never upscales).

**2. Responsive sizing — Hugo (extended) resizes the AVIF natively at build time** and emits a `srcset`, so each viewport/DPR downloads only what it needs. This happens in several places:

| Where | Template | Widths emitted |
|---|---|---|
| Markdown body images | `layouts/_markup/render-image.html` | 400 / 800 / 1200w + lightbox + lazy-load |
| Post covers | `layouts/_partials/cover.html` | 360 / 480 / 720 / 1080 / 1500w |
| `carousel` shortcode | `layouts/shortcodes/carousel.html` | 400 / 800w |
| Home avatar | `layouts/_partials/home_info.html` | 1x / 2x from `imageWidth` |
| Header logo | `layouts/_partials/header.html` | 2x from `iconHeight` |

Each variant is only generated when the source is wider than that breakpoint, and every `<img>` gets explicit `width`/`height` to prevent layout shift. Hugo's AVIF quality is set under `imaging.avif` in `hugo.yaml`.

> **Gotcha:** Hugo *extended* can resize AVIF, but PaperMod's `cover.html` keeps a hardcoded `$processableFormats` list that omits `avif` upstream — the override here appends it. If you re-pull `cover.html` from the theme, re-add `avif` (see the PaperMod-update notes below) or covers silently fall back to full-size, unsized images.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/to-avif.sh` | Convert images to AVIF + JPEG (for OG images) |
| `scripts/archive-links.sh` | Check all posts for dead links and replace with Wayback Machine snapshots |
| `scripts/csp-hashes.sh` | Regenerate / verify Content Security Policy hashes (inline styles *and* scripts) after Hugo or PaperMod updates |
| `scripts/newlink.sh` | Add a new link entry |
| `scripts/sync-hugo-version.sh` | Update CI build images to match local Hugo version |

## Link checking

Run manually when needed — Woodpecker CI also runs lychee on a schedule.

```sh
scripts/archive-links.sh --dry-run --all   # preview
scripts/archive-links.sh --all             # fix
```

## Deployment

The site deploys automatically via [statichost.eu](https://statichost.eu) on every push using the configuration in `statichost.yml`. Hugo runs with `--minify` and outputs to `public/`.

## Maintenance

### After upgrading Hugo locally
Run `scripts/sync-hugo-version.sh` to update the CI build images in `statichost.yml` and `.woodpecker.yml` to match. The weekly Homebrew job will notify you when Hugo updates — its notification also reminds you to run `scripts/csp-hashes.sh --check`, because a changed minifier can silently invalidate the CSP hashes (see below).

### After updating PaperMod

**1. Pull the update**
```sh
git submodule update --remote themes/PaperMod
```

**2. Build and check for errors**
```sh
hugo server
```

If it builds cleanly, most things are fine. If it fails, the error will point at what broke.

**3. Check the four most likely conflict files**

Diff each override against its updated PaperMod source:

```sh
diff themes/PaperMod/layouts/_partials/cover.html layouts/_partials/cover.html
diff themes/PaperMod/layouts/_partials/index_profile.html layouts/_partials/index_profile.html
diff themes/PaperMod/layouts/_partials/templates/opengraph.html layouts/_partials/templates/opengraph.html
diff themes/PaperMod/layouts/baseof.html layouts/baseof.html
```

For each diff: if PaperMod changed unrelated lines, copy their new version and re-apply the change noted below. If they changed the same lines, merge manually.

- `layouts/_partials/cover.html` — `($cover | fingerprint).RelPermalink` instead of `.Permalink`; and `avif` appended to `$processableFormats` so AVIF covers get responsive variants (see [Images](#images))
- `layouts/_partials/index_profile.html` — `$img.RelPermalink` and `| fingerprint` for avif
- `layouts/_partials/templates/opengraph.html` — jpeg OG companion lookup and `site.Language.Lang`
- `layouts/baseof.html` — `.home` class on body for home page, `.Language.Direction`

**4. Re-check the CSP hashes**

A PaperMod update can change an inline style or script without failing the build, which silently invalidates a CSP hash. Run `scripts/csp-hashes.sh --check` and re-hash if it reports drift (see [Content Security Policy hashes](#content-security-policy-hashes)).

**5. Commit the submodule update**
```sh
git add themes/PaperMod
git commit -m "Update PaperMod to latest"
```

### Content Security Policy hashes

The `Content-Security-Policy` header in `static/_headers` allows PaperMod's inline `<style>` and `<script>` blocks by their exact SHA-256 hashes — there is **no `'unsafe-inline'`** in `script-src` or `style-src`. The hashes cover the bytes Hugo's minifier actually emits, so they break if either PaperMod changes a theme style/script **or** Hugo changes how it minifies. When a script hash breaks, the browser silently blocks that script (e.g. dark-mode-on-load or the theme toggle stops working) with only a console CSP error — so verify after upgrades.

Currently hashed scripts: the FOUC theme-on-load setter, the theme toggle, and the menu-scroll / anchor-smooth-scroll handler. PaperMod's scroll-to-top script is intentionally dropped via `disableScrollToTop: true` in `hugo.yaml` so it needs no hash; re-enabling it would require adding its hash.

```sh
scripts/csp-hashes.sh             # build, then print current hashes to paste into static/_headers
scripts/csp-hashes.sh --check     # build, then compare against static/_headers; exit 1 on drift
scripts/csp-hashes.sh --check --no-build   # reuse an existing public/ (used by CI)
```

`--check` reports per directive: `OK` (match), `DRIFT` (a hash is in the build but missing from `_headers` — would be blocked; fails with exit 1), or `WARN` (a stale hash in `_headers` is no longer used — safe to remove). When it reports drift, run `scripts/csp-hashes.sh`, paste the new hashes into **both** CSP blocks in `static/_headers` (the `*` block and the `/iframe-page/*` block), then commit.

Woodpecker CI runs `csp-hashes.sh --check --no-build` on every push as the `csp-check` step (reusing the build step's `public/`). It fails the CI build on drift as a background alarm — note that a failed Woodpecker run does **not** block statichost from deploying, so treat it as a signal to re-hash, not a hard gate.

### Dead link check
Run `scripts/archive-links.sh --all` periodically to find and replace dead outbound links with Wayback Machine snapshots. Woodpecker's scheduled lychee job will flag broken links in CI.

### Adding a new content type
If you add a new section (e.g. `content/essays/`):
1. Add it to `mainSections` in `hugo.yaml`
2. Add a cache rule in `static/_headers` (`/essays/*/*.avif` etc.)
3. Add it to the home page columns in `layouts/list.html` if desired

## Credits

- [PaperMod](https://github.com/adityatelange/hugo-PaperMod) — the Hugo theme this site is built on.
- [Solarized](https://ethanschoonover.com/solarized/) by Ethan Schoonover — the color palette used for the site's light and dark themes.

## License

Content is licensed [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
