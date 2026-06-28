---
title: About
hidemetadata: true
description: "About myself and the website you're visiting"
summary: "This is who I am and how I made this little website"
---

## The Human

Welcome to my tiny little corner of the internet. My name is Jared Eberle and I'm currently a lecturer at Oklahoma State University where I teach primarily first year US history surveys and Oklahoma History. Otherwise my research focus has traditionally been on Indigenous activism in the latter half of the 20th century with a particular focus on the American Indian Movement following the occupation of Wounded Knee, South Dakota in 1973. More about all of that can be found on [my CV](/cv). 

As for here, this little corner is largely meant for myself, to track the [things I've read](/reviews), the [quotes from books](/quotes) I like, or some [longer pieces of historical randomness](/articles). While I maintain a presence on social media, I have largely removed myself from it and my mental health has generally gotten better and I don't feel like I'm missing all that much. If you need to contact me for any reason, {{< email "jared@jaredeberle.org" "email" >}}  ([PGP Key](/key.asc)) is probably the best way to get in touch, but I will see your message if you send it through the Fediverse (Bluesky/Mastodon) because it'll show up on my [Micro.blog](https://eberle.blog) and you can follow me at [jared@eberle.blog](https://micro.blog/eberle). 

If you're curious what takes up my time, here's my [media diet](/sources) and the [things I use](/uses). 

## The Site

This site is built with [Hugo](https://gohugo.io) and served through [Codeberg](https://codeberg.org/jleberle/website) and [Statichost.eu](https://statichost.eu). The base theme for the site is [PaperMod](https://github.com/adityatelange/hugo-PaperMod/) which I have customized with the help of Claude. Claude has only touched back-end files on the site, everything you see publicly is written and edited by me, a [real human](/humans.txt). Typos are my own but for errors, please blame my cat.

I've worked to make this site as environmentally friendly as possible meaning the home page uses only [0.089g of carbon dioxide](https://digitalbeacon.co/report/jaredeberle-org) for a first time visitor.[^1] In terms of my [biggest page](/articles/past-and-future-of-indian-rodeo-in-las-vegas/), it only uses 0.183g and downloads at under 600KB for a first time visitor whereas a standard news article on any major site will download 2-3MB of data (10 times the amount). This is the result of a number of very opinionated decisions:

[^1]: It used to be 0.008g but I added a self-hosted font to make the site better for readability.

- A static blog like Hugo is more efficient than software like Wordpress and to
  further enhance that, all resources are minified when built.
- Images are AVIF format, lazy loaded, and responsive which reduces file sizes and only loads
  them when needed.
- All PDFs on the site are optimized for web delivery.
- The website uses long cache times, so users are not re-downloading content
  except the html itself.

This site should also be fully compliant with web accessibility standards, if you run into issues, please {{< email "jared@jaredeberle.org" "let me know" >}} and I will work to fix the issue as best as possible.

Finally, if you find anything wrong on the site you can either email me or submit a request through Git and Codeberg through the Suggest Changes link at the top of every post.

## Privacy

I take internet privacy seriously and have worked to keep this site as self-contained as possible which protects privacy with the added benefit of speeding up the site. My promises as long as this site exists are the following:

- No tracking is used on this website, I utilize Statichost.eu for serving the site and they receive your IP address but they are EU based and do not keep logs. Their privacy policy is [available on their website](https://www.statichost.eu/privacy/). 
- The only outside embeds I use (or may use) are Bluesky and Youtube. Both are
  click-to-load, so no resources are sent to either unless you click on the embed. When using Youtube it utilizes Youtube's privacy enhanced URL. Clicking to load will send your IP to [Youtube](https://www.youtube.com/howyoutubeworks/privacy/) and [Bluesky](https://bsky.social/about/support/privacy-policy) under their privacy policies.
- No ads, affiliate links or other revenue generating partnerships are served on this website.
- In terms of site storage, I use one non-system font (Source Serif) and it's self-hosted. The theme will set one value in your browser's localStorage for the theme toggle but no cookies are used. The search feature downloads a json index which runs entirely in your browser.

### Your Data and GDPR Rights

I am the sole data controller for the website, but the site stores essentially nothing and I see nothing. There is nothing of your personal data stored by the site and as a result nothing to delete. In the event you email me, I use Proton Mail and all emails are stored on their servers with strong privacy protections. Emails will not be made public without approval and will be deleted on request. 	

## Terms of Use

All original content on this site is offered under a [Creative Commons BY-NC-SA license](https://creativecommons.org/licenses/by-nc-sa/4.0/). Any use of the original content must be appropriately attributed, for non-commercial use, and shared under the same license.

Everything on this site is provided as is. There may very well be errors (that I will correct if you let me know). Any views expressed on this site are my own and do not represent the views of my employer or anyone else.

Once you leave the site I no longer control what you do or experience.

AI bots are not allowed to scrape or utilize data on this site for training AI models as defined by my [robots.txt](/robots.txt), [ai.txt](/ai.txt), and `X-Robots-Tag: noai` header. I ask you do not provide material from this site to bots as well.

Please don't attack the site, hosting provider or anything else connected to the site because of what you find here. 

This site is operated in Oklahoma, US.

If you need to discuss anything above you can find my [contact information here](/contact)