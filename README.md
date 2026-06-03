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

New posts follow the naming convention `YYYY-MM-DD-slug/index.md`. Use the Hugo archetype or the template in `_templates/hugo-new-post.md`.

## Scripts

| Script | Purpose |
|---|---|
| `scripts/to-avif.sh` | Convert images to AVIF format |
| `scripts/webp-to-avif.sh` | Convert WebP images to AVIF |
| `scripts/archive-links.sh` | Archive outbound links |
| `scripts/csp-hashes.sh` | Generate Content Security Policy hashes |
| `scripts/newlink.sh` | Add a new link entry |

## Link checking

```sh
lychee --config lychee.toml content/
```

## Deployment

The site deploys automatically via [statichost.eu](https://statichost.eu) using the configuration in `statichost.yml`. Hugo runs with `--minify` and outputs to `public/`.

## License

Content is licensed [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/).
