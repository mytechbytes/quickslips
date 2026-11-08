import { renderTurnstile } from "./turnstile"

type Widget = Awaited<ReturnType<typeof renderTurnstile>>

/**
 * The Turnstile check of the contact form (`ContactLive`). Draws the widget in `el`, whose `data-site-key` is the
 * site's key, and hands every token to `onToken`; `null` means there is none (the widget expired, failed, or could
 * not be loaded), and the server then asks the visitor to try again or to write by e-mail.
 */
export function mountContactCheck(el: HTMLElement, onToken: (token: string | null) => void) {
  const siteKey = el.dataset.siteKey
  let widget: Widget | null = null
  let stopped = false

  if (siteKey) {
    renderTurnstile(el, siteKey, onToken).then(
      (made) => {
        // The page may have gone while the script was loading.
        if (stopped) made.remove()
        else widget = made
      },
      () => onToken(null),
    )
  }

  return {
    /** A token is good for one check: asks the widget for a new one. */
    reset: () => widget?.reset(),
    stop: () => {
      stopped = true
      widget?.remove()
    },
  }
}
