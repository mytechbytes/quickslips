import { makeSearchable } from "./combo"
import { t } from "./i18n"
import { createItemsField, type ItemRow } from "./items"
import { createPeriodsField, type PeriodsValue } from "./periods"
import { INPUT_CLASS, SECONDARY_BUTTON_CLASS } from "./styles"

export type Field = {
  key: string
  label: string
  type: "text" | "textarea" | "number" | "date" | "time" | "month" | "select" | "items" | "periods" | "tax_rate" | "tax_id"
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
  columns?: { name?: string; qty?: string; rate?: string; code?: string; billing?: string; discount?: string; tax?: string; hsn?: string; mfr?: string; batch?: string; expiry?: string; schedule?: string }
  // The cells of a row of the table, in order (`["code", "billing", "name", "qty", "rate", "discount"]`), and the
  // billing types its rows may have (the `billing` cell is a choice among them).
  cells?: string[]
  billing_options?: string[]
  code_max_length?: number
  cell_max_length?: number
  // A tax rate field: the percentages the country offers.
  rates?: number[]
  max_rows?: number
  // A periods field with a column for the number of each receipt, and the head of that column.
  numbers?: boolean
  number_label?: string
  name_max_length?: number
}
// A design of the bill; `signature` says whether its layout has a place for a signature.
export type Design = { id: string; name?: string; signature?: boolean; driver_signature?: boolean; extra_signatures?: string[]; stamp?: boolean; thermal?: boolean }
// `groups` names the sections of the form where this bill has its own words ("Employee" for the business of a salary receipt).
export type Schema = {
  slug: string
  title: string
  fields: Field[]
  templates?: Design[]
  groups?: Record<string, string>
  // The sections whose details a logged-in user may save and pick again (the employee, the driver).
  saved_groups?: string[]
}
export type BillData = Record<string, string | number | ItemRow[] | PeriodsValue>
export type Business = {
  id: number
  name: string
  address: string | null
  gstin: string | null
  logo_url: string | null
  // The signature that is chosen for a bill when this business is (the id of a saved signature).
  signature_id: number | null
}

/** The details of one section that a user saved: what the picker shows, and the value of each field of the section. */
export type SavedEntry = { id: number; name: string; data: Record<string, string> }

/**
 * The saved details of the sections of a bill (`entries`, by section) and how to save the ones typed (`null` for a
 * visitor, who cannot).
 */
export type SavedSections = {
  entries: Record<string, SavedEntry[]>
  save: ((group: string, data: Record<string, string>, id?: number) => Promise<{ entry: SavedEntry; message: string } | { error: string }>) | null
}

/**
 * Saves the seller details of the form (the server updates the business of that name, or makes one). Tells the form
 * the saved business and the sentence to show, or the sentence to show when it did not work.
 */
export type SaveSeller = (
  details: { name: string; address: string; gstin: string },
  id?: number,
) => Promise<{ business: Business; message: string } | { error: string }>

// The sections of the form, in the order they appear; a field says which one it is in. The titles are ui strings
// (`group_business`, ...), so every language has them.
// "additional" comes last: the details that do not belong to one of the others (a declaration, a note).
const GROUPS = ["business", "registration", "document", "customer", "items", "details", "charges", "payment", "additional"]

type Control = HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement

/** What a picker of saved details works on: the entries to choose from and how to keep what is typed. */
type SectionPicker = {
  /** The id of the select: `saved-<group>`. */
  group: string
  /** The fields that choosing an entry fills and that Update / Create new keep. */
  fields: Field[]
  entries: SavedEntry[]
  /** The line of the select that chooses nothing. */
  placeholder: string
  /** Where the select goes (above the fields), and where the buttons go (under them). */
  top: HTMLElement
  bottom: HTMLElement
  /** `null` for a visitor, who cannot save. */
  save: ((data: Record<string, string>, id?: number) => Promise<{ entry: SavedEntry; message: string } | { error: string }>) | null
  /** Told which entry was chosen (`null`: the "Choose…" line), for what the entry carries besides its fields (a business's logo). */
  picked?: (id: number | null) => void
}

/**
 * At the top of a section whose details may be saved (the employee, the driver, the seller): a searchable list of the
 * saved ones and, under the fields, "Update" (changes the one chosen) and "Create new" (always makes another). Choosing
 * one fills every field of the section.
 */
