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
      if (e.key === 'Escape' && overlay.classList.contains('is-open')) {
        closeLightbox();
      }
    });
  }

  function openLightbox(img) {
    lastFocused = img;
    overlayImg.src = img.dataset.lightboxSrc || img.src;
    overlayImg.alt = img.alt || '';
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

    document.querySelectorAll('.post-content img, .md-content img').forEach(function (img) {
      img.style.cursor = 'zoom-in';
      img.setAttribute('tabindex', '0');
      img.setAttribute('role', 'button');
      img.addEventListener('click', function () {
        openLightbox(img);
      });
      img.addEventListener('keydown', function (e) {
        if (e.key === 'Enter' || e.key === ' ') {
          e.preventDefault();
          openLightbox(img);
        }
      });
    });
  });
})();
