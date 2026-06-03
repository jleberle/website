---
title: What I Learned From Claude
date: 2026-05-27
categories:
  - Digital Humanities
tags:
  - AI
  - Web Development
draft: true
slug: /what-i-learned-from-Claude/
---
I have to acknowledge that while I remain deeply opposed to AI for a multitude of reasons, I did utilize Claude Code to rework a good portion of the site over the last few days. In the process Claude managed to implement some things I've wanted to do for a while and help improve the performance of the site, at the same time it did manage to highlight the glaring issues with AI and re-affirmed the fact that it's place for my workplace is extremely limited.

## Where Claude Worked Well

Claude's biggest benefit was in the simplest tasks, in particular batch renaming and converting. The first thing I had Claude do was convert all my old markdown posts into Hugo page bundles, which meant Claude created folders based on the post title, and renamed the file to index.md. These are simple tasks and Claude did the job quicker and more efficiently than I could have. Same for converting images to webp to reduce bandwidth on the site. Again, a simple script and an easy task for Claude. 

## Where Claude Did OK

I wanted to create *Daring Fireball* style link posts so I could easily link out to books and other materials I wanted to quote from. Claude created the necessary files and made it work with my current theme. It did run into some issues with interfacing with the PaperMod theme I use as a base, but generally it worked well. 

It did also help improve the site with site audits for performance, security, and accessibility. Claude worked well providing a list of tasks to do and was pretty honest about what was worthwhile and what wasn't. This helped figure out gaps in the website and streamlined the process of fixing the errors.

## Where Claude Had Problems

The biggest issue for Claude was when services changed variables or it needed to search resources on the internet. On a handful of occasions Claude provided a fix and implemented it, only for it to present an error. A follow-up prompt led Claude to note the issue. In one cause it was the variable had been deprecated, in another Claude simply couldn't find the answer and I had to paste in information on my own to get it over the line. 

## Where I Had Problems

One of the reasons I find AI deeply problematic is that it incentivizes using it more and more and by the end of my time with Claude I ran into at least one point where I could have easily solved the problem myself but reflexively asked Claude what the issue was. In that case Claude had created a link checker that would run in Codeberg's online command interface and I was checking it for errors. Claude's original suggestion was throwing tons of errors to internal files and it's follow-up also failed. It finally figured out what it wanted to do and that third option did ultimately work but the parameter Claude wanted to use was deprecated and the error message told me as much and offered the options that worked. Had I spent a few seconds reading the error message I could have changed the parameter myself and resolved it but I copied the message and fed it to Claude.

## What Now?

I've fed Claude more money that I ever taught I would and it did help fix a number of issues while saving me brainpower and time. From here, however, Claude doesn't need more of my money. I won't let it touch anything I've personally written, at any stage of the process, so I've simply relied on it for the coding backend. 