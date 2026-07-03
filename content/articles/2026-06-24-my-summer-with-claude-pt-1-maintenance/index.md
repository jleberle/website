---
title: "My Summer With Claude, Pt. 1: Maintenance"
slug: my-summer-with-claude-pt-1-maintenance
date: 2026-06-24
lastmod: 2026-06-24
draft: false
description: The first in a series of posts about using Claude this summer
series: "My Summer With Claude"
categories:
  - Articles
tags:
  - Personal
  - AI
---
The goal for this summer is to tackle the smaller goals I have had had on my to-do lists for in many cases years. These are things that are not going to cause a ton of issues if I do not do them, so they have usually ended up remaining at the bottom of the to-dos but now is the time to finally tackle them. How many of them will get done? Not entirely sure, summers always start with the same youthful vibrancy that people have when they start out with New Year's resolutions on January 1st. Meanwhile summers usually end with the simple fact that not nearly as much happened as you would have hoped. 

<!-- more -->

Right now I have four broad areas I want to tackle, some of which I've already done:

1. **Digital organizing and cleanup**: I have a lot of files on my computers that have become increasingly disorganized and in various levels of disrepair. The goal is to modernize them and set them up for better ease of use and reliability moving forward.
2. **Lectures**: Like my digital files more broadly, I have lecture notes that have accumulated various parts that I don't really use anymore in lectures themselves. The goal is to do a full review of all my lecture notes and slides and put them into better working order.
3. **Obsidian**: I've been using [Obsidian](https://obsidian.md) for years but I've never fully committed to working on a system to truly *use* Obsidian. I have some resources I've been saving and the goal is to sit down with Obsidian and truly learn how to use the app.
4. **The 1970s**: I have 4 or 5 books that I've had sitting on my shelf for years now that I really want to finally actually sit down with and take notes on for a variety of reasons. 

What I've done so far:

1. I've updated most of my digital files as seen below
2. I've started to reorganize lectures a I work on recording lectures for my online summer course
3. I've added some to Obsidian to help me manage my website within the app but haven't fully explored using the app for resource purposes.
4. Nothing, yet.

The first thing I wanted to tackle this summer were my digital files, in particular the four main git repositories I have: my website, CV, syllabi, and dotfiles.[^4] All four of them were sitting in various levels of disrepair and were largely held together by the equivalent of digital duck tape and luck that nothing had broken.  If I were to try and tackle even one of these repositories on my own I'd probably spend well over a year and the system would still probably be fragile jerry-rigged setup. So I turned to something I never really thought I'd use in any depth, AI. I remain deeply concerned about AI's impacts on both the environment and learning, but paying for Claude did allow me to improve my systems, albeit in a way that still leaves me unable to fully resolve issues should they arise. With that important caveat in mind, here's what changed.
## Dotfiles

