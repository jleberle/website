# JaredEberle.org

Source for [jaredeberle.org](https://jaredeberle.org), the personal and academic site of Jared L. Eberle.

Built with [Hugo](https://gohugo.io). The site began as a PaperMod fork but is now a fully local theme: templates, styles, scripts, and publishing workflow all live in this repo.

## Setup

```sh
scripts/doctor.sh
```

That checks every program the site needs, says what each one is needed *for*,
and prints the exact install command for anything missing. It exits non-zero
only when something genuinely blocks publishing — most of what it can report is
optional.

Four things are required: [Hugo](https://gohugo.io/installation/) (extended),
Python 3, Git, and [ImageMagick](https://imagemagick.org/). Node and
[Lychee](https://lychee.cli.rs/) are needed only for `preflight --full`, which
CI runs anyway, and GnuPG only for re-signing `security.txt` about once a year.

## Publishing a post

The whole cycle, in order. Every step is one command.

**1. Start a draft.** It is created in the Obsidian vault, outside this repo.

```sh
scripts/newpost.sh article "Post Title"
scripts/newpost.sh article --cover "Post Title"
```

**2. Write it.** In the vault, not here. Nothing in this repo changes yet.

**3. Preview as you go.**

```sh
hugo server           # http://localhost:1313
```

**4. Move it into the site**, adding images and a Works Cited list if it needs them.

```sh
scripts/publish-draft.sh articles/2026-06-24-post-title.md
scripts/publish-draft.sh --cite reviews/2026-06-24-review-slug.md
scripts/add-images.sh content/articles/<dir> --cover photo.jpg
```

**5. Ship it.** This runs the checks, commits everything, and pushes. Pushing is
what deploys — StaticHost builds from the push, so there is no separate deploy
step.

```sh
scripts/ship.sh "Commit message"
```

Steps 4 and 5 collapse into one with `--push`:

```sh
scripts/publish-draft.sh --push articles/2026-06-24-post-title.md
```

## When a check fails

`scripts/ship.sh` refuses to commit anything if the checks fail, so a failure
leaves your work exactly where it was. Every failure prints a **Fix:** line
naming the file and what to do.

Two kinds of result, and the difference matters:

| | Meaning | What to do |
|---|---|---|
| `✗` red | **Blocking.** Pushing this would break the live site or do something that cannot be undone — a broken image, GPS coordinates in a photo, duplicate posts on eberle.blog. | Fix it before pushing. The Fix: line says how. |
| `⚠` yellow | **Advisory.** Real, but a later commit fixes it completely and nothing breaks meanwhile — a misspelled tag, an oversized page. | You can push now. Clear it soon; CI fails on it. |

To see everything CI will say before pushing:

```sh
scripts/preflight.sh --full
```

[operations.md](docs/operations.md) explains how the line between the two is
drawn, and why each check sits on the side it does.

## Reading and sources

The bibliography is one page per cited work under `content/sources/`, keyed by
citation key. The reading ledger is the subset with a reading status.

```sh
scripts/newsource.sh book "Book Title"       # prefills from Open Library by ISBN
scripts/newsource.sh zotero cramer2005       # prefills from Zotero, offline
scripts/finishsource.sh --push egan2023      # mark read, ship, and push
```

## Other commands

```sh
scripts/log-writing.sh          # end of a writing session: count the vault, publish the log
scripts/doctor.sh               # check this machine is set up
scripts/preflight.sh            # run the checks without committing anything
```

If you use the `site` fish function, every command above is available from any
directory — `site doctor`, `site new article "Title"`, `site ship "Message"` —
and `site` on its own lists them, grouped by task. The scripts here stay
canonical; `site` only removes the `cd`.

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
repo has no `.obsidian/` setup of its own. Drafts live at `~/Notes/07 Blog/Drafts/`
(override with `WEBSITE_DRAFTS_DIR`), outside the repo, until
`scripts/publish-draft.sh` moves them into `content/`.

The Templater draft templates are versioned here, in `templates/obsidian/`, and
copied into `~/Notes/Meta/templates/Website/` where Obsidian loads them. Edit
either copy and run `scripts/sync-templates.sh --from-vault` or `--to-vault` to
match them up; preflight warns when they drift. They no longer decide what a
draft looks like — they prompt, then call `scripts/newpost.sh`, which is the
only implementation of the slug rule and field order.

## Documentation

| Document | What it covers |
|---|---|
| [docs/workflow.md](docs/workflow.md) | Content model, draft/publish flow, scripts, shortcodes |
| [docs/images.md](docs/images.md) | Image authoring, responsive output, figure/carousel behavior |
| [docs/reading.md](docs/reading.md) | Reading/source ledger schema, scripts, RSS syndication behavior |
| [docs/metadata-sweep.md](docs/metadata-sweep.md) | The 2026-07 front-matter restructure: schema, vocabulary, per-file record |
| [docs/writing-log.md](docs/writing-log.md) | The public writing log: `scripts/log-writing.sh`, how words are counted from git history, and the multi-machine vault census |
| [docs/operations.md](docs/operations.md) | Remotes, CI, deployment, checks, failure behavior |
| [docs/maintenance.md](docs/maintenance.md) | Hugo upgrades, CSP hashes, theme history, repo-specific upkeep |

## Credits

- [PaperMod](https://github.com/adityatelange/hugo-PaperMod) — origin of the vendored Hugo theme base (MIT licensed)
- [Fast Search for Hugo](https://gist.github.com/cmod/5410eae147e4318164258742dd053993) by Craig Mod — fuzzy-match approach adapted into `assets/js/archive-filters.js`'s archive search (MIT licensed)
- [Charter](https://ctan.org/pkg/xcharter) by Matthew Carter (Bitstream), extended as XCharter by Michael Sharpe ([Bitstream Charter Free font license](static/fonts/charter-LICENSE.txt))
- [Fraunces](https://fonts.google.com/specimen/Fraunces) by Undercase Type ([SIL Open Font License](https://openfontlicense.org/))
- [IBM Plex Mono](https://fonts.google.com/specimen/IBM+Plex+Mono) by IBM ([SIL Open Font License](https://openfontlicense.org/))

### No longer in use

- [Solarized](https://ethanschoonover.com/solarized/) by Ethan Schoonover — early palette inspiration; the current palette (see [docs/maintenance.md](docs/maintenance.md)) has since diverged from it entirely

## License

- Content (`content/`, images, and site text) is licensed [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) — see [LICENSE](LICENSE).
- Code (templates, scripts, CSS, JS, and site configuration) is licensed under the [MIT License](LICENSE-CODE), consistent with the vendored [PaperMod](https://github.com/adityatelange/hugo-PaperMod) base it was forked from — see [LICENSE-CODE](LICENSE-CODE).
- Self-hosted font files under `static/fonts/` retain their own upstream licenses, not this repo's.
