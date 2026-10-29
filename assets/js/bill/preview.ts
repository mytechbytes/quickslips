import type { BillData } from "./form"

type Reply = { id: number; svg?: string; error?: string }

export function createPreview(opts: {
  workerUrl: string
  slug: string
  template: string
  container: HTMLElement
  status: HTMLElement
}) {
  const worker = new Worker(opts.workerUrl)
  let source: string | null = null
  let latest = 0
  let timer: number | undefined
  let currentUrl: string | null = null

  const img = document.createElement("img")
  img.alt = "Document preview"
  img.className = "max-h-[75vh] w-auto bg-white shadow"

  worker.onmessage = (event: MessageEvent<Reply>) => {
    const { id, svg, error } = event.data
    if (id !== latest) return // an older render finished late; ignore it
    if (error || !svg) {
      opts.status.textContent = "Preview could not be rendered."
      console.error(error)
      return
    }
    // Show the SVG through <img> (not innerHTML): scripts inside an SVG never run there.
    const url = URL.createObjectURL(new Blob([svg], { type: "image/svg+xml" }))
    img.src = url
    if (currentUrl) URL.revokeObjectURL(currentUrl)
    currentUrl = url
    if (!img.isConnected) opts.container.replaceChildren(img)
    opts.status.textContent = ""
  }

  async function loadSource() {
    if (source) return source
    const res = await fetch(`/source/${opts.slug}/${opts.template}`)
    source = await res.text()
    return source
  }

  async function renderNow(data: BillData) {
    opts.status.textContent = "Updating preview…"
    const id = ++latest
    worker.postMessage({ id, source: await loadSource(), data })
  }

  return {
    renderNow,
    /** Re-render after the user stops typing for `delay` ms (Task 6.3). */
    schedule(data: BillData, delay = 300) {
      window.clearTimeout(timer)
      timer = window.setTimeout(() => renderNow(data), delay)
    },
  }
}
