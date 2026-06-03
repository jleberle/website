document.addEventListener("DOMContentLoaded", function () {

    // YouTube click-to-load
    document.querySelectorAll(".yt-facade").forEach(function (facade) {
        facade.addEventListener("click", function () {
            var id = this.dataset.id;
            var iframe = document.createElement("iframe");
            iframe.src = "https://www.youtube-nocookie.com/embed/" + id + "?autoplay=1";
            iframe.width = "100%";
            iframe.height = "100%";
            iframe.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture";
            iframe.allowFullscreen = true;
            iframe.loading = "lazy";
            this.replaceWith(iframe);
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
