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

This site is built with [Hugo](https://gohugo.io), sourced on [GitHub](https://github.com/jleberle/website), and served through [Cloudflare](https://www.cloudflare.com). The current inspiration for the site's theming comes from Winslow Homer's coastal paintings, in particular *Northeaster* and [*The Fog Warning*](winslow-homer-the-fog-warning.avif), experiencing my New England heritage.

The site's theme was largely designed with the help of Claude but the programs only touched back-end files on the site, everything you see publicly is written and edited by me, a [real human](/humans.txt). Typos are my own but for errors, please blame my cat.

## Low Impact

Besides the theme design, I've intently worked to make this site as environmentally friendly as possible meaning the homepage uses only [0.028g of carbon dioxide](https://digitalbeacon.co/report/jaredeberle-org) for a first time visitor.[^1] In terms of my [biggest page](/articles/past-and-future-of-indian-rodeo-in-las-vegas/), it only uses 0.059g and downloads at just under 191KB for a first time visitor whereas a standard news article on any major site will download 2-3MB of data. What all this means is that if 10,000 people visit this site a month, which doesn't happen, this would produce the same amount of carbon as watching an hour of Netflix.

[^1]: These numbers aren't exact but are a good gauge. For reference, another scoring metric puts the [CO2 produced at 0.01g](https://www.websitecarbon.com/website/jaredeberle-org/). Regardless the basic point is the site uses minimal resources.

I've made a number of conscious choices to keep the impact of the site minimal while maintaining reasonable style choices:

- I run the blog with hugo, which generates all the pages as static files and minimizes the outputted CSS and javascript. I keep the javascript files as minimal as possible and do not source any outside libraries.
- The site uses self-hosted subsetted fonts (Fraunces, Charter, IBM Plex Mono) that reduce file sizes. IBM Plex Mono and the italicized Charter are only loaded on pages that explicitly need them.
- Images are AVIF format, lazy loaded, and responsive which reduces file sizes and only loads them on the page when needed.
- The website uses hashed files and immutable cache times for everything besides the html and RSS feeds. This seems resources are not redownload unless they change on the site.

## Accessibility

This site should also be fully compliant with web accessibility standards, if you run into issues, please {{< email "jared@jaredeberle.org" "let me know" >}} and I will work to fix the issue as best as possible.

## Privacy and Terms of Use

Further information on [privacy](/privacy) and [terms of use](/terms) can be found at those links but privacy boils down to I keep nothing about your visit and terms is really just please be kind and report issues you find. For errors you can either email me or submit a request through Git and GitHub through the Suggest Changes link at the top of every post.
