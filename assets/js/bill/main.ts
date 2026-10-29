import { buildForm, type BillData, type Schema } from "./form"

function init() {
  const root = document.getElementById("bill-app")
  if (!root) return // not on a template page

  const schema: Schema = JSON.parse(root.dataset.schema!)
  const sample: BillData = JSON.parse(root.dataset.sample!)
  const form = root.querySelector<HTMLFormElement>("#bill-form")!

  const ui = buildForm(form, schema, sample, (data) => console.log("changed", data))
  console.log("initial", ui.read())
}

document.addEventListener("DOMContentLoaded", init)
