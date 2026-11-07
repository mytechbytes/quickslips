import type { BillData, Business } from "./form"
import { t } from "./i18n"

type Reply = { id: number; svg?: string; error?: string }

export function createPreview(opts: {
  workerUrl: string
  slug: string
  template: string
  container: HTMLElement
  status: HTMLElement
  // The two files every template reads next to its data, as JSON text: the words of the document's language
  // (`text.json`) and what its country and currency decide (`region.json`).
  text: string
  region: string
  // The font files of the language, as web paths (Noto Sans, and a Chinese or Japanese font for those languages).
  fonts: string[]
}) {
  const worker = new Worker(opts.workerUrl)
  // The words and the region of the document; the currency of the site switch changes them.
  let template = opts.template
  let text = opts.text
  let region = opts.region
  let source: string | null = null
  let helpers: string | null = null
  let latest = 0
  let timer: number | undefined
  let currentUrl: string | null = null
  let lastData: BillData | null = null
  // The pictures of the chosen business: the bytes by file name, and the names to put in the data.
  let images: Record<string, Uint8Array> = {}
  let imageNames: Record<string, string> = {}
  let businessToken = 0

  const img = document.createElement("img")
  img.alt = t("preview_alt")
  img.className = "max-h-[75vh] w-auto bg-white shadow lg:max-h-[calc(100vh-14rem)]"

  worker.onmessage = (event: MessageEvent<Reply>) => {
    const { id, svg, error } = event.data
    if (id !== latest) return // an older render finished late; ignore it
    if (error || !svg) {
      opts.status.textContent = t("preview_failed")
      console.error(error)
      return
    }
    // typst.ts puts a <script> in the SVG (for text selection). Its code is not valid XML, so <img>
    // would refuse the whole picture. We don't need it, so cut it out.
    const clean = svg.replace(/<script[\s\S]*?<\/script>/g, "")
    // Show the SVG through <img> (not innerHTML): scripts inside an SVG never run there.
    const url = URL.createObjectURL(new Blob([clean], { type: "image/svg+xml" }))
    img.src = url
    if (currentUrl) URL.revokeObjectURL(currentUrl)
    currentUrl = url
    if (!img.isConnected) opts.container.replaceChildren(img)
    opts.status.textContent = ""
  }

  async function loadSource() {
    if (source) return source
    const res = await fetch(`/source/${opts.slug}/${template}`)
    source = await res.text()
    return source
  }

  // The helpers every template imports (`_shared/helpers.typ`). They sit next to main.typ, as on the server.
  async function loadHelpers() {
    if (helpers) return helpers
    const res = await fetch("/source/_shared/helpers")
    helpers = await res.text()
    return helpers
  }

  async function renderNow(data: BillData) {
    lastData = data
    opts.status.textContent = t("preview_updating")
    const id = ++latest
    // The templates draw "logo" and "signature" when the data names a file, as the server does.
    worker.postMessage({
      id,
      source: await loadSource(),
      helpers: await loadHelpers(),
      data: { ...data, ...imageNames },
      images,
      text,
      region,
      fonts: opts.fonts,
    })
  }

  /** Use the logo and signature of this business (or none) in the preview. */
  async function setBusiness(business: Business | null) {
    const token = ++businessToken
    const wanted: Record<string, string | null> = {
      logo: business?.logo_url ?? null,
      signature: business?.signature_url ?? null,
    }
    const nextImages: Record<string, Uint8Array> = {}
    const nextNames: Record<string, string> = {}

    for (const [key, url] of Object.entries(wanted)) {
      if (!url) continue
      const response = await fetch(url).catch(() => null)
      if (!response?.ok) continue // no picture is better than no preview
      const name = key + url.slice(url.lastIndexOf(".")) // "logo.png"
      nextImages[name] = new Uint8Array(await response.arrayBuffer())
      nextNames[key] = name
    }

    if (token !== businessToken) return // the user chose another business meanwhile
    images = nextImages
    imageNames = nextNames
    if (lastData) renderNow(lastData)
  }

  return {
    renderNow,
    /** Another design of the same bill: its layout is fetched and the preview drawn again. */
    setTemplate(id: string) {
      template = id
      source = null
      if (lastData) renderNow(lastData)
    },
    /** The document is for another country or currency: use its words and region from now on. */
    setRegion(newText: string, newRegion: string) {
      text = newText
      region = newRegion
      if (lastData) renderNow(lastData)
    },
    setBusiness,
    /** The page is going away: stop the worker and let go of the last picture. */
    destroy() {
      window.clearTimeout(timer)
      worker.terminate()
      if (currentUrl) URL.revokeObjectURL(currentUrl)
    },
    /** Re-render after the user stops typing for `delay` ms (Task 6.3). */
    schedule(data: BillData, delay = 300) {
      window.clearTimeout(timer)
      timer = window.setTimeout(() => renderNow(data), delay)
    },
  }
}
