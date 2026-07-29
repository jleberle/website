# Maintenance

## After Upgrading Hugo

When local Hugo changes, run:

```sh
scripts/sync-hugo-version.sh
```

That updates the Hugo versions referenced in:

- `statichost.yml`
- `.github/workflows/site-checks.yml`

After a Hugo upgrade, also verify CSP hashes:

```sh
scripts/csp-hashes.sh --check
```

## CSP Hashes

The `Content-Security-Policy` header in `static/_headers` allows inline `<style>` and `<script>` blocks by exact SHA-256 hash. There is no `'unsafe-inline'` in `script-src` or `style-src`.

That means hashes can drift when:

- an inline script or style changes
- Hugo's minifier changes how those blocks are emitted

Commands:

```sh
scripts/csp-hashes.sh
scripts/csp-hashes.sh --check
scripts/csp-hashes.sh --check --no-build
```

When drift appears:

1. run `scripts/csp-hashes.sh`
2. update both CSP blocks in `static/_headers`
3. commit the result

## Trusted Types

`static/_headers` sets `require-trusted-types-for 'script'; trusted-types default`, and `assets/js/trusted-types-policy.js` registers the `default` policy:

```js
trustedTypes.createPolicy('default', {
  createHTML: function (html) { return html; }
});
```

That `createHTML` is a pass-through, not a sanitizer. It satisfies the CSP directive — every `innerHTML` write on the site (`footnotes.js`, `obf-email.js`) goes through a declared policy instead of failing under Trusted Types enforcement — but it does not strip or escape anything. The only real protection Trusted Types currently gives this site is refusing an *undeclared* write (code that doesn't route through this policy at all); it does not defend against a malicious string that does.

That's an acceptable trade today because there's no path for attacker-controlled data to reach `innerHTML`: no comments, no client-side rendering of remote or user-submitted content, nothing beyond static Hugo-rendered footnote markup and build-time base64 in `obf-email.js`'s own `data-*` attributes. If a future feature ever pipes external or user-submitted content into `innerHTML` (a comments system, client-rendered search results, etc.), replace this pass-through with an actual sanitizer (or a narrow per-call-site allowlist) before that feature ships — don't assume the existing policy already covers it.

## Layout File Naming

`layouts/` is snake_case throughout (`post_meta.html`, `site_footer.html`, `format_date.html`, the shortcode `cv_letterhead.html`, ...), with one deliberate exception: `layouts/_markup/render-link.html`, `render-image.html`, and `render-table.html` stay kebab-case. Those are Hugo's own [markdown render hook](https://gohugo.io/render-hooks/introduction/) filenames — Hugo discovers them by exact name, not by registration, so renaming one to `render_image.html` doesn't error, it just silently stops Hugo from calling it and that hook's content quietly reverts to default rendering. Leave those three names alone; everything else under `layouts/` follows snake_case.

## Theme History

This repo no longer tracks PaperMod as a dependency. There is no `themes/` upstream relationship to diff against for active maintenance purposes.

What remains:

- `layouts/`
- `assets/css/site/00-license.css`

These originated in PaperMod and were vendored into the repo. The site-specific work lives on top of that as first-class local code; the rest of `assets/css/site/` (numbered `01-`–`99-`) is site-specific CSS with no PaperMod lineage.

Dead compatibility shims and unused PaperMod pieces were deliberately removed rather than preserved for theme-upgrade compatibility.

## Operational Notes

- StaticHost deploys independently of GitHub Actions, so local preflight remains the real pre-push gate.
- Secret scanning is the global Git pre-commit hook's only responsibility. The repository preflight owns publish policy, including draft and source-image checks, without modifying the Git index.
- If macOS metadata files ever reappear, `scripts/preflight.sh` now checks both Hugo source directories and generated output for `.DS_Store` and similar junk.
- Preflight also includes site-specific growth guards: oversized built HTML pages and responsive image candidates that are too small for the slots the theme renders.
