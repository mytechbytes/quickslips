import { t } from "./i18n"

/** What the user chose for the watermark, as the server keeps it (see `QuickSlips.Watermark`). */
export type WatermarkSettings = { type: "text" | "image"; text?: string; layout: string; angle: number; count: number }

/** The watermark as the preview draws it: its settings, with the picture (if it is one) by the name the template reads. */
export type WatermarkPreview = { settings: WatermarkSettings & { image?: string }; image?: { name: string; bytes: Uint8Array } }

const MAX_IMAGE_BYTES = 1_500_000
// The angle a layout starts with, until the user types one of their own.
const DEFAULT_ANGLE: Record<string, number> = { diagonal: 45, horizontal: 0, vertical: 90, grid: 0 }

/**
 * The "Watermark" part of the advanced settings: a text or a picture, put `count` times in a layout (diagonal,
 * horizontal, vertical or grid), each turned by an angle. Calls `onChange` whenever something is chosen.
 */
export function createWatermark(root: HTMLElement, onChange: () => void) {
  const el = <T extends HTMLElement>(id: string) => root.querySelector<T>(`#${id}`)!
  const type = el<HTMLSelectElement>("watermark-type")
  const options = el("watermark-options")
  const textField = el("watermark-text-field")
  const imageField = el("watermark-image-field")
  const text = el<HTMLInputElement>("watermark-text")
  const file = el<HTMLInputElement>("watermark-image")
  const message = el("watermark-image-message")
  const layout = el<HTMLSelectElement>("watermark-layout")
  const angle = el<HTMLInputElement>("watermark-angle")
  const count = el<HTMLInputElement>("watermark-count")

  // The picture chosen: its bytes (for the preview) and as a data URL (for the download).
  let image: { name: string; bytes: Uint8Array; dataUrl: string } | null = null
  let angleTyped = false

  function show() {
    options.classList.toggle("hidden", type.value === "")
    textField.classList.toggle("hidden", type.value !== "text")
    imageField.classList.toggle("hidden", type.value !== "image")
  }

  /** The settings, or null when there is no watermark (none chosen, no text, no picture yet). */
  function settings(): WatermarkSettings | null {
    if (type.value === "text" && text.value.trim() !== "") {
      return { type: "text", text: text.value.trim(), layout: layout.value, angle: Number(angle.value) || 0, count: clampCount() }
    }
    if (type.value === "image" && image) {
      return { type: "image", layout: layout.value, angle: Number(angle.value) || 0, count: clampCount() }
    }
    return null
  }

  function clampCount() {
    return Math.min(50, Math.max(1, Math.round(Number(count.value) || 1)))
  }

  type.addEventListener("change", () => {
    show()
    onChange()
  })
  for (const input of [text, count]) input.addEventListener("input", onChange)
  angle.addEventListener("input", () => {
    angleTyped = true
    onChange()
  })
  layout.addEventListener("change", () => {
    if (!angleTyped) angle.value = String(DEFAULT_ANGLE[layout.value] ?? 0)
    onChange()
  })
  file.addEventListener("change", async () => {
    message.textContent = ""
    image = null
    const chosen = file.files?.[0]
    if (chosen) {
      const kind = chosen.type
      if ((kind !== "image/png" && kind !== "image/jpeg") || chosen.size > MAX_IMAGE_BYTES) {
        message.textContent = t("watermark_image_error")
        file.value = ""
      } else {
        const bytes = new Uint8Array(await chosen.arrayBuffer())
        const dataUrl = await new Promise<string>((resolve) => {
          const reader = new FileReader()
          reader.onload = () => resolve(String(reader.result))
          reader.readAsDataURL(chosen)
        })
        image = { name: kind === "image/png" ? "watermark.png" : "watermark.jpg", bytes, dataUrl }
      }
    }
    onChange()
  })

  // "Edit and regenerate": the settings the document was made with (a picture has to be chosen again).
  try {
    const saved = JSON.parse(root.dataset.watermark || "{}")
    if (saved.type === "text" || saved.type === "image") {
      type.value = saved.type
      text.value = saved.text ?? ""
      if (saved.layout) layout.value = saved.layout
      if (typeof saved.angle === "number") {
        angle.value = String(saved.angle)
        angleTyped = true
      }
      if (saved.count) count.value = String(saved.count)
    }
  } catch {
    // no settings: the defaults stay
  }
  show()

  return {
    /** What the preview draws: the settings and the picture, or null for no watermark. */
    preview(): WatermarkPreview | null {
      const current = settings()
      if (!current) return null
      if (current.type === "image" && image) return { settings: { ...current, image: image.name }, image: { name: image.name, bytes: image.bytes } }
      return { settings: current }
    },
    /** What the download sends: the settings, with the picture as a data URL. */
    download(): (WatermarkSettings & { image_data?: string }) | undefined {
      const current = settings()
      if (!current) return undefined
      return current.type === "image" && image ? { ...current, image_data: image.dataUrl } : current
    },
    /** Whether the options are open (they are, when a watermark is chosen), for the page to open the advanced settings. */
    chosen: () => type.value !== "",
  }
}
