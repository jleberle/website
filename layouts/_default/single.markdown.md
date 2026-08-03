{{- /* Raw Markdown source endpoint for agents (spec: markdown-source-endpoints).
       .RawContent is the pre-render markdown body (shortcodes/frontmatter
       stripped), so this ships the same source the page was authored from,
       not a re-serialization of the rendered HTML. */ -}}
---
title: {{ .Title | jsonify }}
url: {{ .Permalink }}
updated: {{ .Lastmod.Format "2006-01-02" }}
license: {{ site.Copyright | markdownify | plainify | jsonify }}
---

{{ .RawContent }}