[These files](https://codeberg.org/jleberle/dotfiles) provide configurations for digital tools I use on a semi-regular basis. As evidenced by the [changelog](https://codeberg.org/jleberle/dotfiles/src/branch/main/CHANGELOG.md) they had largely been unmaintained for a number of years. I had Claude conduct audits of all the files and report back on issues and improvements which resulted in essentially a full rewrite of the files that should in theory work well for at least a reasonable time.

By the time I was happy with the files, I had created the ability to get a new computer and have it mirror my old system quickly. Now all I need to do when setting up a new system is download xcode's command-line tools, clone my git repo and run 5 make commands to set everything up. 

First it cleaned up and improved a number of my command line programs:

- **Fish**: My command line shell was updated from zsh to fish and Claude rewrote all the files and added helpful caching to speed up launches.
- **Ghostty**: My terminal app, which Claude added options to make it work better with the tools I use.
- **tmux**: I rarely use it, especially because Ghostty allows for easily splitting terminals and moving between them, but I keep it around just in case.
- **Git/GPG**: Claude proposed a number of changes to modernize both setups and fix some errors in the config files.
- **Firefox**: [Betterfox](https://github.com/yokoffing/Betterfox) is now a submodule of the repo and I can easily update it when needed and pull in my customizations.
-  **Scripts**: Claude reworked scripts to remove dependency issues and fix errors that had arisen and made the scripts largely non-functional. 

Then I had it write a more streamlined setup for writing markdown prose in the term and getting it out to other formats when needed:

- **Neovim**: I had Claude construct a minimal neovim setup that focused on writing in Markdown and prose, so it doesn't incorporate syntax highlighting for many code languages and reduced what I had to worry about from the previous setup I used.
- **Templates**: I had Claude create a reference.docx for Pandoc, setup a metadata file and write in aliases that allow for easy creation and outputting files through Pandoc with the basic formatting I need.
- **Neomutt**: I used to use mutt for email but when OSU switched to blocking IMAP I had to stop using it, but I had Claude recreate my setup for the odd time when I need to access an encrypted message, which I can do for free through Mutt rather than using GPG Tools. 

To help manage it all I had Claude write a number of check options into the makefile that allows me to verify everything is correctly installed and nothing is silently failing. While I mostly write in Obsidian, this allows me to have a good command line set up when I do dip into it.
## CV

In the past I used [markdown-pp](https://github.com/amyreese/markdown-pp) to build a web version and a PDF version of my CV at the same time. When I moved my website to Wordpress I left the system as it was but removed the option to create a web version as it was no longer needed. Markdown-pp is no longer maintained, however, and the system regularly ran into issues when I needed to construct an updated CV. 

When Claude analyzed the repository, it noted that the whole system could be achieved solely through [pandoc](https://pandoc.org) and wrote the script to build the PDF, the markdown file, and update both repositories. I had Claude also ensure the PDF was optimized for web delivery, reducing the file size by roughly 70%. So now I can run the same system I had before but with tools I already use and are well-maintained.

## Syllabi

My main concern with my syllabi was the fact that I was using an old LaTeX template that had a tendency to break. So I asked Claude to assess it for issues and it immediately noted that the template was good but was very old and suggested I rewrite it for modern standards. Claude resolved the issues, rewrote it to have a more modern look and helped minimize the LaTeX footnote on my computer to only download the dependencies I actually need.

After setting up the base I decided to take it a step further and have Claude write a script to automate syllabus creation, which I can now do and have the syllabus populated with basic information and a class schedule that updates based on the start date I give it. 

## Website

This is really where I wanted to spend my time and what started out as a desire to tweak my current theme ultimately became essentially a full rewrite of the site's theme.[^2] What I have now is a site theme around a muted style of "Oklahoma prairie sunrise" which gives the site earthly, mellow tones throughout.[^3] I was really hoping to embrace the "good enough" mentality here, but the theme really did become a far more significant focus than I expected it to be when I started.

[^2]: The last time I had the robots compute how much of the underlying PaperMod theme I was overriding it was around 41%. **Update**: After publishing I continued to tinker and it ultimately became more sustainable to simply remove PaperMod entirely and have a fully independent theme. Which is where we are now.
[^3]: **Update**: The original design of the site is really my design aesthetic but apparently it's also [shared by AI](https://www.newyorker.com/culture/infinite-scroll/the-ai-design-aesthetic-thats-taking-over-the-internet). So now the theme is playing into [my love of Winslow Homer's paintings](/about#site). 

In addition to the outward changes, my original main focus was on efficiency and resource usage. As a result I had Claude start with converting images to avif to shirk their size on my server. Next I had it convert all my posts to page bundles where I can drop images or files and use relative paths rather than having to put everything in the static folder. I also had Claude add improvements for caching further reducing the load times and environmental impact of this site is essentially zero.

Then we get to my favorite improvements, which are the things that happen behind the scenes before this site gets built. I have a setup now that helps automate the drudgery of creating a post in Hugo, either through the command line or within Obsidian itself. Now I can create a post and have it populate metadata or prompt me to insert it or drop it entirely if unneeded. Furthermore all of the image optimizations are scripted in so I can run my add-images.sh script and have it copy a photo from the Downloads folder to the correct post folder on the site and generate an optimized avif image and corresponding jpeg if it's needed for social media sharing. Then when I am done actually writing the post and commit it, I have an automated pre-push setup in git that will scan the website for issues and cancel the push if there's an error. Finally, for URLs I have scans to replace dead URLs with archive.org links and automated cron jobs on the repo to scan the URLs and report breaks to help with archivability.
## Bonus: Micro.Blog and NetNewsWire

My [micro.blog](https://eberle.blog) isn't something I thought I'd actually want to deal with here, but given that I had the time, I had Claude write an entire theme for my micro.blog that mirrors the theming of my main site and really does what I've always wanted with micro.blog. Now my site shows my most recent status at the top, then what I'm currently reading, followed by my most recent reads and watches, and ends with my clippings from around the web. Now I truly have my own home page for status updates. 

This was the most rewarding and frustrating one of my interactions with Claude because as it was building my theme I kept running into an issue: the website would break under Hugo's 0.158 when I triggered a full rebuild. For quite a while Claude argued that the answer was something on Micro.blog's end and my theme was fine. After a lot of prodding I finally decided to test the theme locally and set up a fully mirrored archive on my computer and the result was that the archive plugin I was using had an old variable that nuked the feed that built the homepage, so Claude was technically both right that it wasn't our theme but wrong with the idea that it was something entirely internal. 

Then I had Claude write four themes for NetNewsWire, my trusted RSS reader that allows custom themes. The [four themes](https://codeberg.org/jle/nnw-themes) are divided into two categories: phone-based and desktop-based. Each one gets a minimal sans-serif theme and a serif theme. The sans-serif theme is kept very minimal and monochrome and has become my preferred themes over the slightly more elaborate serif themes.
 
 ## Where Claude Worked Well (and Didn't)

Claude was best for the batch conversions, changing pages to page bundles, converting images and PDFs.[^1] Claude also tended to work well with the basic revisions that were needed. At the same time Claude did have a tendency to get things wrong, which makes me question anyone using it for more significant things than I have here. I'm comfortable having Claude deploy stuff to the web for me because everything here is static files, there's no true opportunity for exploits. What I would not trust Claude with is anything public facing that involves scripts or databases because Claude for all it's successes still isn't smart and any LLM is going to probably inject security issues at some point.

The failure instance that most stuck with me was when I asked Claude to update my post metadata to incorporate the last modified date from Git and it told me variables were deprecated and needed to be replaced, so I approved the change only to find my site didn't build. I asked Claude to figure out the issue and it reported that it had actually changed the site to use the old variables and the ones it had replaced were actually correct. There were a number of other times were Claude added in regressions or made errors, all of which were minor given the nature of my repos.

[^1]: I also had it OCR a bunch of PDFs that haven't been OCRed and renamed those files to better ensure I don't lose the citation information on them.

## Where Claude Just Annoyed Me

If you've been on Twitter/X any time in the last few years or seen stuff through second hand accounts you know a lot of the biggest proponents of AI talk in the most grating way. By the end of my time with Claude I truly wished it was a real person so I could slap it. Too often it talked like a 20 year old chugging Mountain Dew and trying to sound cool. 
## What I Learned

In terms of the changes, not that much. Everything I have is still in a lot of respects the same house of cards as before but with a firmer basis. Can I fix issues if they break in the future? With my basic HTML and CSS, possibly but my real knowledge is also severely outdated. In the same way that using AI to prepare notes or study reduces the amount of material you retain, I didn't pick up anything from this besides reducing the amount of time and brain power I spent on it. 

I also found myself at times relying too much on Claude, both in terms of asking it to fix things I could do myself as well as asking it to constantly find improvements. By the end I felt I was getting that addictive itch of wanting Claude to find more, which is basically what Anthropic, OpenAI, and all the rest want. The more I use it, the more money they get, so naturally Claude offered me some free usage credits as I neared my plan limits. Anthropic may want to bill itself as the enlightened choice but it still tapped into the same tactics as online gambling sites, realizing I was a heavy user and enticing me with free usage to keep working beyond the limits it imposed. And when those credits ran out? Well I could either wait for the usage windows to reset or buy more credits. I waited, it should be noted.
## What's Next?

I'll have more explicitly on the Obsidian setup in that post, but for right now it's onto organizing some archival research, checking lectures, and maybe reading some books.

[^4]: Short way of saying configuration files.
