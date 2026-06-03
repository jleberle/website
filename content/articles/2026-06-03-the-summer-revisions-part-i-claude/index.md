---
title: "The Summer Revisions, Part I: Claude"
date: 2026-06-03
lastmod: 2026-06-03
draft: true
description: A series on what I did this summer starting with Claude
tags:
  - AI
  - Productivity
categories:
  - Personal
---
## What I Want to Do

The goal for this summer is to try and tackle as much of the things I've had lying around waiting for be done and simply haven't gotten around to doing, in some cases for years. How many of them will get done? Not entirely sure, summers always start with the same youthful vibrancy that people have when they start out with New Year's resolutions on January 1st. Meanwhile summers usually end with the simply fact that not nearly as much happened as you would have hoped. 

Right now I have four broad areas I want to tackle, some of which I've already done:

1. **Digital organizing and cleanup**: I have a lot of files on my computers that have become increasingly disorganized and in various levels of disrepair. The goal is to simply get them into better shape.
2. **Lectures**: Like my digital files more broadly, I have lecture notes that have accumulated various parts that I don't really use anymore in lectures themselves. The goal is to do a full review of all my lecture notes and slides and put them into better working order.
3. **Obsidian**: I've been using [Obsidian](https://obsidian.md) for years but I've never fully committed to working on a system to truly *use* Obsidian. I have some resources I've been saving and the goal is to sit down with them and Obsidian and truly learn how to use the app I probably use the most.
4. **The 1970s**: I have 4 or 5 books that I've had sitting on my shelf for years now that I really want to finally actually sit down with and take notes on for a variety of reasons. 

What I've done so far:

1. I've updated most of my digital files as seen below
2. I've started to reorganize lectures a I work on recording lectures for my online summer course
3. I've added some to Obsidian to help me manage my website within the app but haven't fully explored using the app for resource purposes.
4. Nothing, yet.

## My Time With Claude

The first thing I wanted to tackle this summer were my digital files, in particular the four main git repositories I have for my website, cv, syllabi, and dotfiles. All four of them were sitting in various levels of disrepair and were largely held together by the equivalent of digital duck tape and luck that nothing had broken.  If I were to try and tackle even one of these repositories on my own I'd probably spend well over a year and the system would still probably be a house of cards. So I turned to something I never really thought I'd use in any depth, AI. I remain deeply concerned about AI's impacts on both the environment and learning, but paying for Claude did allow me to improve my systems, albeit in a way that still leaves me unable to fully resolve issues should they arise. With that important caveat in mind, here's what changed.

## Dotfiles

