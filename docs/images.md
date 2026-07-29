# Images

## Authoring Model

Image handling is split into two stages:

1. authoring helpers that place and convert images into the post bundle
2. Hugo responsive processing at build time

The authoring helper is:

```sh
scripts/add-images.sh content/articles/<dir> --cover photo.jpg
scripts/add-images.sh content/articles/<dir> img1.jpg img2.png
```

Covers become:
- `cover.avif`
- an optimized `cover.jpg` companion for OpenGraph crawlers

Body images become:
- `.avif` only

Do not pre-generate resized variants. The build handles responsive resizing.

`scripts/to-avif.sh` strips EXIF/IPTC/XMP from every output it writes (GPS
tags and similar were the original concern). The AVIF/HEIC encoder writes
some of its own EXIF back in after the first `-strip` pass, so the script
runs a second `-strip` pass on the finished file — a single pass isn't
enough. `scripts/checks/image-metadata-lint.py` (wired into preflight)
enforces this on every published raster file regardless of how it got
there, so an image added outside the helper still gets caught.

## Responsive Output

Several templates route through `layouts/_partials/responsive-img.html`, which is the single source of truth for the shared image sizing logic.

| Where | Template | Widths emitted |
|---|---|---|
| Markdown body images | `layouts/_markup/render-image.html` | 400 / 800 / 1200w + original |
| `figure` shortcode | `layouts/shortcodes/figure.html` | 400 / 800 / 1200w + original |
| `carousel` shortcode | `layouts/shortcodes/carousel.html` | 400 / 800 / 1200w + original |
| Post covers | `layouts/_partials/cover.html` | 360 / 480 / 720 / 1080 / 1500w |
| Home avatar | `layouts/_partials/home_info.html` | 1x / 2x from configured width |
| Header logo | `layouts/_partials/header.html` | 2x from configured height |

Each image gets explicit `width` and `height` to reduce layout shift. Single-page covers load eagerly as likely LCP elements; most other images lazy-load.

## Accessibility Expectations

Figures without `alt` or `caption` trigger a build warning in strict checking.

- `alt` should describe what the image shows
- `caption` should provide attribution, commentary, or context

Captions are not substitutes for alt text.

## Publishing Behavior

`build.publishResources` is `false` in `hugo.yaml`. That means page-bundle files only publish when a template resolves them as real Hugo resources and calls `.RelPermalink` or `.Permalink`.

Do not build page-bundle URLs by string concatenation. If a template needs a bundle resource, resolve it properly with `.Resources.Get` or `GetMatch`.

The local preflight published-reference scan exists partly to catch mistakes here.
