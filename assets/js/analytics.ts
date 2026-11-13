// Google Tag Manager. Which tags run, and when, is set in the Tag Manager account (tagmanager.google.com), not here:
// this only starts the container. It is loaded from the bundle, like Turnstile, because the layouts may reference only
// app.js and app.css. Whether it may start is for the visitor to say (consent.ts).

// Pages whose address holds a one-time token: the link of a log-in or of an e-mail confirmation (see the router).
// Google would receive the address with the page view, so Tag Manager is not started on them. Such a link always
// opens as a new page (it comes from an e-mail), so looking at the address once, here, is enough.
const ONE_TIME_LINKS = [/^\/users\/log-in\/[^/]+/, /^\/users\/settings\/confirm-email\/[^/]+/]

declare global {
  interface Window {
    dataLayer?: unknown[]
  }
}

let started = false

// Google's own helper. A command goes into the dataLayer as the `arguments` object itself: an array is not understood.
function gtag(..._command: unknown[]): void {
  window.dataLayer!.push(arguments)
}

/** Starts the container `id` (like "GTM-XXXXXXX"). This is Google's own loader; gtm.js loads without blocking the page. */
export function startTagManager(id: string): void {
  if (started || ONE_TIME_LINKS.some((link) => link.test(location.pathname))) return
  started = true

  window.dataLayer ??= []

  // What Google may do with the data, said before the container loads: statistics only. Whatever the Analytics account
  // is set to, nothing here is used for advertising.
  gtag("consent", "default", {
    analytics_storage: "granted",
    ad_storage: "denied",
    ad_user_data: "denied",
    ad_personalization: "denied",
  })

  // The `gtm.js` event has to be in the dataLayer before the container loads: it is what starts the container, and the
  // tags that run "on all pages" wait for it.
  window.dataLayer.push({ "gtm.start": Date.now(), event: "gtm.js" })

  const script = document.createElement("script")
  script.async = true
  script.src = `https://www.googletagmanager.com/gtm.js?id=${encodeURIComponent(id)}`
  document.head.append(script)
}

/**
 * The visitor takes the consent back. The script of a page that has started stays until the next page, so it is told
 * that nothing may be stored from now on, and what it has stored is deleted. The next page does not start it.
 */
export function stopTagManager(): void {
  if (started) gtag("consent", "update", { analytics_storage: "denied" })
  deleteGoogleCookies()
}

// Google's cookies are `_ga` and `_ga_` with a code. It sets them on the main domain of the site (example.com, not
// www.example.com), so the address and each domain above it are tried.
function deleteGoogleCookies(): void {
  const names = document.cookie
    .split(";")
    .map((cookie) => cookie.split("=")[0].trim())
    .filter((name) => name === "_ga" || name.startsWith("_ga_"))

  const labels = location.hostname.split(".")
  const domains: (string | undefined)[] = [undefined] // the cookie of this address alone
  for (let first = 0; first <= labels.length - 2; first++) domains.push(labels.slice(first).join("."))

  for (const name of names) {
    for (const domain of domains) {
      document.cookie = `${name}=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/` + (domain ? `; domain=${domain}` : "")
    }
  }
}