[These files](https://codeberg.org/jleberle/dotfiles) provide configurations for digital tools I use on a semi-regular basis. As evidenced by the [changelog](https://codeberg.org/jleberle/dotfiles/src/branch/main/CHANGELOG.md) they had largely been unmaintained for a number of years. I had Claude conduct audits of all the files and report back on issues and improvements which resulted in essentially a full rewrite of the files that should in theory work well for at least a reasonable time.

By the time I was happy with the files, I had created the ability to install a new system that would mirror by old system relatively quickly. Utilizing a brewfile I can install all the apps I use now with one command and setup automatic weekly updates with another. From there I had Claude fully rewrite the configuration options for the various programs I use and construct from helpful template files as well:

- **Fish**: My command line shell was updated from zsh to fish and Claude rewrote all the files and added helpful caching to speed up launches.
- **Ghostty**: My terminal app, which Claude added options to make it work better with the tools I use
- **Git/GPG**: Claude proposed a number of changes to modernize both setups and fix some errors in the config files
- **Neovim**: I had Claude construct a minimal neovim setup that focused on writing in Markdown and prose, so it doesn't incorporate syntax highlighting for many code languages and reduced what I had to worry about from the previous setup I used.
- **tmux**: I rarely use it, especially because Ghostty allows for easily splitting terminals and moving between them, but I keep it around just in case.
- **Templates**: I had Claude create a reference.docx for Pandoc, setup a metadata file and write in aliases that allow for easy creation and outputting files through Pandoc with the basic formatting I need.
- **Scripts**: Claude reworked scripts to remove dependency issues and fix errors that had arisen and made the scripts largely non-functional. 

I do must of my work in Obsidian, but this now provides me a firmer command line system for when I need it, especially because my previous system was no longer maintained and would've probably broken at some point in time.

## CV

In the past I used [markdown-pp](https://github.com/amyreese/markdown-pp) to build a web version and a PDF version of my CV at the same time. When I moved my website to Wordpress I left the system as it was but removed the option to create a web version as it was no longer needed. Markdown-pp is no longer maintained, however, and the system regularly ran into issues when I needed to construct an updated CV. 

When Claude analyzed the repository, it noted that the whole system could be achieved solely through Pandoc and wrote the script to build the PDF, the markdown file, and update both repositories. I had Claude also ensure the PDF was effectively optimized for web delivery, reducing the file size by roughly 70%. So now I can run the same system I had before but with tools I already use and are well-maintained.

## Syllabi

My main concern with my syllabi was the fact that I was using an old LaTeX template that had a tendency to break. So I asked Claude to assess it for issues and it immediately noted that the template was good but was very old and suggested I rewrite it for modern standards. Claude resolved the issues, rewrote it to have a more modern look and helped minimize the LaTeX footnote on my computer to only download the dependencies I actually need.

In addition I asked Claude to write a script to automate syllabus creation, which I can now do and have the syllabus populated with basic information and a class schedule that updates based on the start date I give it. 

## Website

This is really where I wanted to spend my time and it actually became the place I spent the least time in many respects. I did at one point envision creating my own theme for my website with Claude but decided for the good enough approach and continue to use the theme I was using with minor tweaks to fix the issues that annoyed me. 

Instead of rewriting the entire site I had Claude focus on efficiency, converting images to avif to shirk their size on my server and converting all my posts to page bundles where I can drop images or files and use relative paths rather than having to put everything in the static folder. I also had Claude add improvements for caching further reducing the load times and environmental impact of this site is essentially zero.

My favorite improvement is actually want happens before this site even gets built. Now before every commit is made the site is checked for files that can be converted to avif, meaning I can drop in a .png file and have it converted without my direct involvement. Additionally the site is checked on every commit for dead URLs and they're replaced with links to archive.org snapshots. Similarly I have an automated monthly check to catch anything missed in between posts. This improves both the usability and archivability of the website. As a result the website still looks the same in most respects but it works far better than it did a month ago and I've added a lot of the behind-the-scenes things that made me like Wordpress.

## Where Claude Worked Well (and Didn't)

Claude was best for the batch conversions, changing pages to page bundles, converting images and PDFs. Claude also tended to work well with the basic revisions that were needed. At the same time Claude did have a tendency to get things wrong, which makes me question anyone using it for more significant things than I have here. For instance I asked Claude to update my post metadata to incorporate the last modified date from Git and it told me variables were deprecated and needed to be replaced, so I approved the change only to find my site didn't build. I asked Claude to figure out the issue and it reported that it had actually changed the site to use the old variables and the ones it had replaced were actually correct. There were a few other times were Claude ran into the same issues and ultimately changed things it had previously implemented.

## What I Learned

In terms of the changes, not that much. Everything I have is still in a lot of respects the same house of cards as before but with a firmer basis. Can I fix issues if they break in the future? No. In the same way that using AI to prepare notes or study reduces the amount of material you retain, I didn't pick up anything from this besides reducing the amount of time and brain power I spent on it. 

I also found myself at times relying too much on Claude, both in terms of asking it to fix things I could do myself as well as asking it to constantly find improvements. By the end I felt I was getting that addictive itch of wanting Claude to find more, which is basically want Anthropic, OpenAI, and all the rest want. The more I use it, the more money they get, so naturally Claude seemingly always found something new to suggest when I asked it to review everything and present concerns. Yes, the suggestions did gradually diminish in their importance, but at times Claude did find meaningful improvements even on the 4th or 5th pass. 

## What's Next?

The lecture revisions are going to happen as I work through the lecture videos and I will probably ask Claude for help with checking Obsidian templates for usability. As of right now I'm pretty happy with the system I have for this.