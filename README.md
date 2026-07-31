# JaredEberle.org

Source for [jaredeberle.org](https://jaredeberle.org), the personal and academic site of Jared L. Eberle.

Built with [Hugo](https://gohugo.io). The site began as a PaperMod fork but is now a fully local theme: templates, styles, scripts, and publishing workflow all live in this repo.

## Prerequisites

- [Hugo](https://gohugo.io/installation/) extended edition
- [ImageMagick](https://imagemagick.org/) (`magick`) for image helpers
- [Node.js](https://nodejs.org/) / npm for HTML/CSS/accessibility checks
- [Lychee](https://lychee.cli.rs/) for optional link checking

## Local Development

```sh
hugo server
```

The site is available at `http://localhost:1313`.

## Repo Layout

| Path | Purpose |
|---|---|
| `content/` | Published site content |
| `content/sources/` | One page per cited work, keyed by citation key; the bibliography, reading ledger, and connection hubs |
| `layouts/` | Hugo templates and shortcodes |
| `assets/` | CSS and JavaScript |
| `scripts/` | Authoring, build, and maintenance helpers |
| `docs/` | Operational and workflow documentation |

Obsidian only runs against the `~/Notes` vault, synced via Obsidian Sync — this
repo has no `.obsidian/` setup of its own. Drafts live at `~/Notes/04 Blog/Drafts/`
(override with `WEBSITE_DRAFTS_DIR`), outside the repo, until
`scripts/publish-draft.sh` moves them into `content/`. The Templater draft
templates live solely at `~/Notes/Meta/templates/Website/`; there is no repo
copy, so edit them there directly.

## Daily Commands

```sh
scripts/newpost.sh article "Post Title"
scripts/newpost.sh article --cover "Post Title"
scripts/newsource.sh book "Book Title"           # prefills from Open Library by ISBN
scripts/newsource.sh zotero cramer2005           # prefills from the Zotero library, offline
scripts/finishsource.sh --push egan2023          # mark read, ship, and push
scripts/publish-draft.sh --push articles/2026-06-24-post-title.md      # no images to add
scripts/publish-draft.sh --cite reviews/2026-06-24-review-slug.md      # append Works Cited
scripts/add-images.sh content/articles/<dir> --cover photo.jpg
scripts/ship.sh "Commit message"                 # preflight, commit, push in one step
```

## Documentation

| Document | What it covers |
|---|---|
| [docs/workflow.md](docs/workflow.md) | Content model, draft/publish flow, scripts, shortcodes |
| [docs/images.md](docs/images.md) | Image authoring, responsive output, figure/carousel behavior |
| [docs/reading.md](docs/reading.md) | Reading/source ledger schema, scripts, RSS syndication behavior |
| [docs/metadata-sweep.md](docs/metadata-sweep.md) | The 2026-07 front-matter restructure: schema, vocabulary, per-file record |
| [docs/operations.md](docs/operations.md) | Remotes, CI, deployment, checks, failure behavior |
| [docs/maintenance.md](docs/maintenance.md) | Hugo upgrades, CSP hashes, theme history, repo-specific upkeep |

## Credits

- [PaperMod](https://github.com/adityatelange/hugo-PaperMod) — origin of the vendored Hugo theme base (MIT licensed)
- [Solarized](https://ethanschoonover.com/solarized/) by Ethan Schoonover — original palette inspiration
- [Source Serif 4](https://fonts.google.com/specimen/Source+Serif+4) by Frank Grießhammer / Adobe ([SIL Open Font License](https://openfontlicense.org/))
- [Fraunces](https://fonts.google.com/specimen/Fraunces) by Undercase Type ([SIL Open Font License](https://openfontlicense.org/))
- [IBM Plex Mono](https://fonts.google.com/specimen/IBM+Plex+Mono) by IBM ([SIL Open Font License](https://openfontlicense.org/))

## License

Content is licensed [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
