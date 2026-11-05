export type Field = {
  key: string
  label: string
  type: "text" | "textarea" | "number" | "date" | "month" | "select"
  required?: boolean
  max_length?: number
  min?: number
  options?: string[]
  prefill?: string
}
export type Schema = { slug: string; title: string; fields: Field[] }
export type BillData = Record<string, string | number>
export type Business = { id: number; name: string; address: string | null; gstin: string | null }

type Control = HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement

const INPUT_CLASS =
  "block w-full rounded-field border border-line-strong bg-surface px-3 py-2.5 text-base text-ink placeholder:text-ink-faint focus:border-focus focus:outline-2 focus:-outline-offset-1 focus:outline-focus sm:text-sm/6"

/** A "Fill from a saved business" picker above the first field. Choosing a business fills every field whose `prefill` is `business.<attribute>`. */
function addBusinessPicker(
  form: HTMLFormElement,
  schema: Schema,
  businesses: Business[],
  controls: Map<string, Control>,
  notify: () => void,
) {
  if (businesses.length === 0) return // visitors, and users who have not saved a business yet

  const select = document.createElement("select")
  select.id = "business-select"
  select.className = INPUT_CLASS
  select.append(new Option("Choose a saved business…", ""))
  for (const business of businesses) select.append(new Option(business.name, String(business.id)))

  const label = document.createElement("label")
  label.htmlFor = select.id
  label.className = "mb-1 block text-sm/6 font-medium text-ink"
  label.textContent = "Fill from a saved business"

  select.addEventListener("change", () => {
    const business = businesses.find((b) => String(b.id) === select.value)
    if (!business) return // the "Choose…" line

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
  } else if (field.type === "select") {
    control = document.createElement("select")
    for (const option of field.options ?? []) {
      const el = document.createElement("option")
      el.value = option
      el.textContent = option
      control.append(el)
    }
  } else {
    control = document.createElement("input")
    control.type = field.type === "text" ? "text" : field.type // number | date | month
    if (field.type === "number") control.step = "any"
  }
  control.id = id
  control.name = field.key
  control.className = INPUT_CLASS
  if (field.max_length && !(control instanceof HTMLSelectElement)) control.maxLength = field.max_length
  if (field.min !== undefined && control instanceof HTMLInputElement) control.min = String(field.min)
  return control
}

/** Builds the form inside `form` and calls `onChange` with the current data after every edit. */
export function buildForm(
  form: HTMLFormElement,
  schema: Schema,
  initial: BillData,
  onChange: (data: BillData) => void,
  businesses: Business[] = [],
) {
  const controls = new Map<string, Control>()
  const errorEls = new Map<string, HTMLElement>()

  for (const field of schema.fields) {
    const id = `field-${field.key}`
    const wrapper = document.createElement("div")

    const label = document.createElement("label")
    label.htmlFor = id
    label.className = "mb-1 block text-sm/6 font-medium text-ink"
    label.textContent = field.label + (field.required ? " *" : "")

    const control = createControl(field, id)
    const initialValue = initial[field.key]
    if (initialValue !== undefined) control.value = String(initialValue)

    const error = document.createElement("p")
    error.id = `error-${field.key}`
    error.className = "mt-1.5 text-sm text-danger"
    control.setAttribute("aria-describedby", error.id)

    wrapper.append(label, control, error)
    form.append(wrapper)
    controls.set(field.key, control)
    errorEls.set(field.key, error)
  }

  const read = (): BillData => {
    const data: BillData = {}
    for (const field of schema.fields) {
      const raw = controls.get(field.key)!.value.trim()
      if (raw === "") continue // optional and empty: omit
      data[field.key] = field.type === "number" ? Number(raw) : raw
    }
    return data
  }

  form.addEventListener("input", () => onChange(read()))

  addBusinessPicker(form, schema, businesses, controls, () => onChange(read()))

  return {
    read,
    /** Show server-side errors: `{ field_key: ["message"] }`. Pass {} to clear. */
    showErrors(errors: Record<string, string[]>) {
      for (const [key, el] of errorEls) el.textContent = (errors[key] ?? []).join(", ")
    },
  }
}
