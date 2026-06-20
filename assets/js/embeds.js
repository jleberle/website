document.addEventListener("DOMContentLoaded", function () {

    // YouTube click-to-load. Facades are native <button>s, so Enter/Space
    // activate them for free (no keydown handler needed). An <iframe> can't
    // live inside a <button>, so replace the button with a wrapper element.
    document.querySelectorAll(".yt-facade").forEach(function (facade) {
        facade.addEventListener("click", function () {
            var wrapper = document.createElement("div");
            wrapper.className = "yt-embed";

            var iframe = document.createElement("iframe");
            iframe.src = "https://www.youtube-nocookie.com/embed/" + this.dataset.id + "?autoplay=1";
            iframe.title = "YouTube video player";
            iframe.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture";
            iframe.allowFullscreen = true;
            iframe.style.position = "absolute";
            iframe.style.inset = "0";
            iframe.style.width = "100%";
            iframe.style.height = "100%";
            iframe.style.border = "0";

            wrapper.appendChild(iframe);
            this.replaceWith(wrapper);
        });
    });

    // Bluesky click-to-load
    document.querySelectorAll(".bsky-facade").forEach(function (facade) {
        facade.addEventListener("click", function () {
            var url = this.dataset.url;

            var blockquote = document.createElement("blockquote");
            blockquote.className = "bluesky-embed";
            blockquote.dataset.blueskyUri = url;
            blockquote.dataset.blueskyCid = "";
            blockquote.innerHTML = '<a href="' + url + '">View on Bluesky</a>';

            var script = document.createElement("script");
            script.src = "https://embed.bsky.app/static/embed.js";
            script.async = true;
            script.charset = "utf-8";

            var wrapper = document.createElement("div");
            wrapper.appendChild(blockquote);
            wrapper.appendChild(script);

            this.replaceWith(wrapper);
        });
    });

});
