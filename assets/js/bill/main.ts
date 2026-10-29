import { buildForm, type BillData, type Schema } from "./form"
import { createPreview } from "./preview"
import { downloadPdf } from "./download"

function init() {
  const root = document.getElementById("bill-app")
  if (!root) return // not on a template page

  const button = root.querySelector<HTMLButtonElement>("#download-button")!
  const status = root.querySelector<HTMLElement>("#bill-status")!
  const schema: Schema = JSON.parse(root.dataset.schema!)
  const sample: BillData = JSON.parse(root.dataset.sample!)
  const form = root.querySelector<HTMLFormElement>("#bill-form")!
  const preview = createPreview({
    workerUrl: root.dataset.worker!,
    slug: schema.slug,
    template: root.dataset.template!,
    container: root.querySelector<HTMLElement>("#bill-preview")!,
    status: root.querySelector<HTMLElement>("#bill-status")!,
  })
  preview.renderNow(sample)
  const ui = buildForm(form, schema, sample, (data) => preview.schedule(data))
  // const ui = buildForm(form, schema, sample, (data) => console.log("changed", data))
  // console.log("initial", ui.read())

  button.addEventListener("click", async () => {
    button.disabled = true
    status.textContent = "Creating your PDF…"
    ui.showErrors({})
    const result = await downloadPdf(schema.slug, root.dataset.template!, ui.read())
    button.disabled = false

    if (result.ok) status.textContent = "Downloaded."
    else if (result.status === 422) {
      ui.showErrors(result.errors ?? {})
      status.textContent = "Please fix the highlighted fields."
    } else if (result.status === 429) status.textContent = "You've used today's free downloads. Please log in."
    else status.textContent = result.message ?? "Something went wrong. Please try again."
  })
  
}

document.addEventListener("DOMContentLoaded", init)
