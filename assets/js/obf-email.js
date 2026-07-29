document.querySelectorAll(".obf-email").forEach(function (el) {
  var address = atob(el.dataset.e);
  var text = atob(el.dataset.t);
  var link = document.createElement("a");
  link.href = "mailto:" + address;
  link.textContent = text;
  el.textContent = "";
  el.appendChild(link);
});
