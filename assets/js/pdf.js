// PDF click-to-load. The facade is a native <button>, so Enter/Space activate
// it for free (no keydown handler needed).
//
// Native PDF viewers embedded in iframes frequently show only the first page
// on iOS/iPadOS. Touch-capable devices therefore open the document directly in
// the browser's full PDF viewer; desktop swaps the facade for an inline frame.
var prefersDirectPdf = navigator.maxTouchPoints > 0 ||
    window.matchMedia("(pointer: coarse)").matches;

if (prefersDirectPdf) {
    document.querySelectorAll(".pdf-facade-meta").forEach(function (meta) {
        meta.textContent = "PDF — tap to open";
    });
}

document.querySelectorAll(".pdf-facade").forEach(function (facade) {
    facade.addEventListener("click", function () {
        if (prefersDirectPdf) {
            window.location.assign(this.dataset.url);
            return;
        }

        var wrapper = document.createElement("div");
        wrapper.className = "pdf-embed";

        var iframe = document.createElement("iframe");
        iframe.src = this.dataset.url;
        iframe.title = this.getAttribute("aria-label") || "PDF document";

        wrapper.appendChild(iframe);
        this.closest(".pdf-block").replaceChild(wrapper, this);
    });
});
