---
title: "The Obsidian Workflow"
slug: the-obsidian-workflow
date: "2026-08-11T12:27:05-05:00"
draft: false
description: "How I work in Obsidian with research notes"
series: "\"My Summer With Claude\""
tags:
  - "AI"
  - "Writing"
publishDate: "2026-08-13T10:02:33-05:00"
lastmod: "2026-08-13T10:02:33-05:00"
---

I have used Obsidian for a number of years now but never really felt I got the system setup in a way that provided truly meaningful use. I used it primarily for storing my lecture notes and a random collection of notes I've imported from Readwise, Instapaper, Kindle, and other places. So one of my goals was to sit down with Obsidian and truly learn how to use to work for me. It's still in process but it's at least organized and structured in a manner than makes more sense and makes finding things easier as well.

<!-- more -->
## Background and Material Setup

A lot of this is adopted from Elena Razlogova's [Doing History With Zotero and Obsidian](https://publish.obsidian.md/history-notes/01+Notetaking+for+Historians), an indispensable resource for building a workflow like this. Jason Heppler's [Obsidian Workflow](https://jasonheppler.org/2026/01/08/how-i-use-obsidian-redux/) also provided valuable guidance. 

The basic idea is simple, I want my archival materials in one unified place that easily accessible and readable. By default most of my materials are stored in a single PDF for each folder within the archive. These PDFs have been OCRed and I store them within Obsidian directly rather than in Zotero. This is primarily due to cost. Thanks to being an early adopter within Obsidian, I have 50GB of syncing space at the education discounted rate of $48/year. This provides me ample storage space for my archival materials and is cheaper than Zotero's storage costs.[^1] Storing in Zotero is a more streamlined approach if you don't want as much hassle.

So when I have new archival materials, they go in my `03 Rearch/Archives` folder within Obsidian, broken down by archive, box and folder.[^2] Each archive's folder get a short status file that is solely frontmatter:

```
---
type: archive-folder-status
archive: "AAIA Files"
box: "Box 61"
folder: "Folder 1"
promoted: 0
status: to-skim
---
```

[^2]: Backups are important and I use [restic](https://restic.net) and a fish function to backup the materials as an encrypted copy on my external hard drive. The fish function also provides options to check for OCRed text and verification the backups aren't corrupted.

That frontmatter is viewable in the Archives Status base at the root of the directory, so I can easily see in one go where I can in processing. As I process the materials I change the status to promoting and then done when I'm finished.

The promotion process is relatively simple, I skim them in Obsidian for any material worth a citation entry in Zotero. When I find something, I create the relevant entry within that archive's Zotero folder, adding tags for the file and a `<project>-project` tag if need be. Once all the metadata is in Zotero, I add a link to the PDF within Zotero and annotate with its PDF reader. After that it's time to import the highlights back into Obsidian.
## The Obsidian Structure

{{< figure src="screenshot-2026-08-11-at-12-50-33-pm.avif" alt="My folder structure in Obsidian" align=center >}}

My Obsidian is organized with numbered folders, starting with the Journal which includes weekly, monthly, and yearly notes, that recap what happened during those periods. Inbox is for imported notes; Notes are general notes not tied to a project; Research is all my archival PDFs; Projects are the individual projects I'm working on; Lectures are my class lecture materials; Micro.Blog stores my micro.blog posts and Blog are the main blog drafts (where I'm writing this). Finally Meta is a collection of scripts and templates along with Obsidian bases to service and provide an overview of the materials in the vault.
## Working with Notes

When I'm ready I run the [Zotero Integration plugin](https://community.obsidian.md/plugins/obsidian-zotero-desktop-connector) in Obsidian and it will create a new note in my `01 Inbox` folder. Like my email inbox, Obsidian's is meant as a temporary processing stop, notes should never stay, but rather be filtered into the appropriate category for storage. If the note is directly related to a project it goes in the appropriate project's notes folder, otherwise it goes into `02 Notes`, the general library folder. If one of the notes in `02 Notes` ever becomes relevant to a project, it will filter down into the appropriate project in `04 Project`. 

Within each project I have a folder for Notes, which are notes directly connected to a source; analysis, which are deeper writings, moving towards the final product; Index, which collects the timeline materials for the project; Conferences collects papers that come out of the material; and Sources are the books or archival materials tied to that project. Below the folders are Obsidian bases that provide overviews of the books and archival sources and a listing of the various people, places, and organizations tied to the project. When I import a source, if it's connected to a person I can add a `[[wikilink]]` of their name in the frontmatter and it will populate a note I can fill in with the appropriate information to build a database for the project.

Finally there's a base showing all unread materials, a to-do document for the various things I need to track down or verify, and a project dashboard providing an overview of everything in one spot.

{{< figure src="screenshot-2026-08-11-at-12-58-22-pm.avif" alt="The structure of an individual project folder" align=center >}}

## Moving Forward

All of this is pretty vague because I haven't been working with the setup too much so far, as I dive deeper into it I will undoubtedly encounter annoyances and tweak the setup as it progresses, but right now it provides much more structure than my previous setup and the metadata for my files is actually there now allowing for better searching and processing than before. 

## Lectures Addendum

One of my goals for this summer in cleaning up my digital files was to better organize my lecture notes. I went through all the lectures in Obsidian and added frontmatter and then organized them to better flow with the slides. Now lecture headers call out what slides they correspond to and the material in the text is better formatted with bold call-outs and better bullet points for easier readability during lectures. While not within Obsidian, I also normalized my Powerpoints to have the same styling. As I work through the semester my focus is documenting directly which lectures have too much content and what can be trimmed down to incorporate newer material.

[^1]: Zotero charges $20/year for 2GB, $60/year for 6GB and $120/year for unlimited. I used to have unlimited but downgraded to the 2GB and won't be charged again until 2030 with prorating.
