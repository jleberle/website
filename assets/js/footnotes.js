// Progressive footnotes. Wide screens receive accessible margin notes;
// narrower screens open the same source notes in a popover. Without JS (or if
// a note is not found), references still jump to the canonical list normally.
(function () {
  var content = document.querySelector('.post-content');
  if (!content) return;
  var refs = content.querySelectorAll('a.footnote-ref');
  if (!refs.length) return;
  var marginQuery = window.matchMedia('(min-width: 1280px)');

  var pop = document.createElement('div');
  pop.className = 'fn-popover';
  pop.id = 'fn-popover';
  pop.setAttribute('role', 'note');
  document.body.appendChild(pop);

  var current = null; // the reference that opened the popover, or null

  // Clone the matching note's content, minus its back-link arrow. Returns the
  // cloned <li> itself; callers move its children into place with
  // moveChildren rather than serializing it through innerHTML.
  function noteContent(ref) {
    var id = (ref.getAttribute('href') || '').slice(1); // "#fn:1" -> "fn:1"
    var li = id && document.getElementById(id);
    if (!li) return null;
    var clone = li.cloneNode(true);
    clone.querySelectorAll('.footnote-backref').forEach(function (b) { b.remove(); });
    return clone;
  }

  // Move every child of a detached node into target, in order — the DOM
  // equivalent of `target.innerHTML = source.innerHTML` without building or
  // parsing an HTML string.
  function moveChildren(target, source) {
    while (source.firstChild) target.appendChild(source.firstChild);
  }

  // On wide screens, copy each semantic footnote into the free outer margin.
  // The original list remains in the document for printing, feeds and no-JS
  // use, but is hidden while these accessible copies are active so assistive
  // technology does not announce every note twice.
  function buildSidenotes() {
    var madeOne = false;
    refs.forEach(function (ref, index) {
      var noteBody = noteContent(ref);
      var marker = ref.closest('sup');
      if (noteBody === null || !marker || ref.marginNote) return;

      var note = document.createElement('aside');
      note.className = 'margin-note';
      note.id = 'margin-note-' + (index + 1);
      note.setAttribute('role', 'note');
      note.setAttribute('aria-label', 'Footnote ' + ref.textContent);
      note.tabIndex = -1;
      note.referenceMarker = marker;

      var number = document.createElement('span');
      number.className = 'margin-note-number';
      number.setAttribute('aria-hidden', 'true');
      number.textContent = ref.textContent;
      note.appendChild(number);

      var body = document.createElement('div');
      body.className = 'margin-note-content';
      moveChildren(body, noteBody);
      note.appendChild(body);

      content.appendChild(note);
      ref.marginNote = note;
      ref.setAttribute('aria-describedby', note.id);
      ref.removeAttribute('aria-expanded');
      ref.removeAttribute('aria-controls');
      madeOne = true;
    });
    if (madeOne || content.querySelector('.margin-note')) {
      content.classList.add('sidenotes-active');
      positionSidenotes();
    }
  }

  // Absolutely position notes against the unchanged prose column. This keeps
  // them independent of a floated cover image while still stacking long or
  // closely spaced notes without collisions.
  function positionSidenotes() {
    if (!content.classList.contains('sidenotes-active')) return;
    content.style.minHeight = '';
    var contentTop = content.getBoundingClientRect().top;
    var nextTop = 0;

    content.querySelectorAll('.margin-note').forEach(function (note) {
      if (!note.referenceMarker) return;
      var referenceTop = note.referenceMarker.getBoundingClientRect().top - contentTop;
      var top = Math.max(referenceTop, nextTop);
      note.style.top = top + 'px';
      nextTop = top + note.offsetHeight + 16;
    });

    if (nextTop > content.offsetHeight) content.style.minHeight = nextTop + 'px';
  }

  function removeSidenotes() {
    refs.forEach(function (ref) {
      if (ref.marginNote) ref.marginNote.remove();
      ref.marginNote = null;
      ref.removeAttribute('aria-describedby');
      ref.setAttribute('aria-expanded', 'false');
      ref.setAttribute('aria-controls', 'fn-popover');
    });
    content.classList.remove('sidenotes-active');
    content.style.minHeight = '';
  }

  function syncSidenotes() {
    if (marginQuery.matches) {
      close(false);
      buildSidenotes();
    } else {
      removeSidenotes();
    }
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
    var noteBody = noteContent(ref);
    if (noteBody === null) return;
    pop.textContent = '';
    moveChildren(pop, noteBody);
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
    if (noteContent(ref) === null) return;   // unknown note -> leave default behavior
    e.preventDefault();
    e.stopPropagation();
    if (content.classList.contains('sidenotes-active')) {
      if (ref.marginNote) ref.marginNote.focus({ preventScroll: true });
      return;
    }
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

  syncSidenotes();
  marginQuery.addEventListener('change', syncSidenotes);
  if (document.fonts && document.fonts.ready) document.fonts.ready.then(positionSidenotes);
  window.addEventListener('resize', function () {
    if (current) place(current);
    positionSidenotes();
  });
})();
