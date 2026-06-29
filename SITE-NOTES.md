# Site Notes

A maintainer-facing knowledge dump — not a how-to (that's `README.md`), but
the *why* behind the current state of the theme, what's been verified, and
what's still genuinely open. Written after a long audit/build pass; meant to
let a future session (human or Claude) pick up context fast without
re-deriving it from git history.

## Identity and values

- `jaredeberle.org` — personal/academic site for Jared L. Eberle, historian
  of late 20th-century Indigenous activism, lecturer at Oklahoma State.
- Explicit, stated priorities (from `content/about.md`, in his own words):
  privacy (no analytics, no trackers, minimal third-party requests),
  environmental/data efficiency (home page ~0.089g CO₂, biggest page under
  600KB vs. 2-3MB typical), and self-hosting everything feasible (one
  self-hosted font, no CDN dependencies).
- Hard rule, stated in `README.md` and honored throughout: **content under
  `content/` is never edited by Claude** — only the site owner writes that.
  Claude can build templates/CSS/scripts that render content, but never the
  prose, front matter values, or `humans.txt`-style personal statements
  themselves.
- Codeberg is canonical; GitHub is a private CI-only mirror with no deploy
  secrets.

## Architecture provenance

- Originally a fork of the Hugo theme **PaperMod**. The `themes/PaperMod`
  submodule was fully removed and every file vendored directly into this
  repo — there is no upstream to diff against anymore. `git log`/`git blame`
  are the way to understand any given file now, not a theme comparison.
- `assets/css/base/` = the vendored-then-owned former PaperMod core CSS,
  consolidated from PaperMod's old `core/`+`common/` split into one
  directory with numeric filename prefixes (`00-`, `01-`, `10-`...`20-`,
  `90-`) that encode concatenation order for a single `resources.Match
  "css/base/*.css"` glob.
- `assets/css/extended/` = local customizations, loaded after `base/` via
  alphabetical glob order. This is the actual design layer; `base/` is
  closer to a "PaperMod defaults" reference layer now.
- Six PaperMod-era shortcodes were deliberately dropped during the fork
  (audio, inTextImg, ltr, rtl, rawhtml, video) as dead weight; `collapse`
  was the one judged possibly useful later and is the only one not
  fully removed (kept available, unused).
- `disableSpecial1stPost`, `translations` i18n key, and several
  PaperMod-only CSS selectors (`.gist`, `.highlighttable`, `.linenodiv`,
  `.lang-menu`, `.logo-switches`, `.nav-sep`, `.i18n_list`, `.breadcrumb`
  singular) were confirmed completely dead (zero markup references) and
  removed in a later cleanup pass.

## Typography history

- Body/heading serif: **Newsreader → Literata → Source Serif 4**, in that
  order, across this project's lifetime.
- The driver each time was `onum` (OpenType oldstyle figures) support.
  Newsreader was confirmed via direct binary inspection (fontTools, not
  reputation/hearsay — an online claim that its TTF had `onum` was checked
  and found false) to have **never** had `onum` in any released version.
- Literata and Source Serif 4 were the two closest matches found among
  Google Fonts serifs with real `onum` support and a comparable
  weight/optical-size variable-font structure. Literata shipped first;
  Source Serif 4 replaced it after a live side-by-side preview, because it
  reads more restrained/classic-book for a citation-heavy academic site.
- `font-variant-numeric: oldstyle-nums proportional-nums` in `serif.css` was
  a dormant rule for a long time (no font backing it) before Literata made
  it meaningfully active; it's now backed by Source Serif 4.
- `hanging-punctuation: first` is deliberately Safari/iOS-only (silently
  ignored elsewhere) and is explicitly turned back **off** on blockquotes
  (`.post-content blockquote { hanging-punctuation: none; }`) so it doesn't
  pull the blockquote's first-line quote-mark indent into the margin. As of
  this writing there is **no top-level body paragraph** in any published
  post that opens with a quotation mark — the only places the effect can
  currently be seen are inside footnote citations (small text). Confirmed
  working correctly when manually tested by temporarily converting a
  blockquote to a plain paragraph (then reverted).
- Meta/"furniture" text (dates, breadcrumbs, tags, nav, footer) uses a
  system sans stack (`--meta-font`), deliberately distinct from the serif
  body — this is a real design line, not an oversight, and it's now bug-free
  (see Cascade bugs below).

## Color system

- `00-tokens.css` keeps the full 16-color Solarized palette (Ethan
  Schoonover) as a documented "heritage reference," even though only
  `--yellow`, `--cyan`, and `--base03` are actually consumed downstream.
  This is intentional, not dead code to prune.
- The live palette ("Prairie") is warmer/earthier than Solarized: field
  paper, wheat panel, sage-gray text, clay links, ochre quote marks.
- Dark mode is **deliberately not Solarized dark** — it falls back to a
  neutral gray dark (PaperMod's old defaults, now just hardcoded in
  `base/00-theme-vars.css`) because Solarized dark read too warm/low-contrast
  for long-form reading. Only links/accent/rule/quote-rule are
  re-themed for dark, via `color-mix()`, in Solarized cyan/yellow.
- Every text/background pair in both themes has been computed (not just
  eyeballed) against WCAG: all pass AA (4.5:1+), most pass AAA. Tightest
  margins are dark-mode link-on-card (4.81:1) and light-mode meta-on-card
  (4.53:1) — both deliberately tuned to just clear AA per the `00-tokens.css`
  comment, confirmed accurate by independent calculation.
- Decorative `hr`/divider contrast (~2.2–2.5:1) is below the 3:1 non-text
  guideline but exempt — WCAG 1.4.11 doesn't apply to purely decorative
  dividers, same logic as decorative images being alt-exempt.

## Content model

- Sections: `articles`, `reviews`, `quotes` (the three in `mainSections`,
  i.e. what appears in archives/feeds/prev-next), plus `courses` and `cv`
  outside that set. `quotes` are flat files (no bundle, no images); the
  rest are page bundles.
- Courses are slugged by catalog number (`content/courses/3793/` etc.), not
  by title — intentional, matches how the university catalogs them.
- **Series support**: `series` is a real taxonomy (`hugo.yaml`), same status
  as `categories`/`tags`. Set `series: "A Series Name"` in front matter on
  every part — a **natural display name**, not a hyphenated slug; Hugo
  title-cases each word of a taxonomy term but doesn't turn hyphens into
  spaces, so a slug-style value renders as the literal ugly "My-Summer-
  With-Claude" instead of "My Summer With Claude." Same convention as
  tags/categories, which are already written as natural strings (`"Indigenous
  History"`, not `indigenous-history`).
  `layouts/_partials/series_nav.html` reads `.GetTerms "series"`, orders the
  term's pages by date, and renders a "Part X of N" block with links to
  every part, right under the post description. No-op if the field is
  absent or the series has only one member. Being a taxonomy also means:
  `/series/` and `/series/<term>/` browse pages exist automatically (same
  generic `taxonomy.html`/`list.html` used by tags/categories), and
  `templates/opengraph.html`'s `og:see_also` block — written assuming this
  taxonomy would exist, dead until now — is live.
  Currently set on `content/articles/2026-06-24-my-summer-with-claude-pt-1-maintenance/`
  with value `series: "My Summer With Claude"`. Future parts need the same
  value added by hand.
- Reviews can carry `reviewed_*` bibliographic fields; quotes can carry
  `source_*` fields. Both render via the shared `post_context.html` partial,
  which `series_nav.html` deliberately mirrors visually (same
  `.post-context`/kicker-label pattern).
- **Hero image as LCP** (authoring convention): when a post hides its
  single-view cover (`cover.hiddenInSingle: true`) but opens the body with
  that same image, mark the image eager so it isn't lazy-loaded as the LCP.
  The attribute list goes on its **own line** directly beneath the image,
  never same-line:

  ```markdown
  ![alt text](cover.avif)
  {loading="eager" fetchpriority="high"}
  ```

  Same-line `![](x){…}` silently does nothing (see the round-2 LCP note in
  the verification ledger for the mechanism). Currently applied to three
  posts (tulsa-in-1918, vanishing-americans, bob-engelharts). These in-body
  attribute tags are rendering directives, not prose or front matter — and
  they are the one place Claude has touched files under `content/`, added
  with the owner's sign-off; the "Claude never edits content" rule otherwise
  stands.

## Verification ledger (what's actually been confirmed, not assumed)

Performance, SEO, structured data:
- PageSpeed Insights: **100/100** all categories, mobile and desktop.
- The one PSI diagnostic (render-blocking CSS) is the deliberate
  `rel="preload stylesheet"` single-bundle pattern — intentional, avoids
  FOUC, costs nothing in the actual score.
- Google Rich Results Test: clean. The one "optional" flag (missing
  `author.url` on `BlogPosting`) was fixed — every post's author Person
  object now links to the homepage, matching the site-level Person schema.
- `BreadcrumbList` JSON-LD validated structurally correct, including for the
  numeric-slugged course pages.
- Live response headers (confirmed via direct `curl` against the deployed
  site) match `static/_headers` byte-for-byte — statichost.eu applies CSP,
  HSTS, Permissions-Policy, etc. exactly as committed, no drift.

Dead code / cascade correctness:
- A full selector-by-selector, key-by-key audit (custom script comparing
  every CSS file in actual cascade order) found and removed: 9 dead CSS
  selectors, 1 dead i18n key, 1 dead Hugo config param.
- Found and fixed **three real same-specificity cascade bugs** in
  `meta.css` where a later catch-all `font-family: inherit` rule was
  silently overriding earlier, intentional `font-family: var(--meta-font)`
  declarations — nav, the entire site footer, and archive-filter pills were
  all quietly rendering serif instead of the intended sans. Root cause and
  fix documented in `meta.css`'s own comments now.
- Re-ran the cascade-conflict script after every fix; zero genuine
  extended-vs-extended conflicts remain (only the intentional, by-design
  base-vendor-vs-local-override pattern, which is *supposed* to differ).

Accessibility:
- Keyboard-only navigation manually walked through and confirmed in both
  **Firefox and Safari** (desktop) — skip link, nav, theme toggle, search,
  archive filters, carousel arrow keys, lightbox focus-trap + escape +
  focus-return, footnote popovers, TOC.
- (Safari note: Tab not reaching page content is a macOS Safari *default*,
  not a bug — needs Safari → Settings → Advanced → "Press Tab to highlight
  each item on a webpage," sometimes also System Settings → Keyboard →
  Keyboard Navigation.)
- Real mobile device (touch): carousel swipe, lightbox tap, archive filter
  taps, theme toggle tap all confirmed working.
- **VoiceOver screen-reader pass has NOT been done.** This is the one
  manual-accessibility item still genuinely open — rotor/heading navigation,
  alt-text quality (not just presence), ARIA announcements on the lightbox
  modal/footnote popovers/archive-filter pressed-state/search input label.
- Automated a11y (axe via `npm run test:axe`) passes, but is known to only
  catch roughly half of real-world WCAG issues — it does not substitute for
  the VoiceOver pass above.

Cross-browser/format risk (the two things in this codebase that could
*actually* break on an old browser, everything else is safe no-op
progressive enhancement):
- **AVIF images have zero fallback format** (no `<picture>`/JPEG fallback
  for in-body/figure/carousel images; covers get a JPG companion but only
  for OG-crawler purposes). Confirmed rendering fine in real Safari and
  Firefox. Low risk given AVIF's now multi-year-old broad support, but
  worth remembering if a very old browser ever gets reported as seeing
  blank images.
- **`color-mix()`** drives dark-mode link/accent/rule colors. Confirmed
  rendering correctly in real Safari and Firefox dark mode.
- `text-wrap: pretty`, `text-wrap: balance`, `hanging-punctuation: first`,
  and the CV's `:has()` selector are all confirmed-by-design graceful
  no-ops on unsupported browsers — not a real risk.

Bugs found and fixed during this audit (not pre-existing knowledge — found
by actually visiting pages, not just reasoning about the code):
- **404 page**: `base/10-404.css` sets `font-size: 160px; font-weight: 700`
  on the `.not-found` *container*; the local override reset it for the `h1`
  and the message `<p>`, but never for the helpful-links `<nav>`, so "Home /
  Articles / Reviews / Courses / Search" rendered at 160px and overlapped
  the header. Fixed in `extended/404.css`.
- **Paginated list pages**: the last entry's `border-bottom` divider sat
  flush against the "« PREV / NEXT »" pagination control with zero gap
  anywhere defining `.page-footer` margin. Fixed with `margin-top:
  var(--gap)` (correctly responsive — 24px desktop, 14px under the 768px
  mobile breakpoint where `--gap` itself shrinks).
- **Lighthouse a11y nits** (PageSpeed flagged a few non-100 pages):
  - *Links rely on color* → the footnote back-link arrow (`.footnote-backref`)
    had `text-decoration: none` and sits in the footnote text block. Now
    underlined. Uncovered a same-specificity cascade bug while there: its
    `color: var(--secondary)` was always dead — `prose.css`'s
    `.md-content a:not(.anchor)` ties at (0,2,1) and loads later, so the
    backref has always rendered clay (`--link`), not the muted secondary the
    old comment claimed. Left it clay (matches every other link), removed the
    dead declaration, fixed the comment. *(If the original "quiet/muted"
    intent is preferred, bump specificity with `.footnotes` — flagged, not
    done.)*
  - *Touch targets too small* → carousel dots were 8×8px; now a 24×24px hit
    target wrapping an 8px visual dot drawn with `::before` (gap dropped to 0
    so the visible dots stay grouped). The carousel prev/next buttons were
    already ~45px and fine; carousel images are excluded from the lightbox
    (`lightbox.js:66`) so there's no overlapping-target issue.
  - *Touch targets too small* → `.related-posts-list`/`.series-nav-list`
    links were ~23.5px tall stacked; now `inline-block` + `padding-block:
    0.2rem` → 30px. (Series-nav wasn't Lighthouse-flagged only because no
    2-part series exists yet to render it — fixed pre-emptively since it's
    structurally identical.) `.post-tags` deliberately left alone: it's an
    inline comma-separated keyword line, which is the WCAG 2.5.8 inline-text
    exemption — making those block targets would break the design.
  - *Improve image delivery / properly size images* → the cover `<img>`
    (`cover.html`) hardcoded `sizes="(min-width: 768px) 720px, 100vw"`, but
    a single-page cover is a floated **220px** book-jacket (`cover.css`),
    unfloating to full width only at ≤640px; list covers are
    `min(100%, 520px)`. So the browser fetched a 720/800w candidate for a
    ~210px slot. `sizes` is now context-aware via `$.IsSingle`:
    `(max-width: 640px) 100vw, 220px` for single, `(max-width: 520px) 100vw,
    520px` for list. Verified: a desktop single cover that previously pulled
    the 800w original now fetches the 480w candidate (360w at 1×). The
    `width`/`height` attrs stay the intrinsic dimensions (for CLS); only the
    `sizes` hint changed.
  - *LCP image lazy-loaded / no fetchpriority* (category & section list
    pages) → every list cover was `loading="lazy"` with no fetchpriority,
    including the first one, which is usually the LCP element on desktop.
    `cover.html` now takes an `isFirst` flag and gives that cover
    `loading="eager"` + `fetchpriority="high"` (the rest stay lazy).
    `list.html` precomputes the index of the first entry with a *visible*
    cover — skipping entries whose cover is hidden in lists (reviews) or
    absent — so a mixed article/review page primes the real first image, not
    blindly entry 0. Verified exactly one eager/high cover per page (zero on
    all-review lists). Home page is unaffected — `home_sections.html` renders
    text-only entries, no cover images, so its LCP is text.
  - *Properly size images, round 2* (in-content figures & carousel) →
    `responsive-img.html` (shared by the markdown image hook, the figure
    shortcode and the carousel) had drifted from the actual layout: its
    `sizes` claimed `720px`, its `src` fallback `800`, and its candidate
    widths were `400 800 1200` — but the content column is **680px**
    (`serif.css` overrides `--main-width` from the PaperMod base 720 to 680).
    With no candidate near 680, a full-width 800px-source figure/slide was
    served at 800w for a 680px slot at 1× desktop. Fixed by aligning the
    helper to the real column: widths `400 680 800 1200` (680 added), `sizes`
    `…680px`, `display` fallback `680`. Now a 1× desktop full-width image
    fetches the 680w candidate; 800w/1200w remain for 2×/3× and mobile. This
    is the single source of truth, so every figure, carousel slide and inline
    image benefits. (The earlier *round 1* covered the cover `<img>`, which
    has its own `sizes` in `cover.html` and is unaffected by this helper.)
  - *LCP image lazy-loaded, round 2* (single posts whose cover is hidden in
    single view) → measured real LCP elements with a `PerformanceObserver`
    across the home page, a text post, and a cover post: home/text-post LCP
    is always the first body paragraph (weight 400, already preloaded — the
    weight-600 heading face never wins, it's always smaller in area than the
    body block beneath it, so a second font preload would help nothing and
    would only contend with the cover image's bandwidth). But on the three
    posts that set `cover.hiddenInSingle: true` and open the body with that
    same image as a Markdown `![]()`, the *visible* LCP image was
    `loading="lazy"` with no fetchpriority — `render-image.html` hardcoded
    `lazy` for every in-content image, with no escape hatch. Fixed by
    enabling Goldmark `parser.attribute.block` +
    `wrapStandAloneImageWithinParagraph: false` (`hugo.yaml`) so a standalone
    image can carry a trailing attribute list, and fixing a merge-order bug
    in `render-image.html` so author attributes now win over the lazy
    default instead of being silently clobbered. See the authoring
    convention under Content model above (own-line attribute syntax is
    required; same-line is silently swallowed by Goldmark). Verified via
    `npm run validate` (zero html-validate problems across all 185 pages
    after the side effect of unwrapping standalone images from their `<p>`
    — `.md-content img` carries its own margin/radius, so this changed no
    rendering) and in-browser (all three posts: eager + high fetchpriority,
    no `<p>` wrapper, no leaked `{…}` text, title-attribute tooltip on the
    Bob Engelhart image preserved).
  - *Review-meta rules ran into the floated cover* → on review single pages
    with `cover.hiddenInSingle: false`, the bibliographic meta block
    (`.post-context-review`) flowed under the floated 220px cover rather
    than beside it, so its top/bottom rules spanned the full content column
    and visibly crossed the cover photo. Fixed with `display: flow-root` on
    `.post-context-review`, giving it its own block formatting context so
    it narrows to sit beside the float instead of under it. Inert below the
    640px breakpoint where the cover unfloats (verified: box is full column
    width there, same as before). Quote-source variant
    (`.post-context-source`) untouched — it doesn't share a page with a
    floated cover in the same way.
  - *Layout shift, every page* → the self-hosted Source Serif 4
    (`fonts.css`) uses `font-display: swap` with no metric-matching, so
    every page reflows once when the web font replaces the Georgia fallback
    (different fonts, different glyph widths → different line-wrap points →
    different paragraph height). Fixed with a `'Source Serif 4 Fallback'`
    proxy `@font-face` (`src: local('Georgia'), …`, no network fetch) given
    `size-adjust`/`ascent-override`/`descent-override`/`line-gap-override`,
    inserted into the `body` font stack between `'Source Serif 4'` and
    plain `Georgia` (`serif.css`). The `size-adjust` value was measured
    empirically in a real browser (render the same sentence in both fonts
    at a fixed size, compare pixel widths: Source Serif 4 ≈4.06% wider) —
    **not** taken from either font's OS/2 table, after the two standard
    table-based formulas (`xHeight` ratio vs. `xAvgCharWidth` ratio)
    disagreed by 30 points; `xAvgCharWidth` is a known-unreliable field
    across font vendors and would have shipped a visibly wrong scale.
    Verified by forcing `.post-content` to the fallback face and the real
    web font in turn and diffing `getBoundingClientRect().height` on a real
    article — **0px delta** (was effectively the size of the swap-shift
    before the fix). ascent/descent/line-gap-override matter less than
    usual here since body `line-height` is a fixed `1.7` multiplier
    (font-metric-independent), not `normal` — they're included anyway for
    correctness in inline/baseline contexts where it does matter, computed
    from Source Serif 4's own OS/2 typo ascent/descent/line-gap divided by
    the size-adjust factor. Headings inherit `body`'s font-family (no
    separate declaration), so they're covered automatically.

## New features added this pass

- **Print stylesheet** (`assets/css/extended/print.css`, new file): hides
  all on-screen-only chrome (nav, footer, skip-link, archive filters,
  pagination, theme toggle, TOC, carousel controls, the CV's redundant
  "Download PDF" link), forces a light/ink-efficient palette regardless of
  which theme was active on screen (so dark mode never prints dark, and the
  always-dark code-block background doesn't print as a giant black
  rectangle), and shows every carousel slide stacked instead of just the
  active one. Also hides `.related-posts` (cross-page nav, useless on
  paper, same logic as `.paginav`) while deliberately keeping `.series-nav`
  ("Part 2 of N" is meaningful printed context). Verified by code-level
  reasoning about cascade order/specificity (no print rendering tool was
  available to screenshot it directly) — worth a real Cmd+P sanity check on
  the CV page next time you're near it.
- **Series navigation** — see Content model above.
- **Adaptive `theme-color`**: `head.html` previously emitted one static
  `<meta name="theme-color" content="#2e2e33">` always — fine in dark mode,
  wrong in light mode, where mobile browser chrome (Safari address bar,
  Android Chrome) rendered dark gray above the warm cream light-mode page.
  Now two `media`-scoped tags (`#f6edd8` light / `#1d1e20` dark, matching
  `--theme` exactly in both palettes) so the chrome always matches. The PWA
  manifest's `theme_color` stays a single static value — manifests don't
  support per-scheme values, and that one only paints the installed-app
  icon/splash, not live browser chrome.
- **Site-default OG/Twitter share image**: text-only posts and all `quotes`
  (flat files, no images) previously got a card with **no image at all** —
  `opengraph.html`/`twitter_cards.html` only tried the post's cover, then
  any in-body image, then gave up. `site.Params.images` (`assets/images/
  card.jpg`, 1000×688) already existed for exactly this purpose — visible
  in a comment in `rss.xml` describing it as "the OG card" — but nothing
  actually read it. Both templates now fall back to it as a final tier.
- **Related posts**: `layouts/_partials/related_posts.html` uses Hugo's
  built-in `.Related` against pages in `mainSections`, with `related:` in
  `hugo.yaml` restricted to the `tags` index only (Hugo's default config
  also scores by keyword/date proximity, which would surface undated
  coincidences as "related" with no actual topical overlap — not wanted
  here). Up to 3 results, ranked by shared-tag count, no-op if nothing
  shares a tag. Sits in the post footer, after the tags block and before
  the prev/next chronological nav, reusing the same `.post-context` kicker
  styling as series-nav/review-context. Verified against real content
  (e.g. "Dennis Banks FBI File" correctly surfaces 3 other 1970s/AIM-tagged
  posts, ranked by shared-tag count) — not committed yet, built for you to
  inspect first.

## Explicitly declined (with reasoning, so it isn't re-litigated by accident)

- **OpenSearch description** — said no, not relevant at this site's scale.
- **Service worker / offline PWA support** — would add real
  cache-invalidation maintenance burden for a site whose own stated goal is
  staying minimal and fast; not worth it against a speculative benefit.
- **Citation export (BibTeX/RIS)** — bigger feature than it looks (needs
  structured per-post citation metadata) for a speculative benefit; not
  ruled out forever, just not done.
- **Webmentions** (showing replies/likes from Bluesky or the fediverse on a
  post) — considered and dismissed by the site owner. Receiving them would
  either mean loosening the CSP to bring in Micro.blog (the actual
  fediverse setup in use) or relying on a generic webmention-receiving
  service whose data would just go stale. Neither is worth it.

## Open / pending — for you to decide, not done

- **VoiceOver screen-reader pass** — see Accessibility above. Only
  remaining manual-testing gap.
- **"As of [date]" / last-reviewed disclaimer for older historical posts**
  — raised once, but you noted the existing `Lastmod`/"Updated [date]" line
  already shown on every post's footer covers this. Considered resolved,
  no action needed.
- **Footer's PaperMod credit line** — was flagged as possibly stale; you
  already edited `hugo.yaml`'s `params.footer.about` yourself to drop "and
  PaperMod," independent of any Claude edit. Resolved.
- **`profileMode` dead code deleted** — `site.Params.profileMode.enabled`
  was never set in `hugo.yaml`, so `layouts/_partials/index_profile.html`,
  `assets/css/base/18-profile-mode.css`, and the profile-only lines in
  `90-zmedia.css` (`.profile img`, `.button:active`) were unreachable.
  Removed the dead `{{ if }}` branch from `list.html` and deleted both
  files. A follow-up full-codebase sweep (config-gated feature flags,
  orphaned partials/shortcodes/JS, i18n keys, every CSS class selector,
  unreferenced static assets) found nothing else in this class — verified
  clean across the board, this was the one real remnant.
- **`.searchResults` camelCase naming** — vendored PaperMod name, still tied
  to matching JS/templates (`fastsearch.js`, `search.html`). Now that
  PaperMod has no upstream to stay compatible with, a rename to kebab-case
  is a safe, optional, coordinated cleanup across those files whenever you
  want it. Low priority — not done.

## Maintenance reminders (not new — carried forward from `README.md`, restated here for completeness)

- After upgrading Hugo locally: run `scripts/sync-hugo-version.sh`, then
  `scripts/csp-hashes.sh --check` (a changed minifier can silently break CSP
  hashes — the failure mode is a console-only CSP error, easy to miss).
- `scripts/archive-links.sh --all` periodically for dead outbound links
  (also runs on a CI schedule via lychee).
- Any new content section needs three things: `mainSections` in
  `hugo.yaml`, a cache rule in `static/_headers`, and (optionally) a home
  page column in `layouts/list.html`.
- `static/fonts/OFL.txt` must match whichever font is currently live
  (currently Source Serif 4 / Adobe) — verified correct as of this writing,
  but worth checking again if the body font ever changes again.
- **Only the `latin` subset of Source Serif 4 is shipped** (the `latin-ext`
  files were deleted, −206 KiB / 4 files). Audited every non-ASCII character
  actually used in `content/` and confirmed all of it — including Western
  European accents (Spanish/French/German/Italian/Portuguese: á é í ó ú ñ ü
  ç è à) — falls inside Latin-1 Supplement (U+0000–00FF), which the base
  `latin` subset already covers. `latin-ext` is for a different language
  group entirely (Polish/Czech/Croatian/Romanian/Turkish/Vietnamese/Baltic)
  that isn't a goal for this English-only site, and confirmed via the
  network panel zero requests for it ever fired. If a future post needs a
  glyph outside Latin-1 (e.g. a Polish ł or Czech č in a quoted name), it'll
  silently render in the metric-matched fallback face instead of Source
  Serif 4 — an accepted trade-off, not a bug, given the stated scope.
- **stylelint** (`.stylelintrc.json`, extends `stylelint-config-standard`) runs
  in `npm run validate` and as a step in `scripts/preflight.sh --full`/CI. Four
  rules are tuned, each backed by a real false-positive found when first
  auditing the codebase, not a blanket preference:
  - `no-descending-specificity` — off. Every hit was the standard "general
    rule, then a more specific exception" pattern (e.g. `.md-content ol` then
    `.md-content ol:not(:last-child)`), which is this codebase's intentional
    base→extended override architecture, not a cascade bug.
  - `selector-class-pattern` — kebab-case + an optional BEM `--modifier`
    suffix, plus one literal exception (`searchResults`): a PaperMod-vendored
    class name also referenced by matching JS/templates (`fastsearch.js`,
    `search.html`), so renaming the CSS alone would break the feature. (A
    second exception, `profile_inner`, was removed along with the rest of
    the dead `profileMode` feature — see below.)
  - `property-no-vendor-prefix` — ignores `-webkit-text-size-adjust` and
    `-webkit-appearance` specifically; both are paired with their standard
    unprefixed sibling already and exist for real Safari/iOS gaps the
    standard property doesn't fully cover.
  - `value-keyword-case` — `camelCaseSvgKeywords: true` (so
    `text-rendering: optimizeLegibility` isn't flagged) and ignores
    `--meta-font` (a custom property holding a font stack; the rule can't
    tell it's not a generic keyword list and was lowercasing
    `BlinkMacSystemFont` — a Blink-internal sentinel token, not a real font
    name, risky to lowercase since no source confirms it's matched
    case-insensitively).
  Three genuinely intentional same-name reuses remain and are silenced inline
  with `stylelint-disable-next-line` + a reason comment rather than a config
  exception, since they're one-off: the heritage-vs-live `:root` token blocks
  in `00-tokens.css`, and the `.yt-facade`/`.bsky-facade` selectors repeated
  across separate thematic rule blocks in `embeds.css`.
