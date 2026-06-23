# JaredEberle.org

Source for [jaredeberle.org](https://jaredeberle.org), the personal and academic site of Jared L. Eberle — historian of late 20th century Indigenous activism and lecturer at Oklahoma State University.

Built with [Hugo](https://gohugo.io) using the [PaperMod](https://github.com/adityatelange/hugo-PaperMod) theme.

**Note**: I had Claude write this to document what was created and where to look for issues in the future. Anything on [my site](https://jaredeberle.org) is written solely my me, Claude is banned from making any edits to content itself.

## Prerequisites

- [Hugo](https://gohugo.io/installation/) (extended edition, see version in `statichost.yml`)
- [ImageMagick](https://imagemagick.org) (`magick`) for `scripts/to-avif.sh` / `scripts/add-images.sh`
- [Lychee](https://lychee.cli.rs) for link checking (optional; `scripts/preflight.sh` skips it when absent)

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

New posts follow the naming convention `YYYY-MM-DD-slug/index.md` (articles and reviews are page bundles; quotes are flat files). Scaffold from the CLI with `scripts/newpost.sh`, or use the Obsidian templates in `_templates/`.

## Publishing workflow

```sh
scripts/newpost.sh article "Post Title"           # scaffold (article|review|quote)
scripts/newpost.sh article --cover "Post Title"   #   articles: cover block on request
                                                  #   reviews: cover block always
                                                  #   quotes: prompts for external_url
scripts/add-images.sh content/articles/<dir> --cover photo.jpg   # cover.avif + OG cover.jpg
scripts/add-images.sh content/articles/<dir> img1.jpg img2.png   # body images → AVIF only
scripts/preflight.sh && git push                  # pre-push gate, then deploy
```

`preflight.sh` runs the same build and CSP checks as CI plus an offline internal-link
check and a scan that every internal `src`/`href`/`srcset`/feed URL resolves to a
published file. `--strict` also fails on build warnings (e.g. figures missing alt text).

## Shortcodes

| Shortcode | Usage | Description |
|---|---|---|
| `youtube` | `{{</* youtube VIDEO_ID */>}}` | Click-to-load YouTube embed. Thumbnail is self-hosted at build time via `resources.GetRemote`. Video only loads on click. |
| `bluesky` | `{{</* bluesky "https://bsky.app/..." */>}}` | Click-to-load Bluesky embed. Embed script only loads on click. |
| `carousel` | `{{</* carousel "a.avif" "b.avif" */>}}` | Image carousel from page bundle files. Supports keyboard navigation and dot indicators. Each slide's `alt` falls back to the humanized filename. All slides lazy-load; for a carousel that is the topmost media on the page use the named form `{{</* carousel images="a.avif, b.avif" eager=true */>}}` so the first slide loads eagerly with `fetchpriority="high"`. Pass real alt text via a parallel, **semicolon-separated** `alts` list (semicolons so alt text may contain commas): `{{</* carousel images="a.avif, b.avif" alts="A bull rider mid-buck; Barrel racing at speed" */>}}` — only the named form can carry `alts`. |

## Images

Two stages, two tools:

**1. Authoring — `scripts/add-images.sh` drops images into a post bundle with the right conversion per role** (it wraps `scripts/to-avif.sh`, ImageMagick): covers become `cover.avif` plus an optimized `cover.jpg` companion for OpenGraph crawlers; body images become `.avif` only. Don't pre-generate resized variants — that's Hugo's job (next stage). Author images at a sensible max width (covers/in-body ~1500px is plenty; the build only downscales, never upscales). Figures without `alt` or `caption` produce a build warning — write alt text describing what the image *shows*; captions are for attribution/commentary and are never copied into alt.

**2. Responsive sizing — Hugo (extended) resizes the AVIF natively at build time** and emits a `srcset`, so each viewport/DPR downloads only what it needs. This happens in several places:

| Where | Template | Widths emitted |
|---|---|---|
| Markdown body images | `layouts/_markup/render-image.html` → `responsive-img` partial | 400 / 800 / 1200w + original + lightbox + lazy-load |
| `figure` shortcode | `layouts/shortcodes/figure.html` → `responsive-img` partial | 400 / 800 / 1200w + original + lightbox |
| `carousel` shortcode | `layouts/shortcodes/carousel.html` → `responsive-img` partial | 400 / 800 / 1200w + original |
| Post covers | `layouts/_partials/cover.html` | 360 / 480 / 720 / 1080 / 1500w |
| Home avatar | `layouts/_partials/home_info.html` | 1x / 2x from `imageWidth` |
| Header logo | `layouts/_partials/header.html` | 2x from `iconHeight` |

The first three share `layouts/_partials/responsive-img.html` — the single source of truth for breakpoints and the `sizes` hint (sized to the 720px content column), so they can't drift apart. Each smaller variant is only generated when the source is wider than that breakpoint; the original is always included as the largest `srcset` candidate (so a `srcset` is still emitted for images that only exceed one breakpoint, e.g. 400–800px). Every `<img>` gets explicit `width`/`height` to prevent layout shift (paired with a global `img { height: auto }` so constrained widths keep the aspect ratio), `decoding="async"`, and lazy-loading — except the single-page cover, which loads eagerly with `fetchpriority="high"` as the likely LCP element. AVIF encoding uses Hugo's default quality (no `imaging` override in `hugo.yaml`).

> **Gotcha:** Hugo *extended* can resize AVIF, but two upstream PaperMod templates don't process it out of the box, so both are overridden here:
> - `cover.html` — its hardcoded `$processableFormats` list omits `avif`; the override appends it.
> - `figure.html` — the stock shortcode emits a plain `<img>` with no resizing; the override resolves `src` as a page resource and uses the `responsive-img` partial (falling back to a plain `<img>` for external/static sources, and keeping the `#center` centering fragment).
>
> If you re-pull either file from the theme, re-apply these (see the PaperMod-update notes below) or those images silently fall back to full-size, unsized downloads.

**Bundle resources publish only when invoked.** `build.publishResources` is `false` site-wide (see the comment in `hugo.yaml`), so Hugo no longer copies unreferenced originals into `public/`. Any template that references a page-bundle file must resolve it (`.Resources.Get`/`GetMatch`) and invoke `.RelPermalink`/`.Permalink` — never build the URL as a string, or the file won't be published. `scripts/preflight.sh`'s reference scan catches violations.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/newpost.sh` | Scaffold an article (`--cover` optional), review, or quote |
| `scripts/add-images.sh` | Add images to a post bundle: `--cover` → AVIF + OG JPEG; body → AVIF only, prints figure snippets |
| `scripts/preflight.sh` | Pre-push gate: build + warnings, CSP check, offline link check, published-reference scan (`--strict` fails on warnings) |
| `scripts/to-avif.sh` | Convert images to AVIF + JPEG (for OG images); `--og-only` re-optimizes the OG JPEG without touching the AVIF |
| `scripts/archive-links.sh` | Check all posts for dead links and replace with Wayback Machine snapshots |
| `scripts/csp-hashes.sh` | Regenerate / verify Content Security Policy hashes (inline styles *and* scripts) after Hugo or PaperMod updates |
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

**3. Check the most likely conflict files**

Diff each override against its updated PaperMod source:

```sh
diff themes/PaperMod/layouts/_partials/cover.html layouts/_partials/cover.html
diff themes/PaperMod/layouts/_shortcodes/figure.html layouts/shortcodes/figure.html
diff themes/PaperMod/layouts/_partials/header.html layouts/_partials/header.html
diff themes/PaperMod/layouts/_partials/home_info.html layouts/_partials/home_info.html
diff themes/PaperMod/layouts/_partials/head.html layouts/_partials/head.html
diff themes/PaperMod/layouts/_partials/templates/opengraph.html layouts/_partials/templates/opengraph.html
diff themes/PaperMod/layouts/baseof.html layouts/baseof.html
```

For each diff: if PaperMod changed unrelated lines, copy their new version and re-apply the change noted below. If they changed the same lines, merge manually.

- `layouts/_partials/cover.html` — `($cover | fingerprint).RelPermalink` instead of `.Permalink`; and `avif` appended to `$processableFormats` so AVIF covers get responsive variants (see [Images](#images))
- `layouts/shortcodes/figure.html` — resolves `src` to a page resource and uses the `responsive-img` partial for the AVIF `srcset` + `width`/`height` (see [Images](#images)); always emits `alt` (never copied from the caption) and warns at build when both are missing; the stock shortcode does no image processing
- `layouts/_partials/header.html` — the header logo uses a processed local resource with `.RelPermalink` so it stays crisp on high-DPR screens without hard-wiring production URLs into local or preview builds
- `layouts/_partials/home_info.html` — the home avatar resolves `imageUrl` as a resource and emits 1x/2x fingerprinted AVIF variants (`$img.Resize … | fingerprint`, `.RelPermalink`); also adds the microformats2 `h-card` markup (see [Images](#images))
- `layouts/_partials/head.html` — uses the stored list paginator to self-canonicalize paginated list pages and emit `rel=prev`/`rel=next`
- `layouts/_partials/templates/opengraph.html` — jpeg OG companion lookup and `site.Language.Lang`
- `layouts/baseof.html` — `.home` class on body for home page, `.Language.Direction`, and early list-paginator storage for `<head>` metadata

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
- [Newsreader](https://fonts.google.com/specimen/Newsreader) by Production Type ([SIL Open Font License](https://openfontlicense.org/)) — the self-hosted serif used for body and heading type (`static/fonts/`, declared in `assets/css/extended/fonts.css`).

## License

Content is licensed [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
