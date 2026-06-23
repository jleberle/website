(function () {
    var archive = document.querySelector("[data-archive]");
    var filters = document.querySelector("[data-archive-filters]");
    if (!archive || !filters) return;

    var buttons = Array.prototype.slice.call(filters.querySelectorAll("[data-archive-filter-button]"));
    var entries = Array.prototype.slice.call(archive.querySelectorAll("[data-archive-entry]"));
    var months = Array.prototype.slice.call(archive.querySelectorAll("[data-archive-month]"));
    var years = Array.prototype.slice.call(archive.querySelectorAll("[data-archive-year]"));
    if (!buttons.length || !entries.length) return;

    filters.hidden = false;

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

    function updateGroups() {
        months.forEach(function (month) {
            var hasVisibleEntry = month.querySelector("[data-archive-entry]:not(.is-hidden)");
            month.classList.toggle("is-hidden", !hasVisibleEntry);
        });

        years.forEach(function (year) {
            var hasVisibleMonth = year.querySelector("[data-archive-month]:not(.is-hidden)");
            year.classList.toggle("is-hidden", !hasVisibleMonth);
        });
    }

    function applyFilter(filter, updateUrl) {
        entries.forEach(function (entry) {
            var isMatch = filter === "all" || entry.dataset.archiveSection === filter;
            entry.classList.toggle("is-hidden", !isMatch);
        });

        buttons.forEach(function (button) {
            var isActive = button.dataset.archiveFilterButton === filter;
            button.classList.toggle("is-active", isActive);
            button.setAttribute("aria-pressed", String(isActive));
        });

        updateGroups();
        if (updateUrl) setUrlFilter(filter);
    }

    buttons.forEach(function (button) {
        button.addEventListener("click", function () {
            applyFilter(button.dataset.archiveFilterButton, true);
        });
    });

    var params = new URLSearchParams(window.location.search);
    var requestedFilter = params.get("type") || "all";
    var hasRequestedFilter = buttons.some(function (button) {
        return button.dataset.archiveFilterButton === requestedFilter;
    });

    applyFilter(hasRequestedFilter ? requestedFilter : "all", false);
})();
