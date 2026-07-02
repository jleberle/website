(function () {
    var ledger = document.querySelector("[data-reading-ledger]");
    var list = document.querySelector("[data-reading-list]");
    var sortControls = document.querySelector("[data-reading-sort]");
    if (!ledger || !list || !sortControls) return;

    var buttons = Array.prototype.slice.call(sortControls.querySelectorAll("[data-reading-sort-button]"));
    var entries = Array.prototype.slice.call(list.querySelectorAll("[data-reading-entry]"));
    if (!buttons.length || !entries.length) return;

    function applySort(mode) {
        var attr = mode === "published" ? "sortPublished" : "sortRead";
        var sorted = entries.slice().sort(function (a, b) {
            return (b.dataset[attr] || "").localeCompare(a.dataset[attr] || "");
        });

        sorted.forEach(function (entry) {
            list.appendChild(entry);
        });

        buttons.forEach(function (button) {
            var active = button.dataset.readingSortButton === mode;
            button.classList.toggle("is-active", active);
            button.setAttribute("aria-pressed", String(active));
        });
    }

    buttons.forEach(function (button) {
        button.addEventListener("click", function () {
            applySort(button.dataset.readingSortButton);
        });
    });

    applySort("read");
})();
