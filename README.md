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
| `content/links/` | Link archive |

New posts follow the naming convention `YYYY-MM-DD-slug/index.md`. Use the Obsidian templates in `_templates/` or the Hugo archetypes.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/to-avif.sh` | Convert images to AVIF + JPEG (for OG images) |
| `scripts/archive-links.sh` | Check all posts for dead links and replace with Wayback Machine snapshots |
| `scripts/csp-hashes.sh` | Regenerate Content Security Policy hashes after PaperMod updates |
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
Run `scripts/sync-hugo-version.sh` to update the CI build images in `statichost.yml` and `.woodpecker.yml` to match. The weekly Homebrew job will notify you when Hugo updates.

### After updating PaperMod
Check the 12 layout overrides in `layouts/` against the updated theme files. The most likely to conflict are:

- `layouts/_partials/cover.html` — fingerprinting added
- `layouts/_partials/index_profile.html` — fingerprinting added
- `layouts/_partials/templates/opengraph.html` — OG jpeg support added
- `layouts/baseof.html` — `.home` body class added

### If styles break after a PaperMod update
The two SHA hashes in the `Content-Security-Policy` header in `static/_headers` correspond to PaperMod's inline styles. If PaperMod changes those styles the hashes need updating. Run `scripts/csp-hashes.sh` to regenerate them.

### Dead link check
Run `scripts/archive-links.sh --all` periodically to find and replace dead outbound links with Wayback Machine snapshots. Woodpecker's scheduled lychee job will flag broken links in CI.

### Adding a new content type
If you add a new section (e.g. `content/essays/`):
1. Add it to `mainSections` in `hugo.yaml`
2. Add a cache rule in `static/_headers` (`/essays/*/*.avif` etc.)
3. Add it to the home page columns in `layouts/list.html` if desired

## License

Content is licensed [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
