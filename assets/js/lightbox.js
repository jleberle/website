(function () {
  var overlay, overlayImg, overlayClose, lastFocused;

  // <dialog>.showModal() gives us all of this for free: an implicit
  // role="dialog"/aria-modal="true", a focus trap (Tab can't escape to the
  // page behind it), Escape-to-close, and every other top-level element
  // made inert to keyboard/AT automatically. None of that needs hand-rolling
  // the way it did for the old plain-<div> overlay.
  function createOverlay() {
    overlay = document.createElement('dialog');
    overlay.id = 'lightbox-overlay';
    overlay.setAttribute('aria-label', 'Image lightbox');

    overlayImg = document.createElement('img');
    overlayImg.id = 'lightbox-img';
    overlayImg.alt = '';

    // Swapping .src on an <img> that's still showing a previously decoded
    // photo leaves that photo on screen until the new one finishes loading,
    // which reads as a flash of the wrong image rather than a load
    // transition. Hide it the moment a new src is assigned (openLightbox
    // below) and reveal again once the new image is actually ready.
    function reveal() { overlayImg.style.visibility = ''; }
    overlayImg.addEventListener('load', reveal);
    overlayImg.addEventListener('error', reveal);

    overlayClose = document.createElement('button');
    overlayClose.id = 'lightbox-close';
    overlayClose.type = 'button';
    overlayClose.setAttribute('aria-label', 'Close lightbox');
    overlayClose.textContent = '×';

    overlay.appendChild(overlayImg);
    overlay.appendChild(overlayClose);
    document.body.appendChild(overlay);

    // A click that lands on the dialog element itself (not overlayImg or
    // overlayClose) landed on the ::backdrop area — the same "click outside
    // to dismiss" gesture the old overlay div handled explicitly.
    overlay.addEventListener('click', function (e) {
      if (e.target === overlay || e.target === overlayClose) {
        overlay.close();
      }
    });

    // Fires on every close path — Escape, backdrop click, or the close
    // button — so cleanup lives in exactly one place.
    overlay.addEventListener('close', function () {
      document.body.style.overflow = '';
      if (lastFocused) {
        lastFocused.focus();
        lastFocused = null;
      }
    });
  }

  // Accepts either an <img> (covers, content images) or an <a> (a prose link
  // pointing at an image, tagged data-lightbox-src by render-link.html).
  function openLightbox(el) {
    lastFocused = el;
    overlayImg.style.visibility = 'hidden';
    overlayImg.src = el.dataset.lightboxSrc || el.src || el.getAttribute('href');
    overlayImg.alt = el.alt || el.getAttribute('aria-label') || (el.textContent || '').trim();
    document.body.style.overflow = 'hidden';
    overlay.showModal();
    overlayClose.focus();
  }

  document.addEventListener('DOMContentLoaded', function () {
    createOverlay();

    document.querySelectorAll('.post-content img, .md-content img, .post-single .entry-cover img[data-lightbox-src]').forEach(function (img) {
      // YouTube facades and carousels have their own click/keyboard handling
      if (img.closest('.yt-facade') || img.closest('.carousel')) return;
      img.style.cursor = 'zoom-in';
      img.setAttribute('tabindex', '0');
      img.setAttribute('role', 'button');
      // role=button needs an accessible name; an empty alt provides none, so
      // fall back to the figure's caption, then to a generic label.
      if (!img.alt) {
        var fig = img.closest('figure');
        var cap = fig && fig.querySelector('figcaption');
        var name = cap && cap.textContent.trim();
        img.setAttribute('aria-label', name || 'View full-size image');
      }
      img.addEventListener('click', function (e) {
        e.preventDefault();
        openLightbox(img);
      });
      img.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          openLightbox(img);
        }
      });
    });

    // Prose links pointing at an image (render-link.html tags them with
    // data-lightbox-src) open in the lightbox instead of navigating. Anchors
    // are natively focusable and Enter fires a click, so no extra keyboard
    // wiring is needed. Skip an image-as-link wrapper (the inner img already
    // handles its own click) to avoid a double-open.
    document.querySelectorAll('.post-content a[data-lightbox-src], .md-content a[data-lightbox-src]').forEach(function (a) {
      if (a.querySelector('img[data-lightbox-src]')) return;
      a.setAttribute('aria-haspopup', 'dialog');
      a.addEventListener('click', function (e) {
        e.preventDefault();
        openLightbox(a);
      });
    });
  });
})();
