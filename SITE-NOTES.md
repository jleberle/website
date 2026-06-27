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
- **Series support** (new): set `series: some-slug` in front matter on every
  part of a multi-post series; `layouts/_partials/series_nav.html` finds all
  pages sharing that value, orders them by date, and renders a "Part X of N"
  block with links to every part, right under the post description. No-op
  if the field is absent or only one post has a given value. Currently set
  on `content/articles/2026-06-24-my-summer-with-claude-pt-1-maintenance/`
  with value `my-summer-with-claude`; future parts need the same value added
  by hand (Claude doesn't touch `content/`).
- Reviews can carry `reviewed_*` bibliographic fields; quotes can carry
  `source_*` fields. Both render via the shared `post_context.html` partial,
  which `series_nav.html` deliberately mirrors visually (same
  `.post-context`/kicker-label pattern).

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

## New features added this pass

- **Print stylesheet** (`assets/css/extended/print.css`, new file): hides
  all on-screen-only chrome (nav, footer, skip-link, archive filters,
  pagination, theme toggle, TOC, carousel controls, the CV's redundant
  "Download PDF" link), forces a light/ink-efficient palette regardless of
  which theme was active on screen (so dark mode never prints dark, and the
  always-dark code-block background doesn't print as a giant black
  rectangle), and shows every carousel slide stacked instead of just the
  active one. Verified by code-level reasoning about cascade order/
  specificity (no print rendering tool was available to screenshot it
  directly) — worth a real Cmd+P sanity check on the CV page next time
  you're near it.
- **Series navigation** — see Content model above.

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

- **Related posts** (by shared tags, at the bottom of articles) — **you
  asked to hold this for your own assessment**, not yes or no yet. Nothing
  built. If you want it: needs a design/placement decision (how many, where,
  by tag overlap or category), then it's a straightforward `where`/`intersect`
  query in `single.html` plus matching CSS — not a big lift once you decide
  the shape of it.
- **VoiceOver screen-reader pass** — see Accessibility above. Only
  remaining manual-testing gap.
- **"As of [date]" / last-reviewed disclaimer for older historical posts**
  — raised once, but you noted the existing `Lastmod`/"Updated [date]" line
  already shown on every post's footer covers this. Considered resolved,
  no action needed.
- **Footer's PaperMod credit line** — was flagged as possibly stale; you
  already edited `hugo.yaml`'s `params.footer.about` yourself to drop "and
  PaperMod," independent of any Claude edit. Resolved.

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
