import { t } from "./i18n"
import { createItemsField, type ItemRow } from "./items"
import { INPUT_CLASS } from "./styles"

export type Field = {
  key: string
  label: string
  type: "text" | "textarea" | "number" | "date" | "time" | "month" | "select" | "items" | "tax_rate" | "tax_id"
  required?: boolean
  max_length?: number
  min?: number
  options?: string[]
  // What each option is called in the language of the page: the data holds the option, the form shows this.
  option_labels?: Record<string, string>
  prefill?: string
  // The section of the form the field belongs to (one of GROUPS).
  group?: string
  // A table of items: the heads of its columns, how many rows it may have, how long a name may be.
  columns?: { name?: string; qty?: string; rate?: string; code?: string; billing?: string; discount?: string; tax?: string }
  // The cells of a row of the table, in order (`["code", "billing", "name", "qty", "rate", "discount"]`), and the
  // billing types its rows may have (the `billing` cell is a choice among them).
  cells?: string[]
  billing_options?: string[]
  code_max_length?: number
  // A tax rate field: the percentages the country offers.
  rates?: number[]
  max_rows?: number
  name_max_length?: number
}
export type Schema = { slug: string; title: string; fields: Field[] }
export type BillData = Record<string, string | number | ItemRow[]>
export type Business = {
  id: number
  name: string
  address: string | null
  gstin: string | null
  logo_url: string | null
  signature_url: string | null
}

// The sections of the form, in the order they appear; a field says which one it is in. The titles are ui strings
// (`group_business`, ...), so every language has them.
const GROUPS = ["business", "registration", "document", "customer", "items", "details", "charges", "payment"]

type Control = HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement

/**
 * A "Fill from a saved business" picker above the first field. Choosing a business fills every field whose
 * `prefill` is `business.<attribute>`, and tells `picked` which business it is (`null` for the "Choose…" line),
 * because its logo and signature belong on the document too.
 */
function addBusinessPicker(
  form: HTMLFormElement,
  schema: Schema,
  businesses: Business[],
  controls: Map<string, Control>,
  notify: () => void,
  picked: (business: Business | null) => void,
) {
  if (businesses.length === 0) return // visitors, and users who have not saved a business yet

  const select = document.createElement("select")
  select.id = "business-select"
  select.className = INPUT_CLASS
  select.append(new Option(t("pick_business"), ""))
  for (const business of businesses) select.append(new Option(business.name, String(business.id)))

  const label = document.createElement("label")
  label.htmlFor = select.id
  label.className = "mb-1 block text-sm/6 font-medium text-ink"
  label.textContent = t("fill_business")

  select.addEventListener("change", () => {
    const business = businesses.find((b) => String(b.id) === select.value) ?? null
    picked(business)
    if (!business) return // the "Choose…" line: nothing to fill

    for (const field of schema.fields) {
      if (!field.prefill?.startsWith("business.")) continue
      const value = business[field.prefill.slice("business.".length) as keyof Business]
      const text = typeof value === "string" ? value : ""
      controls.get(field.key)!.value = field.max_length ? text.slice(0, field.max_length) : text
    }
    notify() // update the preview
  })

  const wrapper = document.createElement("div")
  wrapper.append(label, select)
  form.prepend(wrapper)
}

function createControl(field: Field, id: string): Control {
  let control: Control
  if (field.type === "textarea") {
    control = document.createElement("textarea")
    control.rows = 3
  } else if (field.type === "tax_rate" && (field.rates ?? []).length === 0) {
    // A country with no standard rate to offer (the United States, Brazil): the rate is typed.
    control = document.createElement("input")
    control.type = "number"
    control.step = "any"
    control.min = "0"
    control.max = "100"
  } else if (field.type === "tax_rate") {
    // The rates of the country; "none" for a document without tax when the field is optional.
    control = document.createElement("select")
    if (!field.required) control.append(new Option("—", ""))
    for (const rate of field.rates ?? []) control.append(new Option(`${rate}%`, String(rate)))
  } else if (field.type === "select") {
    control = document.createElement("select")
    for (const option of field.options ?? []) {
      const el = document.createElement("option")
      el.value = option
      el.textContent = field.option_labels?.[option] ?? option
      control.append(el)
    }
  } else {
    control = document.createElement("input")
    control.type = field.type === "text" || field.type === "tax_id" ? "text" : field.type // number | date | time | month
    if (field.type === "tax_id") control.autocomplete = "off"
    if (field.type === "number") control.step = "any"
  }
  control.id = id
  control.name = field.key
  control.className = INPUT_CLASS
  if (field.max_length && !(control instanceof HTMLSelectElement)) control.maxLength = field.max_length
  if (field.min !== undefined && control instanceof HTMLInputElement) control.min = String(field.min)
  return control
}

