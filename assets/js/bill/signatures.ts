import type { Design } from "./form"
import { t } from "./i18n"
import { saveSignature, type Signature } from "./saved"

export type SignaturePicker = {
  /** The id of the chosen saved signature, or `null` for none: the place to sign by hand. */
  readonly id: number | null
  use(id: number | null): void
  /** The choice is shown while the chosen design of the bill has a place for a signature. */
  showFor(design: Design | undefined): void
}

// A visitor has no signatures: nothing to choose and nothing to draw.
const NO_PICKER: SignaturePicker = { id: null, use() {}, showFor() {} }

/**
 * The signature of the bill: a select of the user's saved signatures (the server draws the select in
 * `#signature-section`), with "No signature (placeholder only)" first, and a small form that saves a new one from a
 * picture and a name. `drawn` is told the address of the chosen picture, or `null`, for the preview.
 */
export function createSignaturePicker(root: HTMLElement, drawn: (url: string | null) => void): SignaturePicker {
  const section = root.querySelector<HTMLElement>("#signature-section")
  const select = root.querySelector<HTMLSelectElement>("#signature-select")
  if (!section || !select) return NO_PICKER

  const signatures: Signature[] = JSON.parse(root.dataset.signatures ?? "[]")
  let chosen: number | null = null

  function use(id: number | null) {
    const signature = signatures.find((s) => s.id === id) ?? null
    chosen = signature ? signature.id : null
    select!.value = signature ? String(signature.id) : ""
    drawn(signature?.url ?? null)
  }
  select.addEventListener("change", () => use(select.value ? Number(select.value) : null))

  const name = root.querySelector<HTMLInputElement>("#signature-name")!
  const file = root.querySelector<HTMLInputElement>("#signature-file")!
  const button = root.querySelector<HTMLButtonElement>("#signature-save")!
  const message = root.querySelector<HTMLElement>("#signature-message")!
  const say = (text: string, error: boolean) => {
    message.textContent = text
    message.className = "text-sm/6 " + (error ? "text-danger" : "text-ink-muted")
  }

  button.addEventListener("click", async () => {
    const picture = file.files?.[0]
    if (!name.value.trim()) return say(t("signature_error_name_blank"), true)
    if (!picture) return say(t("signature_error_no_file"), true)

    button.disabled = true
    const result = await saveSignature(name.value.trim(), picture)
    button.disabled = false

    if (!result.ok) {
      // The server says why with a code; a code with no sentence of its own (or none: offline) is a plain failure.
      const key = `signature_error_${result.code}`
      return say(t(key) === key ? t("error") : t(key), true)
    }

    signatures.push(result.signature)
    signatures.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))
    select.replaceChildren(select.options[0], ...signatures.map((s) => new Option(s.name, String(s.id))))
    use(result.signature.id) // the signature that was just saved is the one the visitor wants
    name.value = ""
    file.value = ""
    say(t("signature_saved"), false)
  })

  return {
    get id() {
      return chosen
    },
    use,
    showFor(design) {
      section.classList.toggle("hidden", !design?.signature)
    },
  }
}
