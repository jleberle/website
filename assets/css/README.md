# Site CSS

The production stylesheet is assembled from `site/` using the explicit component
manifest in `layouts/_partials/head.html`. Numeric prefixes make the intended
order visible in the directory, but the manifest is the source of truth; do not
replace it with an alphabetical glob.

## Component boundaries

- `00`–`03`: license, design tokens, reset, and font declarations
- `10`–`12`: global layout, header, and footer
- `20`–`28`: content and page components
- `90`: narrow-viewport and reduced-motion adjustments shared across components
- `99`: print overrides, deliberately loaded last

Put a rule in the narrowest component that owns it. Keep component-specific
responsive rules beside the component; use `90-responsive.css` only for rules
shared across multiple components. Avoid repeating an exact selector in the same
file—stylelint treats that as a conflict. Repeated selectors across files should
be limited to deliberate responsive or print overrides.

Before publishing CSS changes, run:

```sh
npx stylelint 'assets/css/**/*.css'
scripts/preflight.sh --strict --full
```
