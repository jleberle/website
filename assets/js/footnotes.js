// Footnote popovers. Clicking a footnote reference opens the note in place,
// read from the existing .footnotes list at the foot of the article, so there
// is no duplicated content and no template change. Progressive enhancement:
// without JS (or if a note isn't found) the reference still jumps to the foot
// of the page as normal. Loaded via the deferred bundle, so the DOM is ready.
(function () {
  var content = document.querySelector('.post-content');
  if (!content) return;
  var refs = content.querySelectorAll('a.footnote-ref');
  if (!refs.length) return;

  var pop = document.createElement('div');
  pop.className = 'fn-popover';
  pop.id = 'fn-popover';
  pop.setAttribute('role', 'note');
  document.body.appendChild(pop);

  var current = null; // the reference that opened the popover, or null

  // Clone the matching note's content, minus its back-link arrow.
  function noteHTML(ref) {
    var id = (ref.getAttribute('href') || '').slice(1); // "#fn:1" -> "fn:1"
    var li = id && document.getElementById(id);
    if (!li) return null;
    var clone = li.cloneNode(true);
    clone.querySelectorAll('.footnote-backref').forEach(function (b) { b.remove(); });
    return clone.innerHTML;
  }

  // Anchor below the reference, clamped to stay within the viewport width.
  function place(ref) {
    var r = ref.getBoundingClientRect();
    var pad = 8;
    var maxLeft = window.scrollX + document.documentElement.clientWidth - pop.offsetWidth - pad;
    var left = Math.max(window.scrollX + pad, Math.min(r.left + window.scrollX, maxLeft));
    pop.style.left = left + 'px';
    pop.style.top = (r.bottom + window.scrollY + 6) + 'px';
  }

  function open(ref) {
    var html = noteHTML(ref);
    if (html === null) return;
    pop.innerHTML = html;
    if (current) current.setAttribute('aria-expanded', 'false');
    pop.classList.add('is-open');
    place(ref);
    ref.setAttribute('aria-expanded', 'true');
    current = ref;
  }

  function close(focusRef) {
    if (!current) return;
    pop.classList.remove('is-open');
    current.setAttribute('aria-expanded', 'false');
    if (focusRef) current.focus();
    current = null;
  }

  refs.forEach(function (ref) {
    ref.setAttribute('aria-expanded', 'false');
    ref.setAttribute('aria-controls', 'fn-popover');
  });

  // Handle reference clicks in the CAPTURE phase, then stopPropagation, so we
  // run before — and suppress — PaperMod's per-anchor smooth-scroll handler
  // (footer.html binds every a[href^="#"], which otherwise also scrolls the
  // page down to the bottom footnote). preventDefault covers the native jump.
  content.addEventListener('click', function (e) {
    var ref = e.target.closest && e.target.closest('a.footnote-ref');
    if (!ref || !content.contains(ref)) return;
    if (noteHTML(ref) === null) return;   // unknown note -> leave default behavior
    e.preventDefault();
    e.stopPropagation();
    if (current === ref) { close(false); return; } // toggle
    open(ref);
  }, true);

  // Dismiss on outside click (footnote-ref clicks are handled above and never
  // reach here; clicks inside the popover are ignored so its links stay live).
  document.addEventListener('click', function (e) {
    if (!current) return;
    if (pop.contains(e.target)) return;
    close(false);
  });

  // Esc closes and returns focus to the reference.
  document.addEventListener('keydown', function (e) {
    if (e.key === 'Escape') close(true);
  });

  window.addEventListener('resize', function () { if (current) place(current); });
})();
