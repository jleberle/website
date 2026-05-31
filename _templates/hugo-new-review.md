<%*
// Prompt for title and build slug
const date = tp.date.now("YYYY-MM-DD");
const title = await tp.system.prompt("Post title");
const slug = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '');
const folder = `content/reviews/${date}-${slug}`;

// Create the folder by moving this file into it as index.md
await tp.file.move(`${folder}/index`);
-%>
---
title: "<% tp.file.title %>"
date: <% tp.date.now("YYYY-MM-DDTHH:mm:ssZ") %>
lastmod: <% tp.date.now("YYYY-MM-DDTHH:mm:ssZ") %>
draft: true
description: "<% await tp.system.prompt("Description") %>"
tags: [<% await tp.system.prompt("Tags (comma-separated)") %>]
categories: [<% await tp.system.prompt("Categories (comma-separated)") %>]
cover:
  image: "cover.webp"
  alt: "<% await tp.system.prompt("Image Alt Description") %>"
  hiddenInList: true
  hiddenInSingle: false
  caption: ""
  relative: true
---

<!-- more -->