# JaredEberle.org

Source for [jaredeberle.org](https://jaredeberle.org), the personal and academic site of Jared L. Eberle — historian of late 20th century Indigenous activism and lecturer at Oklahoma State University.

Built with [Hugo](https://gohugo.io). This site began as a fork of the [PaperMod](https://github.com/adityatelange/hugo-PaperMod) theme, but it is now a fully local theme: every template and stylesheet lives in this repo (see [Credits](#credits)).

**Note**: I had Claude write this to document what was created and where to look for issues in the future. Anything on [my site](https://jaredeberle.org) is written solely by me, Claude is banned from making any edits to content itself.

The colors for the site were originally utilizing Ethan Schoonover's [Solarized](https://ethanschoonover.com/solarized/) palette but I've since moved towards a theme based around subtly invoking the Oklahoma red dirt prairies at sunrise or sunset with deeper earthy tones

## Prerequisites

- [Hugo](https://gohugo.io/installation/) (extended edition, see version in `statichost.yml`)
- [ImageMagick](https://imagemagick.org) (`magick`) for `scripts/to-avif.sh` / `scripts/add-images.sh`
- [Node.js](https://nodejs.org/) / npm for HTML validation and rendered axe checks (`npm ci`)
- [Lychee](https://lychee.cli.rs) for link checking (optional; `scripts/preflight.sh` skips it when absent)

## Local Development

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
| `content/quotes/` | Short quote posts |
| `drafts/` | Obsidian-only draft workspace, synced by Obsidian Sync and ignored by Git |

Published posts follow the naming convention `YYYY-MM-DD-slug/index.md` (articles and reviews are page bundles; quotes are flat files). Create ignored drafts from the CLI with `scripts/newpost.sh`, or use the Obsidian templates in `_templates/` to write first in `drafts/`. Draft front matter is timestamped in the site's local timezone (`America/Chicago`) so feeds don't shift posts backward a day.

## Publishing workflow

```sh
scripts/newpost.sh article "Post Title"           # create ignored draft (article|review|quote)
scripts/newpost.sh article --cover "Post Title"   # skip the cover prompt and add cover metadata
                                                  # articles/reviews prompt for optional covers
                                                  # quotes prompt for optional external_url
scripts/publish-draft.sh drafts/articles/2026-06-24-post-title.md
                                                  # publish an Obsidian draft:
                                                  #   articles/reviews -> page bundles
                                                  #   quotes -> flat files
scripts/add-images.sh content/articles/<dir> --cover photo.jpg   # cover.avif + OG cover.jpg
scripts/add-images.sh content/articles/<dir> img1.jpg img2.png   # body images → AVIF only
scripts/preflight.sh && git push                  # pre-push gate, then push to Codeberg + GitHub
```

Obsidian drafts live under `drafts/articles/`, `drafts/reviews/`, and `drafts/quotes/`. The folder is intentionally ignored by Git so drafts can sync through Obsidian Sync without appearing in commits. The Obsidian templates ask for optional metadata, omit blank fields, and ask whether article/review drafts should include a cover block. `description` is the canonical public and SEO blurb; `summary` is only written when you want a different list/feed teaser. When a draft is ready, run `scripts/publish-draft.sh` with the draft path; the script moves it into the proper Hugo section, changes `draft: true` to `draft: false`, and stamps `publishDate` plus `lastmod` with the local publish time when those fields are absent so RSS and JSON feeds sort the post by when it actually went live.

Reviews can carry optional bibliographic context with `reviewed_type`, `reviewed_title`, `reviewed_author`, `reviewed_publisher`, and `reviewed_year`. Quote posts can carry optional source context with `source_title`, `source_author`, and `source_year`. `external_url` links the reviewed/source title in that context line; it does not turn the post title into an outbound link. When present, these fields render beneath the post description on the single-post page.

`preflight.sh` is intentionally lighter locally: by default it runs the
deploy-critical checks (build, content resources, feed lint, CSP drift, and
published-reference scanning). `--strict` also fails on build warnings (e.g.
figures missing alt text). `--full` adds the slower CI-grade checks
(`html-validate`, rendered-content a11y lint, and offline internal-link
checking).

## Remotes and CI

Codeberg is the public canonical remote. GitHub is a private testing mirror used
only for GitHub Actions checks; it has no deploy secrets and the workflow grants
only read access to repository contents.

Configured remotes:

| Remote | Purpose |
|---|---|
| `origin` | Codeberg fetch/push (`codeberg:jle/website.git`) |
| `github` | Private GitHub testing mirror (`github:jleberle/website.git`) |
| `both` | Legacy helper: fetches from Codeberg, pushes to both Codeberg and GitHub |

The local `origin` remote should fetch from Codeberg and carry two push URLs:
Codeberg plus the private GitHub testing mirror. Use plain `git push` for the
normal publishing path after local preflight. If you need a one-off Codeberg-only
push, target the URL directly: `git push codeberg:jle/website.git main`.

GitHub Actions lives in `.github/workflows/site-checks.yml` and runs on pushes to
the private mirror, on manual dispatch, and weekly. Every run executes
`scripts/preflight.sh --strict --full` and `npm run test:axe`. Manual and
scheduled runs also execute the full external lychee link check against the
generated site. Dependabot version updates are configured in
`.github/dependabot.yml` for monthly, grouped npm and GitHub Actions updates.

For scheduled-run failure notices, rely on GitHub's native Actions
notifications on the private mirror rather than issue creation. In GitHub's
notification settings, enable failed workflow run alerts (email or web) for the
repository; the workflow also uploads failure artifacts so the broken build can
be inspected without reproducing it locally.

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

The first three share `layouts/_partials/responsive-img.html` — the single source of truth for breakpoints and the `sizes` hint (sized to the 680px content column), so they can't drift apart. Each smaller variant is only generated when the source is wider than that breakpoint; the original is always included as the largest `srcset` candidate (so a `srcset` is still emitted for images that only exceed one breakpoint, e.g. 400–800px). Every `<img>` gets explicit `width`/`height` to prevent layout shift (paired with a global `img { height: auto }` so constrained widths keep the aspect ratio), `decoding="async"`, and lazy-loading — except the single-page cover, which loads eagerly with `fetchpriority="high"` as the likely LCP element. AVIF encoding uses Hugo's default quality (no `imaging` override in `hugo.yaml`).

> **Gotcha:** Hugo *extended* can resize AVIF, but the original inherited templates didn't process it out of the box, so both were rewritten:
> - `cover.html` — its hardcoded `$processableFormats` list omitted `avif`; this version appends it.
> - `figure.html` — the stock shortcode emitted a plain `<img>` with no resizing; this version resolves `src` as a page resource and uses the `responsive-img` partial (falling back to a plain `<img>` for external/static sources, and keeping the `#center` centering fragment).

**Bundle resources publish only when invoked.** `build.publishResources` is `false` site-wide (see the comment in `hugo.yaml`), so Hugo no longer copies unreferenced originals into `public/`. Any template that references a page-bundle file must resolve it (`.Resources.Get`/`GetMatch`) and invoke `.RelPermalink`/`.Permalink` — never build the URL as a string, or the file won't be published. `scripts/preflight.sh`'s reference scan catches violations.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/newpost.sh` | Create an ignored article (`--cover` optional), review, or quote draft |
| `scripts/publish-draft.sh` | Move an Obsidian draft from `drafts/` into `content/`, preserving page bundles for articles/reviews |
| `scripts/add-images.sh` | Add images to a post bundle: `--cover` → AVIF + OG JPEG; body → AVIF only, prints figure snippets |
| `scripts/preflight.sh` | Pre-push gate: build + warnings, CSP check, offline link check, published-reference scan (`--strict` fails on warnings) |
| `scripts/to-avif.sh` | Convert images to AVIF + JPEG (for OG images); `--og-only` re-optimizes the OG JPEG without touching the AVIF |
| `scripts/archive-links.sh` | Check all posts for dead links and replace with Wayback Machine snapshots |
| `scripts/csp-hashes.sh` | Regenerate / verify Content Security Policy hashes (inline styles *and* scripts) after Hugo updates or template changes |
| `scripts/sync-hugo-version.sh` | Update GitHub Actions and StaticHost Hugo versions to match local Hugo |

Preflight and CI helpers that are not normally called by hand live under
`scripts/checks/`.

## Link checking

Run manually when needed — GitHub Actions also runs lychee on a schedule.

```sh
scripts/archive-links.sh --dry-run --all   # preview
scripts/archive-links.sh --all             # fix
```

## Deployment

The site deploys automatically via [statichost.eu](https://statichost.eu) on every push using the configuration in `statichost.yml`. Hugo runs with `--minify` and outputs to `public/`.

## Maintenance

### After upgrading Hugo locally
Run `scripts/sync-hugo-version.sh` to update the Hugo versions in `statichost.yml` and `.github/workflows/site-checks.yml` to match. The weekly Homebrew job will notify you when Hugo updates — its notification also reminds you to run `scripts/csp-hashes.sh --check`, because a changed minifier can silently invalidate the CSP hashes (see below).

### Theme history

This site no longer tracks PaperMod as a dependency — there is no `themes/`
submodule and no upstream to diff against. The layouts and core CSS/JS under
`layouts/`, `assets/css/base/`, `assets/css/license.css`, and
`assets/js/{fastsearch,fuse.basic.min,license}.js` originated in PaperMod and
were vendored directly into this repo; `assets/css/extended/` and the heavily
modified layouts (`single.html`, `list.html`, `cover.html`, `figure.html`,
etc.) are local rewrites on top of that base. Dead PaperMod-only code (unused
shortcodes, the multi-language `translation_list` partial, the disabled
`comments` hook, etc.) was pruned rather than carried forward once it no
longer needed to stay drop-in compatible with a theme. Treat all of it as
first-class local code — `git log`/`git blame` are the way to understand why
a given file looks the way it does, not a theme diff.

### Content Security Policy hashes

The `Content-Security-Policy` header in `static/_headers` allows the site's inline `<style>` and `<script>` blocks by their exact SHA-256 hashes — there is **no `'unsafe-inline'`** in `script-src` or `style-src`. The hashes cover the bytes Hugo's minifier actually emits, so they break if a template's inline style/script changes **or** Hugo changes how it minifies. When a script hash breaks, the browser silently blocks that script (e.g. dark-mode-on-load or the theme toggle stops working) with only a console CSP error — so verify after upgrades.

Currently hashed scripts: the FOUC theme-on-load setter, the theme toggle, and the menu-scroll / anchor-smooth-scroll handler. The vendored scroll-to-top script is intentionally dropped via `showScrollToTop: false` in `hugo.yaml` so it needs no hash; re-enabling it would require adding its hash.

```sh
scripts/csp-hashes.sh             # build, then print current hashes to paste into static/_headers
scripts/csp-hashes.sh --check     # build, then compare against static/_headers; exit 1 on drift
scripts/csp-hashes.sh --check --no-build   # reuse an existing public/ (used by CI)
```

`--check` reports per directive: `OK` (match), `DRIFT` (a hash is in the build but missing from `_headers` — would be blocked; fails with exit 1), or `WARN` (a stale hash in `_headers` is no longer used — safe to remove). When it reports drift, run `scripts/csp-hashes.sh`, paste the new hashes into **both** CSP blocks in `static/_headers` (the `*` block and the `/iframe-page/*` block), then commit.

GitHub Actions runs `scripts/preflight.sh --strict --full` on every push to the private testing mirror. That includes `csp-hashes.sh --check --no-build`, reusing the `public/` generated by the build. It fails the CI build on drift as a background alarm — note that a failed GitHub Actions run does **not** block StaticHost from deploying from Codeberg, so local preflight remains the hard pre-push gate.
When CI fails, the workflow uploads a short-lived artifact bundle with the generated `public/` directory plus captured `preflight`, `axe`, and external-link logs (when that step ran), so breakage can be inspected away from the local machine.

### Feed checks

`scripts/checks/feed-lint.py` runs inside preflight after Hugo builds. It parses the
generated RSS and JSON Feed files, checks feed-level URLs, and scans syndicated
HTML for relative `href`, `src`, and `srcset` references. This catches feed-reader
portability issues locally without depending on the online W3C validator.

### Rendered accessibility checks

GitHub Actions also runs `npm run test:axe` after preflight. The axe check serves the generated `public/` directory locally and scans representative rendered pages (home, article, review, quote, course, archive, CV, contact, and search). This catches page-level accessibility regressions that source-content linting and HTML validation do not cover.

### Dead link check
Run `scripts/archive-links.sh --all` periodically to find and replace dead outbound links with Wayback Machine snapshots. GitHub Actions' scheduled lychee job will flag broken links in CI.

### Adding a new content type
If you add a new section (e.g. `content/essays/`):
1. Add it to `contentSections` in `hugo.yaml`
2. Add a cache rule in `static/_headers` (`/essays/*/*.avif` etc.)
3. Add it to the home page columns in `layouts/list.html` if desired

## Credits

- [PaperMod](https://github.com/adityatelange/hugo-PaperMod) — the Hugo theme this site's layouts and core CSS/JS originated from (MIT licensed); no longer tracked as a dependency, see [Theme history](#theme-history).
- [Solarized](https://ethanschoonover.com/solarized/) by Ethan Schoonover — the inspiration for the color palette and where dark mode's cyan is pulled from.
- [Fraunces](https://fonts.google.com/specimen/Fraunces) by Undercase Type ([SIL Open Font License](https://openfontlicense.org/)) — the self-hosted display serif used for headings and wordmark (`static/fonts/`, declared in `assets/css/extended/fonts.css`). Body and metadata typography now use system stacks for lighter weight and platform-native rendering.

## License

Content is licensed [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
