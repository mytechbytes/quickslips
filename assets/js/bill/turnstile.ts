declare global {
  interface Window {
    turnstile?: {
      render: (el: HTMLElement, options: Record<string, unknown>) => string
      reset: (widgetId?: string) => void
    }
  }
}

const SRC = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit"
let loading: Promise<void> | null = null

function loadScript(): Promise<void> {
  loading ??= new Promise<void>((resolve, reject) => {
    const script = document.createElement("script")
    script.src = SRC
    script.async = true
    script.onload = () => resolve()
    script.onerror = () => reject(new Error("Turnstile failed to load"))
    document.head.append(script)
  })
  return loading
}

/** Renders the widget once and returns `token()`, which resolves with a fresh, single-use token. */
export async function createTurnstile(container: HTMLElement, siteKey: string) {
  await loadScript()
  let waiting: ((token: string) => void) | null = null // a download that is waiting for a token
  let ready: string | null = null // a token nobody has used yet

  const widgetId = window.turnstile!.render(container, {
    sitekey: siteKey,
    appearance: "interaction-only", // visible only if Cloudflare needs the user to do something
    callback: (token: string) => {
      if (waiting) {
        // A download is already waiting: hand the token over and start on the next one.
        const resolve = waiting
        waiting = null
        resolve(token)
        window.turnstile!.reset(widgetId)
      } else {
        ready = token
      }
    },
  })

  return {
    token(): Promise<string> {
      if (ready) {
        const token = ready
        ready = null
        window.turnstile!.reset(widgetId) // tokens are single-use
        return Promise.resolve(token)
      }
      return new Promise((resolve) => (waiting = resolve))
    },
  }
}