/**
 * Builds the form inside `form` and calls `onChange` with the current data after every edit. `currency` is the
 * sign of the document's currency, `tax` what the country calls its tax ("GST", "IVA") and `tax_id` its registration
 * number ("GSTIN", "NIF"): they take the place of `{currency}`, `{tax}` and `{tax_id}` in a label ("{tax} (%)"),
 * and `formatMoney` writes an amount the way the country does (the amounts of a table of items).
 */
export function buildForm(
  form: HTMLFormElement,
  schema: Schema,
  initial: BillData,
  onChange: (data: BillData) => void,
  businesses: Business[] = [],
  onBusiness: (business: Business | null) => void = () => {},
  vars: { currency?: string; tax?: string; tax_id?: string } = {},
  formatMoney: (amount: number) => string = String,
) {
  const controls = new Map<string, Control>()
  const errorEls = new Map<string, HTMLElement>()
  const tables = new Map<string, ReturnType<typeof createItemsField>>()
  const sections = new Map<string, HTMLElement>()

  // The grid of a section, with its heading (a bar, the title, a hairline), made when its first field comes.
  const sectionOf = (field: Field): HTMLElement => {
    const id = field.group && GROUPS.includes(field.group) ? field.group : "details"
    let grid = sections.get(id)
    if (!grid) {
      const section = document.createElement("section")
      section.dataset.group = id
      section.innerHTML =
        `<div class="mb-3 flex items-center gap-3"><h3 class="border-l-2 border-accent pl-2 text-xs font-semibold uppercase tracking-wider text-ink"></h3><span class="h-px flex-1 bg-line"></span></div>` +
        `<div class="grid gap-x-3 gap-y-2.5 sm:grid-cols-2"></div>`
      section.querySelector("h3")!.textContent = t(`group_${id}`)
      grid = section.querySelector<HTMLElement>("div:last-child")!
      sections.set(id, grid)
    }
    return grid
  }

  for (const field of schema.fields) {
    if (field.type === "items") {
      const table = createItemsField(
        field,
        initial[field.key] as ItemRow[] | undefined,
        { currency: vars.currency ?? "", formatMoney },
        () => onChange(read()),
      )
      table.element.classList.add("sm:col-span-2")
      sectionOf(field).append(table.element)
      tables.set(field.key, table)
      continue
    }

    const id = `field-${field.key}`
    const wrapper = document.createElement("div")
    wrapper.dataset.fieldType = field.type
    // A text area and a long line (an address, a route) take the whole row; the rest share it two by two.
    if (field.type === "textarea" || (field.max_length ?? 0) >= 120) wrapper.className = "sm:col-span-2"

    const label = document.createElement("label")
    label.htmlFor = id
    label.className = "mb-1 block text-sm/5 font-medium text-ink"
    label.textContent =
      field.label
        .replace("{currency}", vars.currency ?? "")
        .replace("{tax}", vars.tax ?? "")
        .replace("{tax_id}", vars.tax_id ?? "") + (field.required ? " *" : "")

    const control = createControl(field, id)
    const initialValue = initial[field.key]
    if (initialValue !== undefined) {
      // A saved document may carry a rate the country no longer offers (12%): it stays choosable.
      if (control instanceof HTMLSelectElement && field.type === "tax_rate" && ![...control.options].some((o) => o.value === String(initialValue)))
        control.append(new Option(`${initialValue}%`, String(initialValue)))
      control.value = String(initialValue)
    }

    const error = document.createElement("p")
    error.id = `error-${field.key}`
    error.className = "mt-1.5 text-sm text-danger"
    control.setAttribute("aria-describedby", error.id)

    wrapper.append(label, control, error)
    sectionOf(field).append(wrapper)
    controls.set(field.key, control)
    errorEls.set(field.key, error)
  }

  for (const id of GROUPS) {
    const grid = sections.get(id)
    if (grid) form.append(grid.parentElement!)
  }

  const read = (): BillData => {
    const data: BillData = {}
    for (const field of schema.fields) {
      const table = tables.get(field.key)
      if (table) {
        const rows = table.read()
        if (rows.length > 0) data[field.key] = rows
        continue
      }
      const raw = controls.get(field.key)!.value.trim()
      if (raw === "") continue // optional and empty: omit
      data[field.key] = field.type === "number" || field.type === "tax_rate" ? Number(raw) : raw
    }
    return data
  }

  const onInput = () => onChange(read())
  form.addEventListener("input", onInput)

  addBusinessPicker(form, schema, businesses, controls, () => onChange(read()), onBusiness)

  return {
    read,
    /** Takes the form's listener away, before the form is built again. */
    destroy() {
      form.removeEventListener("input", onInput)
    },
    /** Show server-side errors: `{ field_key: ["message"] }`. Pass {} to clear. */
    showErrors(errors: Record<string, string[]>) {
      for (const [key, el] of errorEls) el.textContent = (errors[key] ?? []).join(", ")
      for (const table of tables.values()) table.showErrors(errors)
    },
  }
}
