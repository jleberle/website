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

    function normalizeSearchText(value) {
        return value
            .toLocaleLowerCase()
            .normalize("NFD")
            .replace(/[\u0300-\u036f]/g, "")
            .replace(/[\u2018\u2019]/g, "'")
            .replace(/[^a-z0-9']+/g, " ")
            .trim();
    }

    // Exact substring match first; for terms of 3+ characters, fall back to a
    // sequential character-order check so a typo (e.g. "raech" for "reach")
    // still matches without needing a full fuzzy-search library.
    function fuzzyIncludes(text, term) {
        if (text.indexOf(term) !== -1) return true;
        if (term.length < 3) return false;

        var lastIndex = -1;
        for (var i = 0; i < term.length; i++) {
            var found = text.indexOf(term[i], lastIndex + 1);
            if (found === -1) return false;
            lastIndex = found;
        }
        return true;
    }

    function setUrlState(filter, query) {
        if (!window.history || !window.URL) return;
        var url = new URL(window.location.href);
        if (filter === "all") {
            url.searchParams.delete("type");
        } else {
            url.searchParams.set("type", filter);
        }
        if (query) {
            url.searchParams.set("q", query);
        } else {
            url.searchParams.delete("q");
        }
        window.history.replaceState(null, "", url);
    }

    function applyFilter(filter, updateUrl) {
        activeFilter = filter;
        var rawQuery = searchInput.value.trim();
        var queryTerms = normalizeSearchText(rawQuery).split(" ").filter(Boolean);
        var visibleCount = 0;
        var scopeCount = 0;

        entries.forEach(function (entry) {
            var matchesType = filter === "all" || entry.dataset.archiveSection === filter;
            var searchText = normalizeSearchText(entry.dataset.archiveSearchText);
            var matchesQuery = queryTerms.every(function (term) {
                return fuzzyIncludes(searchText, term);
            });
            var isMatch = matchesType && matchesQuery;
            entry.classList.toggle("is-hidden", !isMatch);
            if (matchesType) scopeCount += 1;
            if (isMatch) visibleCount += 1;
        });

        buttons.forEach(function (button) {
            var isActive = button.dataset.archiveFilterButton === filter;
            button.classList.toggle("is-active", isActive);
            button.setAttribute("aria-pressed", String(isActive));
        });

        var activeButton = buttons.find(function (button) {
            return button.dataset.archiveFilterButton === filter;
        });
        var filterLabel = activeButton ? activeButton.dataset.archiveFilterLabel : "posts";
        if (rawQuery) {
            status.textContent = visibleCount + " of " + scopeCount + " " + filterLabel + " matching “" + rawQuery + "”";
        } else if (filter === "all") {
            status.textContent = entries.length + " posts";
        } else {
            status.textContent = scopeCount + " " + filterLabel;
        }
        empty.hidden = visibleCount !== 0;
        if (updateUrl) setUrlState(filter, rawQuery);
    }

    buttons.forEach(function (button) {
        button.addEventListener("click", function () {
            applyFilter(button.dataset.archiveFilterButton, true);
        });
    });

    searchInput.addEventListener("input", function () {
        applyFilter(activeFilter, true);
    });

    document.addEventListener("keydown", function (event) {
        var target = event.target;
        var isTyping = target.matches("input, textarea, select") || target.isContentEditable;
        if (event.key === "/" && !event.metaKey && !event.ctrlKey && !event.altKey && !isTyping) {
            event.preventDefault();
            searchInput.focus();
        }
    });

    reset.addEventListener("click", function () {
        searchInput.value = "";
        applyFilter("all", true);
        searchInput.focus();
    });

    var params = new URLSearchParams(window.location.search);
    var requestedFilter = params.get("type") || "all";
    searchInput.value = params.get("q") || "";
    var hasRequestedFilter = buttons.some(function (button) {
        return button.dataset.archiveFilterButton === requestedFilter;
    });

    applyFilter(hasRequestedFilter ? requestedFilter : "all", false);
})();