function addSavedSection(picker: SectionPicker, controls: Map<string, Control>, notify: () => void) {
  const { entries, fields } = picker
  if (entries.length === 0 && !picker.save) return null // a visitor with nothing to pick

  const row = document.createElement("div")
  row.className = "sm:col-span-2"
  row.dataset.savedSection = picker.group

  const select = document.createElement("select")
  select.id = `saved-${picker.group}`
  select.className = INPUT_CLASS
  select.setAttribute("aria-label", picker.placeholder)
  const show = (selected?: number) => {
    select.replaceChildren(new Option(picker.placeholder, ""))
    for (const entry of entries) select.append(new Option(entry.name, String(entry.id)))
    if (selected !== undefined) select.value = String(selected)
    select.hidden = entries.length === 0
  }
  show()

  select.addEventListener("change", () => {
    const entry = entries.find((e) => String(e.id) === select.value)
    picker.picked?.(entry ? entry.id : null)
    if (entry) fill(entry)
  })

  function fill(entry: SavedEntry) {
    for (const field of fields) {
      const control = controls.get(field.key)
      if (!control) continue
      const text = entry.data[field.key] ?? ""
      control.value = field.max_length ? text.slice(0, field.max_length) : text
    }
    notify()
  }

  row.append(select)
  picker.top.prepend(row)
  makeSearchable(select)
  // "Update" can only change an entry that is chosen.
  let refresh = () => {}

  if (picker.save) {
    const message = document.createElement("p")
    message.setAttribute("role", "status")
    message.className = "text-sm/6"

    const makeButton = (suffix: string, text: string) => {
      const b = document.createElement("button")
      b.type = "button"
      b.id = `save-${picker.group}-${suffix}`
      b.className = SECONDARY_BUTTON_CLASS + " disabled:cursor-not-allowed disabled:opacity-50"
      b.textContent = text
      return b
    }
    const update = makeButton("update", t("saved_update"))
    const create = makeButton("create", t("saved_create"))
    const sync = () => {
      update.disabled = select.value === ""
    }
    sync()
    select.addEventListener("change", sync)
    refresh = sync

    const keep = async (id?: number) => {
      const data: Record<string, string> = {}
      for (const field of fields) data[field.key] = controls.get(field.key)?.value.trim() ?? ""

      update.disabled = true
      create.disabled = true
      const result = await picker.save!(data, id)
      create.disabled = false
      sync()

      message.className = "text-sm/6 " + ("error" in result ? "text-danger" : "text-ink-muted")
      message.textContent = "error" in result ? result.error : result.message
      if ("error" in result) return

      const at = entries.findIndex((e) => e.id === result.entry.id)
      if (at >= 0) entries[at] = result.entry
      else entries.push(result.entry)
      entries.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))
      show(result.entry.id)
      picker.picked?.(result.entry.id)
      sync()
    }
    update.addEventListener("click", () => keep(Number(select.value)))
    create.addEventListener("click", () => keep())
    const foot = document.createElement("div")
    foot.className = "flex flex-wrap items-center gap-3 sm:col-span-2"
    foot.dataset.savedSectionSave = picker.group
    foot.append(update, create, message)
    picker.bottom.append(foot)
  }

  return {
    /** Chooses the entry (as if the visitor had), without filling the fields. */
    choose(id: number | null) {
      select.value = id === null ? "" : String(id)
      refresh()
    },
  }
}

