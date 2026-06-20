<%*
// Prompt for title and build slug
const date = tp.date.now("YYYY-MM-DD");
const title = await tp.system.prompt("Post title");
const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
const description = await tp.system.prompt("Description");

// Quotes are flat files: content/quotes/<date>-<slug>.md
await tp.file.move(`content/quotes/${date}-${slug}`);
-%>
---
title: "<% title %>"
slug: <% slug %>
date: <% tp.date.now("YYYY-MM-DD") %>
lastmod: <% tp.date.now("YYYY-MM-DD") %>
draft: true
description: "<% description %>"
summary: "<% description %>"
tags: [<% await tp.system.prompt("Tags (comma-separated)") %>]
categories: [<% await tp.system.prompt("Categories (comma-separated)") %>]
external_url: "<% await tp.system.prompt("URL") %>"
---

<!-- more -->