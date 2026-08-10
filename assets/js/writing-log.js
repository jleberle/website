/* Writing log (/writing-log) — period tabs and column sorting.
 *
 * Pure enhancement. layouts/writing-log.html renders every panel and every row
 * server-side, each under its own heading; if this never runs the page is a
 * stack of complete, readable tables. Nothing here fetches or computes totals —
 * the numbers come from data/writing-log.json at build time.
 *
 * No inline styles anywhere: the site's CSP is `style-src 'self'` with no
 * 'unsafe-inline', so setting element.style.* is blocked. Visibility uses the
 * `hidden` attribute and classList only.
 */
(function () {
    var tabs = document.querySelector("[data-wl-tabs]");
    var panels = Array.prototype.slice.call(document.querySelectorAll("[data-wl-panel]"));
    if (!tabs || panels.length < 2) return;

    var buttons = Array.prototype.slice.call(tabs.querySelectorAll("[data-wl-tab]"));
    if (!buttons.length) return;

    function activate(id, focusTab) {
        buttons.forEach(function (button) {
            var selected = button.getAttribute("data-wl-tab") === id;
            button.classList.toggle("is-active", selected);
            button.setAttribute("aria-selected", selected ? "true" : "false");
            // Only the selected tab stays in the tab order; arrow keys move
            // between them, which is the expected tablist interaction.
            button.tabIndex = selected ? 0 : -1;
            if (selected && focusTab) button.focus();
        });
        panels.forEach(function (panel) {
            panel.hidden = panel.getAttribute("data-wl-panel") !== id;
        });
        if (window.history && window.URL) {
            var url = new URL(window.location.href);
            url.hash = "";
            window.history.replaceState(null, "", url.pathname + url.search + "#" + id);
        }
    }

    buttons.forEach(function (button, index) {
        button.addEventListener("click", function () {
            activate(button.getAttribute("data-wl-tab"), false);
        });
        button.addEventListener("keydown", function (event) {
            var step = event.key === "ArrowRight" ? 1 : event.key === "ArrowLeft" ? -1 : 0;
            if (!step) return;
            event.preventDefault();
            var next = (index + step + buttons.length) % buttons.length;
            activate(buttons[next].getAttribute("data-wl-tab"), true);
        });
    });

    tabs.hidden = false;
    // On the root element, not on `tabs` — the per-panel headings this hides
    // are siblings of the tablist, not descendants of it.
    document.documentElement.classList.add("wl-tabs-active");

    // Honour a #weeks / #months / #years / #days link; otherwise months, which
    // is the most useful default view of a writing record.
    var requested = (window.location.hash || "").replace(/^#/, "");
    var known = buttons.some(function (button) {
        return button.getAttribute("data-wl-tab") === requested;
    });
    activate(known ? requested : "months", false);

    /* ---- Column sorting ------------------------------------------------ */

    // Rows carry their own sort key in data-wl-value, so sorting never has to
    // parse "1,284" back out of the rendered text or guess at a date format.
    function sortTable(table, header) {
        var headers = Array.prototype.slice.call(table.querySelectorAll("thead th"));
        var index = headers.indexOf(header);
        if (index < 0) return;

        var numeric = header.getAttribute("data-wl-sort") === "num";
        var current = header.getAttribute("aria-sort");
        // First click on a new column sorts descending — for a writing log the
        // interesting end of every column is the big one, and for dates the
        // recent one.
        var descending = current !== "descending";

        var body = table.querySelector("tbody");
        var rows = Array.prototype.slice.call(body.rows);

        rows.sort(function (a, b) {
            var left = a.cells[index].getAttribute("data-wl-value") || a.cells[index].textContent.trim();
            var right = b.cells[index].getAttribute("data-wl-value") || b.cells[index].textContent.trim();
            var result = numeric
                ? parseFloat(left) - parseFloat(right)
                : left.localeCompare(right);
            return descending ? -result : result;
        });

        var fragment = document.createDocumentFragment();
        rows.forEach(function (row) { fragment.appendChild(row); });
        body.appendChild(fragment);

        headers.forEach(function (candidate) {
            if (candidate === header) {
                candidate.setAttribute("aria-sort", descending ? "descending" : "ascending");
            } else if (candidate.hasAttribute("aria-sort")) {
                candidate.removeAttribute("aria-sort");
            }
        });
    }

    Array.prototype.slice.call(document.querySelectorAll("[data-wl-sortable]")).forEach(function (table) {
        Array.prototype.slice.call(table.querySelectorAll("thead th[data-wl-sort]")).forEach(function (header) {
            // Marks the header as interactive for CSS, and only now — an
            // unenhanced header must not look clickable.
            header.setAttribute("data-wl-sortable-active", "");
            header.tabIndex = 0;
            header.addEventListener("click", function () { sortTable(table, header); });
            header.addEventListener("keydown", function (event) {
                if (event.key !== "Enter" && event.key !== " ") return;
                event.preventDefault();
                sortTable(table, header);
            });
        });
    });
})();
