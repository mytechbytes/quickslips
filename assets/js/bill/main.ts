import { buildForm, type BillData, type Schema } from "./form"
import { createPreview } from "./preview"

function init() {
  const root = document.getElementById("bill-app")
  if (!root) return // not on a template page

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
  buildForm(form, schema, sample, (data) => preview.schedule(data))
  // const ui = buildForm(form, schema, sample, (data) => console.log("changed", data))
  // console.log("initial", ui.read())
  
}

document.addEventListener("DOMContentLoaded", init)
