// Copy-to-clipboard button for code blocks. Progressive enhancement: without
// the Clipboard API (older browser, insecure context) this just does
// nothing, so a code block has no button rather than a broken one.
(function () {
  if (!navigator.clipboard || !navigator.clipboard.writeText) return;
  var blocks = document.querySelectorAll('.md-content pre > code');
  if (!blocks.length) return;

  blocks.forEach(function (code) {
    var pre = code.parentElement;
    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'copy-code-button';
    button.setAttribute('aria-label', 'Copy code to clipboard');
    button.textContent = 'Copy';

    var resetTimer = null;
    button.addEventListener('click', function () {
      navigator.clipboard.writeText(code.textContent).then(
        function () { setState('Copied!', true); },
        function () { setState('Failed', false); }
      );
    });

    function setState(label, copied) {
      clearTimeout(resetTimer);
      button.textContent = label;
      button.classList.toggle('is-copied', copied);
      resetTimer = setTimeout(function () {
        button.textContent = 'Copy';
        button.classList.remove('is-copied');
      }, 2000);
    }

    pre.appendChild(button);
  });
})();
