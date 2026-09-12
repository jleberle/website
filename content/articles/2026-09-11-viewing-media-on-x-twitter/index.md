---
title: "Viewing Media on X/Twitter"
slug: viewing-media-on-x-twitter
date: "2026-09-11T09:57:19-05:00"
draft: false
description: "How to avoid the login prompts"
tags:
  - "Media"
publishDate: "2026-09-11T11:33:06-05:00"
lastmod: "2026-09-11T11:33:06-05:00"
---

For a while now I've used Nitter/XCancel to view media on Elon Musk's hell site. Unfortunately in August X sent a [cease and desist letter to the developer of Nitter](https://github.com/zedeus/nitter) and all the instances went offline. They've now returned but the project has been archived on Github and reliability is probably questionable at best moving forward. At the same time X has increasingly restricted the ability to view content on the site without logging in but it is still possible.
<!-- more -->
All of the media on the page is publicly exposed, so a simple bookmarklet will show you the media (images, video) with a single click:

```js
javascript:(async()=>{let h=document.documentElement.innerHTML;try{h+=await(await fetch(location.href)).text()}catch(e){}h=h.replace(/\\\//g,'/').replace(/&amp;/g,'&');const imgs=[...new Set(h.match(/https:\/\/pbs\.twimg\.com\/media\/[\w-]+/g)||[])];const best={};(h.match(/https:\/\/video\.twimg\.com\/[^"'\s\\]+?\.mp4/g)||[]).forEach(u=>{const k=u.split('/vid/')[0],m=u.match(/\/(\d+)x(\d+)\//),s=m?m[1]*m[2]:1;if(!best[k]||s>best[k].s)best[k]={u,s}});const st='style="max-width:100vw;max-height:90vh;display:block;margin:0 auto 12px"';const o=imgs.map(u=>`<a href="${u}?format=jpg&name=orig"><img src="${u}?format=jpg&name=orig" ${st}></a>`).join('')+Object.values(best).map(v=>`<video src="${v.u}" controls playsinline ${st}></video>`).join('');if(!o)return alert('No media found');document.open();document.write(`<title>media</title><body style="margin:0;padding:12px;background:#111">${o}</body>`);document.close();})();
```


Like anything else this is liable to break as X continually works to force people into the app but for now it's a decent backup for something like XCancel or And A Dinosaur's [Litterbox extension](https://andadinosaur.com/launch-litterbox).
