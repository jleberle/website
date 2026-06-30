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

I've worked to make this site as environmentally friendly as possible meaning the homepage uses only [0.013g of carbon dioxide](https://digitalbeacon.co/report/jaredeberle-org) for a first time visitor.[^1] In terms of my [biggest page](/articles/past-and-future-of-indian-rodeo-in-las-vegas/), it only uses 0.045g and downloads at just under 145KB for a first time visitor whereas a standard news article on any major site will download 2-3MB of data (20 times the amount). This is the result of a number of very opinionated decisions:

[^1]: It used to be 0.008g but I added a self-hosted font to make the site better for readability.

- A static blog like Hugo is more efficient than software like Wordpress and to
  further enhance that, all resources are minified when built.
- The site uses one self-hosted and subsetted font (Fraunces) for the headers while all
  remaining fonts are system fonts. This removes an extra outside url fetch and it removes unneeded weight from the font download. 
- Images are AVIF format, lazy loaded, and responsive which reduces file sizes and only loads
  them when needed.
- The website uses long cache times, so users are not re-downloading content
  except the html itself.

This site should also be fully compliant with web accessibility standards, if you run into issues, please {{< email "jared@jaredeberle.org" "let me know" >}} and I will work to fix the issue as best as possible.

Finally, if you find anything wrong on the site you can either email me or submit a request through Git and Codeberg through the Suggest Changes link at the top of every post.
