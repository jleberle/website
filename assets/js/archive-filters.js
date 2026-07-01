(function () {
    var archive = document.querySelector("[data-archive]");
    var tools = document.querySelector("[data-archive-tools]");
    if (!archive || !tools) return;

    var buttons = Array.prototype.slice.call(tools.querySelectorAll("[data-archive-filter-button]"));
    var entries = Array.prototype.slice.call(archive.querySelectorAll("[data-archive-entry]"));
    var searchInput = tools.querySelector("[data-archive-search-input]");
    var status = archive.querySelector("[data-archive-status]");
    var empty = archive.querySelector("[data-archive-empty]");
    var reset = archive.querySelector("[data-archive-reset]");
    if (!entries.length || !searchInput) return;

    tools.hidden = false;
    var activeFilter = "all";

    function setUrlFilter(filter) {
        if (!window.history || !window.URL) return;
        var url = new URL(window.location.href);
        if (filter === "all") {
            url.searchParams.delete("type");
        } else {
            url.searchParams.set("type", filter);
        }
        window.history.replaceState(null, "", url);
    }

    function applyFilter(filter, updateUrl) {
        activeFilter = filter;
        var query = searchInput.value.trim().toLocaleLowerCase();
        var visibleCount = 0;

        entries.forEach(function (entry) {
            var matchesType = filter === "all" || entry.dataset.archiveSection === filter;
            var matchesQuery = !query || entry.dataset.archiveSearchText.indexOf(query) !== -1;
            var isMatch = matchesType && matchesQuery;
            entry.classList.toggle("is-hidden", !isMatch);
            if (isMatch) visibleCount += 1;
        });

        buttons.forEach(function (button) {
            var isActive = button.dataset.archiveFilterButton === filter;
            button.classList.toggle("is-active", isActive);
            button.setAttribute("aria-pressed", String(isActive));
        });

        status.textContent = visibleCount === entries.length
            ? entries.length + " posts"
            : visibleCount + " of " + entries.length + " posts";
        empty.hidden = visibleCount !== 0;
        if (updateUrl) setUrlFilter(filter);
    }

    buttons.forEach(function (button) {
        button.addEventListener("click", function () {
            applyFilter(button.dataset.archiveFilterButton, true);
        });
    });

    searchInput.addEventListener("input", function () {
        applyFilter(activeFilter, false);
    });

    reset.addEventListener("click", function () {
        searchInput.value = "";
        applyFilter("all", true);
        searchInput.focus();
    });

    var params = new URLSearchParams(window.location.search);
    var requestedFilter = params.get("type") || "all";
    var hasRequestedFilter = buttons.some(function (button) {
        return button.dataset.archiveFilterButton === requestedFilter;
    });

    applyFilter(hasRequestedFilter ? requestedFilter : "all", false);
})();