// The value of the "Other rate…" line of a list of tax rates: the typed rate is read from the box beside it.
const OTHER_RATE = "other"

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
    // A rate the country does not list (a local rate, a new one) is typed in a box that opens beside the list.
    control.append(new Option(t("other_rate"), OTHER_RATE))
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
  saveSeller: SaveSeller | null = null,
  savedSections: SavedSections = { entries: {}, save: null },
) {
  const controls = new Map<string, Control>()
  const typedRates = new Map<string, HTMLInputElement>() // the box of "Other rate…", by field key
  const errorEls = new Map<string, HTMLElement>()
  const tables = new Map<string, ReturnType<typeof createItemsField>>()
  const periods = new Map<string, ReturnType<typeof createPeriodsField>>()
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
      section.querySelector("h3")!.textContent = schema.groups?.[id] || t(`group_${id}`)
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

    if (field.type === "periods") {
      const picker = createPeriodsField(field, initial[field.key] as PeriodsValue | undefined, () => onChange(read()))
      sectionOf(field).append(picker.element)
      periods.set(field.key, picker)
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

    wrapper.append(label, control)
    if (field.type === "tax_rate" && control instanceof HTMLSelectElement) {
      const typed = document.createElement("input")
      typed.type = "number"
      typed.step = "any"
      typed.min = "0"
      typed.max = "100"
      typed.id = `${id}-typed`
      typed.className = `${INPUT_CLASS} mt-2 hidden`
      typed.placeholder = t("type_rate")
      typed.setAttribute("aria-label", t("type_rate"))
      const show = () => typed.classList.toggle("hidden", control.value !== OTHER_RATE)
      control.addEventListener("change", () => {
        show()
        if (control.value === OTHER_RATE) typed.focus()
      })
      typedRates.set(field.key, typed)
      wrapper.append(typed)
    }
    wrapper.append(error)
    sectionOf(field).append(wrapper)
    controls.set(field.key, control)
    errorEls.set(field.key, error)
  }

  for (const group of schema.saved_groups ?? []) {
    const grid = sections.get(group)
    const fields = schema.fields.filter((f) => f.group === group && controls.has(f.key))
    if (!grid || fields.length === 0) continue
    // The seller of a bill whose "business" section is saved as a section (a salary receipt's employee).
    addSavedSection(
      {
        group,
        fields,
        entries: savedSections.entries[group] ?? (savedSections.entries[group] = []),
        placeholder: t("pick_saved"),
        top: grid,
        bottom: grid,
        save: savedSections.save ? (data, id) => savedSections.save!(group, data, id) : null,
      },
      controls,
      () => onChange(read()),
    )
  }

  // The seller of the bill: a saved business, chosen like any saved section, with Update and Create new under the fields.
  // It carries a logo and a signature, so choosing one tells the page which it is.
  let businessPicker: ReturnType<typeof addSavedSection> = null
  const sellerFields = schema.fields.filter((f) => f.prefill?.startsWith("business.") && controls.has(f.key))
  if (!schema.saved_groups?.includes("business") && (businesses.length > 0 || (saveSeller && sellerFields.some((f) => f.prefill === "business.name")))) {
    const attribute = (field: Field) => field.prefill!.slice("business.".length)
    const asEntry = (b: Business): SavedEntry => ({
      id: b.id,
      name: b.name,
      data: Object.fromEntries(sellerFields.map((f) => [f.key, String(b[attribute(f) as keyof Business] ?? "")])),
    })
    const entries = businesses.map(asEntry)
    const last = [...sellerFields].reverse().find((f) => sections.has(f.group ?? "details"))
    businessPicker = addSavedSection(
      {
        group: "business",
        fields: sellerFields,
        entries,
        placeholder: t("fill_business"),
        top: sections.get("business") ?? sections.get(sellerFields[0]?.group ?? "details") ?? sectionOf({ group: "business" } as Field),
        bottom: sections.get(last?.group ?? "business") ?? sectionOf({ group: "business" } as Field),
        save:
          saveSeller && sellerFields.some((f) => f.prefill === "business.name")
            ? async (data, id) => {
                const details = { name: "", address: "", gstin: "" }
                for (const f of sellerFields) {
                  const key = attribute(f) as keyof typeof details
                  if (key in details && details[key] === "") details[key] = data[f.key] ?? ""
                }
                const result = await saveSeller(details, id)
                return "error" in result ? result : { entry: asEntry(result.business), message: result.message }
              }
            : null,
        picked: (id) => onBusiness(businesses.find((b) => b.id === id) ?? null),
      },
      controls,
      () => onChange(read()),
    )
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
      const picker = periods.get(field.key)
      if (picker) {
        data[field.key] = picker.read()
        continue
      }
      const control = controls.get(field.key)!
      const raw = (control.value === OTHER_RATE ? (typedRates.get(field.key)?.value ?? "") : control.value).trim()
      if (raw === "") continue // optional and empty: omit
      data[field.key] = field.type === "number" || field.type === "tax_rate" ? Number(raw) : raw
    }
    return data
  }

  const onInput = () => onChange(read())
  form.addEventListener("input", onInput)

  return {
    read,
    /** "Edit and regenerate": the business the document was made with is chosen in the list again. */
    chooseBusiness(id: number | null) {
      businessPicker?.choose(id)
    },
    /** Takes the form's listener away, before the form is built again. */
    destroy() {
      form.removeEventListener("input", onInput)
    },
    /** Show server-side errors: `{ field_key: ["message"] }`. Pass {} to clear. */
    showErrors(errors: Record<string, string[]>) {
      for (const [key, el] of errorEls) el.textContent = (errors[key] ?? []).join(", ")
      for (const table of tables.values()) table.showErrors(errors)
      for (const picker of periods.values()) picker.showErrors(errors)
    },
  }
}
