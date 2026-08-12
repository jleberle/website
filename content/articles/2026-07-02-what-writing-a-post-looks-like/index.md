---
title: "What Writing A Post Looks Like"
slug: what-writing-a-post-looks-like
date: "2026-07-02T14:01:42-05:00"
draft: false
description: "The workflow for writing a post on this blog"
series: "My Summer With Claude"
categories:
- "Articles"
tags:
- "AI"
publishDate: "2026-08-11T12:20:18-05:00"
lastmod: "2026-08-11T12:20:18-05:00"
---

Having sat down and done far more tinkering and revisions on this site than I ever expected, this post is really a way for me to document all the ways to get content into my writing systems because just like having Claude write class notes, I feel I came away from the whole experience feeling like I do not fully know what I actually built. So here it is, feel free to use any of it or get in touch in there's a better way to do anything.
<!-- more -->
When it comes to creating a blog post like I primarily create them in Obsidian through templates that prompt for relevant metadata. To do this I use the Templater plugin for Obsidian and have the new post/review/quote templates connected to a keyboard shortcut that utilizes my hyperkey setup. So now `⌘+⌃+⌥+⇧+P` creates a new post and prompts for all the relevant frontmatter. All the posts live in the drafts/ folder of the repo which is only synced through Obsidian, that way there's no chance a draft post makes it into the website repository until final and ready to publish. In the event I wish to avoid Obsidian for some reason, I can do the same thing in the [command line with a script](https://codeberg.org/jle/website/src/branch/main/scripts/newpost.sh) that will automatically open neovim for writing.

That covers the writing but there's a few more things to note for the site. First, in the event the site has images, I can run [`add-images` script](https://codeberg.org/jle/website/src/branch/main/scripts/add-images.sh), which will take a file in the Downloads folder, convert it to avif and optimize the file size and drop it in the appropriate hugo page bundle for the post. In the event the image is a cover photo for the post it will automatically rename the file to `cover.avif` and create a jpeg version needed for social sharing.

These two steps alone resolve most of the images I had with blogging through Hugo, in that creating the content became too much of a chore and it was simply more of a process getting the scaffolding in place to actually write. That friction did apply as well to the final publishing step but for that I have `publish-draft`, a script to automate the last step of the process. When I run [the script](https://codeberg.org/jle/website/src/branch/main/scripts/publish-draft.sh) it moves the post out of the drafts/ directory and into the appropriate folder in content. Afterward it flips the post to `draft: false` and adds in `lastmod` and `publishDate` variables so that the post is current when published and not using a stale date from when it was created. Both `add-images` and `publish-draft` can be done in Obsidian through the [lean terminal community plugin](https://github.com/sdkasper/lean-obsidian-terminal) which opens a basic terminal in Obsidian to run the necessary shell commands.

I really could've (and should've) stopped there, but decided to go a little further. I've been tracking my [reading on micro.blog](https://eberle.blog/reading) but decided to self-host the setup utilizing a setup like [Jason Heppler does](https://jasonheppler.org/books/). Now I have a [reading page](/reading) that offers additional information on the book (or other materials) when clicked on. I add entries to the page with [another script](https://codeberg.org/jle/website/src/branch/main/scripts/newbook.sh) that tries to pull information from Open Library based on the ISBN or prompts for manual entry if that fails. When I'm done with a book, that's right, [another script](https://codeberg.org/jle/website/src/branch/main/scripts/finishbook.sh) updates the metadata, marking it as complete and populating the relevant material. All of this is RSS backed, which I use to populate the homepage of my micro.blog and sync it across the fediverse in one go. For books I can also create a citekey like I use in Zotero and the reading page will automatically populate entries with related posts. All of this means the only things that don't naively live within this website are my internet clippings that don't fit the scholarly theme of the site and the movies I watch, but as of now a good chunk of the content I generate online is centralized here and pushed other places. 

Finally, when I'm done with everything I simply commit the changes and run `site push` which runs basic checks on the site to flag any breaking issues before pushing the site to the git repo and Cloudflare automatically builds and deploys the site. From there the site is live and Github runs more expansive testing to ensure the site is fully validated and complying with accessibility standards.
