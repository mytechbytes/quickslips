import type { BillData, Business } from "./form"
import { t } from "./i18n"

type Reply = { id: number; svg?: string; error?: string }

/**
 * typst.ts draws every page of the document into one SVG, one under the other. This cuts it into one SVG for each page
 * (the same drawing, seen through a window the size of the page), so the preview can show a page at a time.
 */
export function splitPages(svg: string): string[] {
  const doc = new DOMParser().parseFromString(svg, "image/svg+xml")
  const root = doc.documentElement
  if (root.nodeName !== "svg") return [svg]
  const pages = Array.from(root.querySelectorAll("g.typst-page"))
  if (pages.length < 2) return [svg]

  const box = (root.getAttribute("viewBox") ?? "").split(/[\s,]+/).map(Number)
  const totalWidth = Number(root.getAttribute("width")) || box[2] || 0
  const totalHeight = Number(root.getAttribute("height")) || box[3] || 0
  const offsets = pages.map((page) => {
    const match = /translate\(\s*([-\d.]+)[ ,]+([-\d.]+)\s*\)/.exec(page.getAttribute("transform") ?? "")
    return match ? Number(match[2]) : 0
  })

  return pages.map((page, i) => {
    const y = offsets[i]
    const width = Number(page.getAttribute("data-page-width")) || totalWidth
    const height = Number(page.getAttribute("data-page-height")) || (offsets[i + 1] ?? totalHeight) - y
    const copy = root.cloneNode(true) as Element
    copy.setAttribute("viewBox", `0 ${y} ${width} ${height}`)
    copy.setAttribute("width", String(width))
    copy.setAttribute("height", String(height))
    return new XMLSerializer().serializeToString(copy)
  })
}

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
  // The pictures on the document: where the logo (of the chosen business) and the signature (the chosen one) are,
  // then their bytes by file name, and the names to put in the data.
  const urls: Record<string, string | null> = { logo: null, signature: null, driver_signature: null, stamp: null }
  let images: Record<string, Uint8Array> = {}
  let imageNames: Record<string, string> = {}
  let pictureToken = 0
  // The sheet chosen for the document ("a4", "a5", "us-letter"), or "" for the size of the layout.
  let paper = ""
  // The margins chosen ("narrow", "wide"), or "" for the layout's own.
  let margin = ""

  const img = document.createElement("img")
  img.alt = t("preview_alt")
  img.className = "max-h-[75vh] w-auto bg-white shadow lg:max-h-[calc(100vh-14rem)]"

  // A document of several pages (a receipt for each month) shows one page at a time, with buttons to go through them.
  let pages: string[] = []
  let pageIndex = 0
  const nav = document.createElement("div")
  nav.id = "preview-pages"
  nav.className = "mt-3 flex items-center justify-center gap-3 text-sm/6 text-ink"
  const buttonClass =
    "inline-flex size-9 items-center justify-center rounded-field border border-line-strong bg-surface text-ink transition-colors hover:bg-surface-muted focus-visible:outline-2 focus-visible:outline-focus disabled:cursor-not-allowed disabled:opacity-40"
  const previous = document.createElement("button")
  previous.type = "button"
  previous.id = "preview-prev"
  previous.className = buttonClass
  previous.textContent = "‹"
  previous.setAttribute("aria-label", t("preview_prev"))
  const next = document.createElement("button")
  next.type = "button"
  next.id = "preview-next"
  next.className = buttonClass
  next.textContent = "›"
  next.setAttribute("aria-label", t("preview_next"))
  const counter = document.createElement("span")
  counter.id = "preview-page"
  counter.setAttribute("aria-live", "polite")
  nav.append(previous, counter, next)

  const frame = document.createElement("div")
  frame.className = "flex flex-col items-center"
  frame.append(img, nav)

  function showPage() {
    const url = URL.createObjectURL(new Blob([pages[pageIndex]], { type: "image/svg+xml" }))
    img.src = url
    if (currentUrl) URL.revokeObjectURL(currentUrl)
    currentUrl = url
    nav.classList.toggle("hidden", pages.length < 2)
    counter.textContent = t("preview_page", { page: pageIndex + 1, total: pages.length })
    previous.disabled = pageIndex === 0
    next.disabled = pageIndex >= pages.length - 1
  }
  previous.addEventListener("click", () => {
    if (pageIndex > 0) pageIndex--
    showPage()
  })
  next.addEventListener("click", () => {
    if (pageIndex < pages.length - 1) pageIndex++
    showPage()
  })

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
    pages = splitPages(clean)
    pageIndex = Math.min(pageIndex, pages.length - 1) // the page being read stays, unless the document got shorter
    showPage()
    if (!frame.isConnected) opts.container.replaceChildren(frame)
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
      data: { ...data, ...imageNames, ...(paper ? { paper_size: paper } : {}), ...(margin ? { margin_size: margin } : {}) },
      images,
      text,
      region,
      fonts: opts.fonts,
    })
  }

  // Fetches the pictures that are chosen and draws the preview with them.
  async function loadPictures() {
    const token = ++pictureToken
    const nextImages: Record<string, Uint8Array> = {}
    const nextNames: Record<string, string> = {}

    for (const [key, url] of Object.entries(urls)) {
      if (!url) continue
      const response = await fetch(url).catch(() => null)
      if (!response?.ok) continue // no picture is better than no preview
      const name = key + url.slice(url.lastIndexOf(".")) // "logo.png"
      nextImages[name] = new Uint8Array(await response.arrayBuffer())
      nextNames[key] = name
    }

    if (token !== pictureToken) return // the user chose something else meanwhile
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
    /** Use the logo of this business (or none) in the preview. */
    setBusiness(business: Business | null) {
      urls.logo = business?.logo_url ?? null
      return loadPictures()
    },
    /** Use the signature at this address (or the empty place to sign) in the preview. */
    setSignature(url: string | null) {
      urls.signature = url
      return loadPictures()
    },
    /** Draw the document with these margins (`""`: the layout's own). A roll receipt ignores it, as the PDF does. */
    setMargin(choice: string) {
      margin = choice
      if (lastData) renderNow(lastData)
    },
    /** Draw the document on this sheet (`""`: the layout's own size). A roll receipt ignores it, as the PDF does. */
    setPaper(choice: string) {
      paper = choice
      if (lastData) renderNow(lastData)
    },
    /** Use the driver's signature at this address (or the empty place to sign by hand) in the preview. */
    setDriverSignature(url: string | null) {
      urls.driver_signature = url
      return loadPictures()
    },
    /** Use the further signature `slot` ("signature_3", ...) at this address (or the place to sign by hand) in the preview. */
    setExtraSignature(slot: string, url: string | null) {
      urls[slot] = url
      return loadPictures()
    },
    /** Use the revenue stamp at this address, or (none) the empty box in the preview. */
    setStamp(url: string | null) {
      urls.stamp = url
      return loadPictures()
    },
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
