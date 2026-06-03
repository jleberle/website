<%*
// Prompt for title and build slug
const date = tp.date.now("YYYY-MM-DD");
const title = await tp.system.prompt("Post title");
const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
const folder = `content/links/${date}-${slug}`;

// Create the folder by moving this file into it as index.md
await tp.file.move(`${folder}/index`);
-%>
---
title: "<% title %>"
date: <% tp.date.now("YYYY-MM-DD") %>
lastmod: <% tp.date.now("YYYY-MM-DD") %>
draft: true
description: "<% await tp.system.prompt("Description") %>"
tags: [<% await tp.system.prompt("Tags (comma-separated)") %>]
categories: [<% await tp.system.prompt("Categories (comma-separated)") %>]
external_url: "<% await tp.system.prompt("URL") %>"
---

<!-- more -->