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

    // A new country brings its own currency.
    chooseCurrency(null)
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

// The currency the visitor chose in the switch. It is kept in the browser (`localStorage`), for every page; the
// bill's page uses it for the money of the form, the preview and the PDF. Without a choice a page has its country's
// own currency (`data-default` of the select and of the label).
const CURRENCY_KEY = "qs_currency"

/** The code of the currency the visitor chose, or `null` for the country's own. */
export function chosenCurrency(): string | null {
  try {
    return localStorage.getItem(CURRENCY_KEY)
  } catch {
    return null
  }
}

function chooseCurrency(code: string | null) {
  try {
    if (code) localStorage.setItem(CURRENCY_KEY, code)
    else localStorage.removeItem(CURRENCY_KEY)
  } catch {
    // no storage (a private window): the choice lasts until the page goes
  }
  showCurrency()
}

// Every select of the switch (header and footer) and the label of the button show the same currency.
function showCurrency() {
  const chosen = chosenCurrency()
  for (const select of document.querySelectorAll<HTMLSelectElement>("select[data-currency-select]")) {
    const wanted = chosen ?? select.dataset.default ?? ""
    if ([...select.options].some((option) => option.value === wanted)) select.value = wanted
  }
  for (const label of document.querySelectorAll<HTMLElement>("[data-currency-label]")) {
    label.textContent = chosen ?? label.dataset.default ?? ""
  }
}

document.addEventListener("change", (event) => {
  const select = event.target
  if (!(select instanceof HTMLSelectElement) || !select.hasAttribute("data-currency-select")) return

  chooseCurrency(select.value === select.dataset.default ? null : select.value)
  window.dispatchEvent(new CustomEvent("qs:currency"))
})
document.addEventListener("DOMContentLoaded", showCurrency)
window.addEventListener("phx:page-loading-stop", showCurrency)
