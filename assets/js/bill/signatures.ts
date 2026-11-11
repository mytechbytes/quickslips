import type { Design } from "./form"
import { t } from "./i18n"
import { saveSignature, type Signature } from "./saved"

/** Told when a signature is saved on the page, so the other select of signatures lists it too. */
export const SIGNATURE_SAVED = "signature-saved"

export type SignaturePicker = {
  /** The id of the chosen saved signature, or `null` for none: the place to sign by hand. */
  readonly id: number | null
  use(id: number | null): void
  /** The choice is shown while the chosen design of the bill has a place for a signature. */
  showFor(design: Design | undefined): void
}

/**
 * The driver's signature, the second one of a receipt: a select of the same saved signatures (the server draws it in
 * `#driver-signature-section`), shown while the chosen design has a place for it. `drawn` is told the address of the
 * chosen picture, or `null`, for the preview.
 */
export function createDriverSignaturePicker(root: HTMLElement, drawn: (url: string | null) => void): SignaturePicker {
  const section = root.querySelector<HTMLElement>("#driver-signature-section")
  const select = root.querySelector<HTMLSelectElement>("#driver-signature-select")
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
  // A signature saved in the first picker is listed here too, in the same order, keeping the choice.
  root.addEventListener(SIGNATURE_SAVED, (event) => {
    const { signature, forDriver } = (event as CustomEvent<{ signature: Signature; forDriver: boolean }>).detail
    signatures.push(signature)
    signatures.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))
    select.replaceChildren(select.options[0], ...signatures.map((s) => new Option(s.name, String(s.id))))
    select.value = chosen ? String(chosen) : ""
    if (forDriver) use(signature.id)
  })

  return {
    get id() {
      return chosen
    },
    use,
    showFor(design) {
      section.classList.toggle("hidden", !design?.driver_signature)
    },
  }
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

  // Both selects have a + button that opens the one dialog; the signature saved there is chosen in the select whose
  // button opened it.
  root.querySelector("#signature-open")?.addEventListener("click", () => (root.dataset.signatureTarget = "main"))
  root.querySelector("#driver-signature-open")?.addEventListener("click", () => (root.dataset.signatureTarget = "driver"))

  const name = root.querySelector<HTMLInputElement>("#signature-name")!
  const file = root.querySelector<HTMLInputElement>("#signature-file")!
  const rights = root.querySelector<HTMLInputElement>("#signature-rights")!
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
    if (!rights.checked) return say(t("rights_required"), true)

    button.disabled = true
    const result = await saveSignature(name.value.trim(), picture, rights.checked)
    button.disabled = false

    if (!result.ok) {
      // The server says why with a code; a code with no sentence of its own (or none: offline) is a plain failure.
      const key = `signature_error_${result.code}`
      return say(t(key) === key ? t("error") : t(key), true)
    }

    signatures.push(result.signature)
    signatures.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))
    select.replaceChildren(select.options[0], ...signatures.map((s) => new Option(s.name, String(s.id))))
    const forDriver = root.dataset.signatureTarget === "driver"
    root.dispatchEvent(new CustomEvent(SIGNATURE_SAVED, { detail: { signature: result.signature, forDriver } }))
    if (!forDriver) use(result.signature.id) // the signature that was just saved is the one the visitor wants
    name.value = ""
    file.value = ""
    rights.checked = false
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
