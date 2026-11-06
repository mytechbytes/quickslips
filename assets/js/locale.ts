// The language and country switch posts to /locale (see `UI.locale_menu/1`). It must tell the server which page the
// visitor is on, so the server can send them to the same page in the new locale. The address is read when the form is
// submitted, so it is right after a live navigation too. Without scripts the server reads the Referer instead.
document.addEventListener("submit", (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement) || !form.hasAttribute("data-locale-form")) return

  const from = form.elements.namedItem("from")
  if (from instanceof HTMLInputElement) from.value = location.pathname + location.search
})
