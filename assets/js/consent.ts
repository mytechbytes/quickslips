// What a visitor decides about Google Analytics. Every visitor is asked, wherever they are (the banner is in the root
// layout). Nothing of Google's loads before the visitor agrees.
//
// The choice is kept in this browser, not in a cookie: the server never learns it, and it needs no cookie of its own.
// A visitor is asked again after a year.

const KEY = "quickslips-consent"
const A_YEAR = 365 * 24 * 60 * 60 * 1000

type Choice = "granted" | "denied"

/** What the choice starts and stops: the visit statistics. */
export interface Analytics {
  start(): void
  stop(): void
}

function savedChoice(): Choice | null {
  try {
    const saved = JSON.parse(localStorage.getItem(KEY) ?? "null")
    const known = saved?.analytics === "granted" || saved?.analytics === "denied"
    if (known && Date.now() - saved.at < A_YEAR) return saved.analytics
  } catch {
    // no storage, or something else in it: the visitor is asked
  }
  return null
}

function saveChoice(choice: Choice): void {
  try {
    localStorage.setItem(KEY, JSON.stringify({ analytics: choice, at: Date.now() }))
  } catch {
    // not remembered: the visitor is asked again on the next page
  }
}

export function mountConsent(analytics: Analytics): void {
  // The banner is in the root layout, outside the LiveView, so it keeps its state through live navigations. It is drawn
  // hidden and shown only when this browser has no choice, so nobody who has chosen sees it flash.
  const banner = document.getElementById("consent-banner")
  let opener: Element | null = null // what opened the banner again: it gets the focus back

  const choice = savedChoice()
  if (choice === "granted") analytics.start()
  if (choice === null && banner) banner.hidden = false

  // One listener on the document, like the other buttons of the page: LiveView redraws the footer, and a listener on
  // its button would be lost with it.
  document.addEventListener("click", (event) => {
    if (!(event.target instanceof Element)) return
    const open = event.target.closest("[data-consent-open]")
    const accept = event.target.closest("[data-consent-accept]")
    const reject = event.target.closest("[data-consent-reject]")

    if (open && banner) {
      opener = open
      banner.hidden = false
      banner.querySelector("button")?.focus()
    } else if (accept || reject) {
      saveChoice(accept ? "granted" : "denied")
      if (banner) banner.hidden = true
      if (accept) analytics.start()
      else analytics.stop()
      if (opener instanceof HTMLElement) opener.focus()
      opener = null
    }
  })
}
