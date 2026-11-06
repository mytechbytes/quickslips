// The language and country switch posts to /locale (see `UI.locale_menu/1`). It must tell the server which page the
// visitor is on, so the server can send them to the same page in the new locale. The address is read when the form is
// submitted, so it is right after a live navigation too. Without scripts the server reads the Referer instead.
document.addEventListener("submit", async (event) => {
  const form = event.target
  if (!(form instanceof HTMLFormElement) || !form.hasAttribute("data-locale-form")) return

  const from = form.elements.namedItem("from")
  if (from instanceof HTMLInputElement) from.value = location.pathname + location.search

  // Post it ourselves: the server answers with where to go, and a catalogue can move to another by a live
  // navigation (no new page), where a redirect would load everything again. Any failure falls back to the plain form.
  const submitter = event.submitter
  if (!(submitter instanceof HTMLButtonElement) || !window.fetch) return
  event.preventDefault()

  try {
    const response = await fetch(form.action, {
      method: "POST",
      body: new FormData(form, submitter),
      headers: { "x-locale-switch": "fetch" },
      credentials: "same-origin",
    })
    if (!response.ok) throw new Error(String(response.status))
    const { to, live, lang } = (await response.json()) as { to: string; live: boolean; lang: string }

    submitter.closest("dialog")?.close()
    const liveSocket = (window as unknown as { liveSocket?: { isConnected(): boolean } }).liveSocket
    if (live && liveSocket?.isConnected() && document.querySelector("[data-phx-main]")) {
      // The page's language: the browser picks fonts by it (the Han characters of Chinese and Japanese differ).
      document.documentElement.lang = lang
      const link = document.createElement("a")
      link.href = to
      link.setAttribute("data-phx-link", "redirect")
      link.setAttribute("data-phx-link-state", "push")
      link.hidden = true
      document.body.append(link)
      link.click()
      link.remove()
    } else {
      location.assign(to)
    }
  } catch {
    const choice = document.createElement("input")
    choice.type = "hidden"
    choice.name = submitter.name
    choice.value = submitter.value
    form.append(choice)
    HTMLFormElement.prototype.submit.call(form)
  }
})

// The language and country dialog (a native <dialog>, see `UI.locale_dialog/1`): a button with `data-dialog-open`
// opens the dialog it names, `data-dialog-close` closes the one it is in, and so does a click on the backdrop.
document.addEventListener("click", (event) => {
  const target = event.target
  if (!(target instanceof Element)) return

  const opener = target.closest<HTMLElement>("[data-dialog-open]")
  if (opener) {
    const dialog = document.getElementById(opener.dataset.dialogOpen!)
    if (dialog instanceof HTMLDialogElement && !dialog.open) dialog.showModal()
    return
  }

  if (target.closest("[data-dialog-close]")) {
    target.closest("dialog")?.close()
  } else if (target instanceof HTMLDialogElement && target.hasAttribute("data-backdrop-close")) {
    target.close()
  }
})

// The pages that have a locale in their address say which it is when they connect (`push_event "locale"`), so the
// LiveViews that have none (the dashboard) speak the language of the page the visitor came from, also after live
// navigations. The page's language is what the browser picks its fonts by.
window.addEventListener("phx:locale", (event) => {
  const { code, lang } = (event as CustomEvent<{ code: string; lang: string }>).detail
  document.documentElement.dataset.locale = code
  document.documentElement.lang = lang
})
