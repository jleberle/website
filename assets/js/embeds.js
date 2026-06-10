document.addEventListener("DOMContentLoaded", function () {

    // YouTube click-to-load
    document.querySelectorAll(".yt-facade").forEach(function (facade) {
        function loadYouTube() {
            var id = this.dataset.id;
            var iframe = document.createElement("iframe");
            iframe.src = "https://www.youtube-nocookie.com/embed/" + id + "?autoplay=1";
            iframe.title = "YouTube video player";
            iframe.style.position = "absolute";
            iframe.style.top = "0";
            iframe.style.left = "0";
            iframe.style.width = "100%";
            iframe.style.height = "100%";
            iframe.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture";
            iframe.allowFullscreen = true;
            this.style.cursor = "default";
            this.innerHTML = "";
            this.appendChild(iframe);
        }
        facade.addEventListener("click", loadYouTube);
        facade.addEventListener("keydown", function (e) {
            if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                loadYouTube.call(this);
            }
        });
    });

    // Bluesky click-to-load
    document.querySelectorAll(".bsky-facade").forEach(function (facade) {
        function loadBluesky() {
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
        }
        facade.addEventListener("click", loadBluesky);
        facade.addEventListener("keydown", function (e) {
            if (e.key === "Enter" || e.key === " ") {
                e.preventDefault();
                loadBluesky.call(this);
            }
        });
    });

});
