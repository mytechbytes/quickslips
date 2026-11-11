import type { Design } from "./form"
import { t } from "./i18n"
import { saveStamp, type Stamp } from "./saved"

export type StampPicker = {
  /**
   * What is chosen: `""` for the empty box, `"system:<name>"` for a stamp the site provides, or the id of a saved
   * stamp (as text). It is what the download sends and what a document remembers.
   */
  readonly choice: string
  use(choice: string): void
  /** The choice is shown while the chosen design has a place for a revenue stamp and the document is for India. */
  showFor(design: Design | undefined, country: string): void
}

/**
 * The revenue stamp of the bill: a select with the empty box, the default stamp and the user's saved stamps (the server
 * draws it in `#stamp-section`), and, for a logged-in user, a small form that saves a new one from a picture and a name.
 * `drawn` is told what to draw in the preview: the address of the chosen stamp's picture, or `null` for the empty box.
 */
export function createStampPicker(root: HTMLElement, drawn: (url: string | null) => void): StampPicker {
  const section = root.querySelector<HTMLElement>("#stamp-section")
  const select = root.querySelector<HTMLSelectElement>("#stamp-select")
  if (!section || !select) return { choice: "", use() {}, showFor() {} }

  const stamps: Stamp[] = JSON.parse(root.dataset.stamps ?? "[]")
  let chosen = ""

  function use(choice: string) {
    const stamp = stamps.find((s) => String(s.id) === choice)
    chosen = stamp ? choice : ""
    select!.value = chosen
    drawn(stamp?.url ?? null)
  }
  select.addEventListener("change", () => use(select.value))

  const name = root.querySelector<HTMLInputElement>("#stamp-name")
  const file = root.querySelector<HTMLInputElement>("#stamp-file")
  const rights = root.querySelector<HTMLInputElement>("#stamp-rights")
  const button = root.querySelector<HTMLButtonElement>("#stamp-save")
  const message = root.querySelector<HTMLElement>("#stamp-message")
  if (name && file && rights && button && message) {
    const say = (text: string, error: boolean) => {
      message.textContent = text
      message.className = "text-sm/6 " + (error ? "text-danger" : "text-ink-muted")
    }

    button.addEventListener("click", async () => {
      const picture = file.files?.[0]
      if (!name.value.trim()) return say(t("stamp_error_name_blank"), true)
      if (!picture) return say(t("signature_error_no_file"), true)
      if (!rights.checked) return say(t("rights_required"), true)

      button.disabled = true
      const result = await saveStamp(name.value.trim(), picture, rights.checked)
      button.disabled = false

      if (!result.ok) {
        // The server says why with a code. The stamp has sentences of its own for the name and the limit; the
        // picture is refused for the same reasons as a signature.
        const own = `stamp_error_${result.code}`
        const shared = `signature_error_${result.code}`
        const text = t(own) !== own ? t(own) : t(shared) !== shared ? t(shared) : t("error")
        return say(text, true)
      }

      stamps.push(result.stamp)
      stamps.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))
      const fixed = Array.from(select.options).filter((o) => o.value === "" || o.value.startsWith("system:"))
      select.replaceChildren(...fixed, ...stamps.filter((s) => !String(s.id).startsWith("system:")).map((s) => new Option(s.name, String(s.id))))
      use(String(result.stamp.id)) // the stamp that was just saved is the one the visitor wants
      name.value = ""
      file.value = ""
      rights.checked = false
      say(t("stamp_saved"), false)
    })
  }

  return {
    get choice() {
      return chosen
    },
    use,
    showFor(design, country) {
      section.classList.toggle("hidden", !(design?.stamp && country === "in"))
    },
  }
}
