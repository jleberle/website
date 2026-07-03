document.querySelectorAll(".obf-email").forEach(function (el) {
  var a = atob(el.dataset.e);
  var t = atob(el.dataset.t);
  el.innerHTML = '<a href="mailto:' + a + '">' + t + '</a>';
});
