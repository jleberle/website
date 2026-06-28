(function () {
  var overlay, overlayImg, overlayClose, lastFocused;

  function createOverlay() {
    overlay = document.createElement('div');
    overlay.id = 'lightbox-overlay';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.setAttribute('aria-label', 'Image lightbox');

    overlayImg = document.createElement('img');
    overlayImg.id = 'lightbox-img';
    overlayImg.alt = '';

    overlayClose = document.createElement('button');
    overlayClose.id = 'lightbox-close';
    overlayClose.setAttribute('aria-label', 'Close lightbox');
    overlayClose.textContent = '×';

    overlay.appendChild(overlayImg);
    overlay.appendChild(overlayClose);
    document.body.appendChild(overlay);

    overlay.addEventListener('click', function (e) {
      if (e.target === overlay || e.target === overlayClose) {
        closeLightbox();
      }
    });

    document.addEventListener('keydown', function (e) {
      if (!overlay.classList.contains('is-open')) return;
      if (e.key === 'Escape') {
        closeLightbox();
      } else if (e.key === 'Tab') {
        // The close button is the only focusable control in the overlay, so
        // trap Tab on it — focus can't escape to the page behind the modal.
        e.preventDefault();
        overlayClose.focus();
      }
    });
  }

  // Accepts either an <img> (covers, content images) or an <a> (a prose link
  // pointing at an image, tagged data-lightbox-src by render-link.html).
  function openLightbox(el) {
    lastFocused = el;
    overlayImg.src = el.dataset.lightboxSrc || el.src || el.getAttribute('href');
    overlayImg.alt = el.alt || el.getAttribute('aria-label') || (el.textContent || '').trim();
    overlay.classList.add('is-open');
    document.body.style.overflow = 'hidden';
    overlayClose.focus();
  }

  function closeLightbox() {
    overlay.classList.remove('is-open');
    document.body.style.overflow = '';
    if (lastFocused) {
      lastFocused.focus();
      lastFocused = null;
    }
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
