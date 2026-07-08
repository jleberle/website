---
title: Colophon
hideMeta: true
description: "The technical details of the site"
summary: "All of the technical details that make this site work."
---

## Theme 

{{< figure
src="northeaster-winslow-homer.avif"
alt="Winslow Homer's The Northeaster showing waves crashing on a rocky shore"
caption="Winslow Homer, Northeaster"
attr="Metropolitan Museum of Art, New York, NY"
attrlink="http://www.metmuseum.org/collection/the-collection-online/search/11130"
align="center"
>}}

This site is built with [Hugo](https://gohugo.io) and served through [Codeberg](https://codeberg.org/jleberle/website) and [Statichost.eu](https://statichost.eu). The current inspiration for the site's theming comes from Winslow Homer's coastal paintings, in particular *Northeaster* and [*The Fog Warning*](winslow-homer-the-fog-warning.avif), experiencing my New England heritage.

The site's theme was largely designed with the help of Claude but the programs only touched back-end files on the site, everything you see publicly is written and edited by me, a [real human](/humans.txt). Typos are my own but for errors, please blame my cat.

## Low Impact

Besides the theme design, I've intently worked to make this site as environmentally friendly as possible meaning the homepage uses only [0.013g of carbon dioxide](https://digitalbeacon.co/report/jaredeberle-org) for a first time visitor.[^1] In terms of my [biggest page](/articles/past-and-future-of-indian-rodeo-in-las-vegas/), it only uses 0.045g and downloads at just under 145KB for a first time visitor whereas a standard news article on any major site will download 2-3MB of data (20 times the amount). This is the result of a number of very opinionated decisions:

[^1]: It used to be 0.008g but I added a self-hosted font to make the site better for readability.

- A static blog like Hugo is more efficient than software like Wordpress and to
  further enhance that, all resources are minified when built and my javascript usage is minimal (roughly 7KB in total) and deferred
- The site uses one self-hosted and subsetted font (Fraunces) for the headers while all remaining fonts are system fonts. This removes an extra outside url fetch and it removes unneeded weight from the font download. 
- Images are AVIF format, lazy loaded, and responsive which reduces file sizes and only loads them when needed.
- The website uses hashed files and immutable cache times, which basically means your browser won't redownload things unless they change and a new hashed file is created.
 
This site should also be fully compliant with web accessibility standards, if you run into issues, please {{< email "jared@jaredeberle.org" "let me know" >}} and I will work to fix the issue as best as possible.
 
Further information on [privacy](/privacy) and [terms of use](/terms) can be found at those links but privacy boils down to I keep nothing about your visit and terms is really just please be kind and report issues you find. For errors you can either email me or submit a request through Git and Codeberg through the Suggest Changes link at the top of every post.
