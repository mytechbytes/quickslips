import { t } from "./i18n"
import { INPUT_CLASS, SECONDARY_BUTTON_CLASS } from "./styles"
import type { Field } from "./form"

export type ItemRow = { name?: string; qty?: number; rate?: number }

type Columns = { name: string; qty: string; rate: string }

const COLUMNS: (keyof ItemRow)[] = ["name", "qty", "rate"]

// The table: heads on top, a row per item, the amount of the row and a remove icon at its end. The amount is left out
// on a phone, where the row would not fit; the subtotal is still shown.
const CELL_INPUT_CLASS = INPUT_CLASS.replace("px-3 py-2.5", "px-2 py-2")
const HEAD_CLASS = "px-1 pb-1 text-xs font-medium text-ink-muted"

const isBlank = (row: ItemRow) => COLUMNS.every((column) => row[column] === undefined || row[column] === "")

/**
 * A table of items: add, edit and remove rows, with the amount of each row (quantity times rate) and the subtotal
 * worked out as you type. `read` gives the rows that have something in them; the server checks them again and
 * names a mistake after its cell (`items.2.qty`, see `QuickSlips.Templates.Validator`).
 */
export function createItemsField(
  field: Field,
  initial: ItemRow[] | undefined,
  ctx: { currency: string; formatMoney: (amount: number) => string },
  onChange: () => void,
) {
  const columns: Columns = {
    name: "Item",
    qty: "Qty",
    rate: "Rate ({currency})",
    ...field.columns,
  }
  const heads = {
    name: columns.name,
    qty: columns.qty,
    rate: columns.rate.replace("{currency}", ctx.currency),
  }
  const maxRows = field.max_rows ?? 30

  const wrapper = document.createElement("div")
  wrapper.id = `field-${field.key}`

  const label = document.createElement("p")
  label.className = "block text-sm/6 font-medium text-ink"
  label.textContent = field.label + (field.required ? " *" : "")

  const addButton = document.createElement("button")
  addButton.type = "button"
  addButton.id = `add-${field.key}`
  addButton.className = SECONDARY_BUTTON_CLASS
  addButton.innerHTML = `<span class="hero-plus size-4" aria-hidden="true"></span>`
  const addText = document.createElement("span")
  addText.textContent = t("add_item")
  addButton.append(addText)

  // The name of the table on the left, the button that adds a row on the right.
  const top = document.createElement("div")
  top.className = "mb-2 flex items-center justify-between gap-3"
  top.append(label, addButton)

  const table = document.createElement("table")
  table.className = "w-full table-fixed border-collapse"
  table.id = `items-${field.key}`
  const headRow = document.createElement("tr")
  const heads4 = [
    [heads.name, ""],
    [heads.qty, "w-16 text-right sm:w-20"],
    [heads.rate, "w-20 text-right sm:w-28"],
    [t("amount"), "hidden w-28 text-right sm:table-cell"],
  ]
  for (const [text, className] of heads4) {
    const th = document.createElement("th")
    th.scope = "col"
    th.className = `${HEAD_CLASS} text-left font-medium ${className}`
    th.textContent = text
    headRow.append(th)
  }
  const removeHead = document.createElement("th")
  removeHead.className = "w-10"
  removeHead.innerHTML = `<span class="sr-only"></span>`
  headRow.append(removeHead)
  const thead = document.createElement("thead")
  thead.append(headRow)
  table.append(thead)

  const error = document.createElement("p")
  error.id = `error-${field.key}`
  error.className = "mt-1.5 text-sm text-danger"

  const subtotalEl = document.createElement("p")
  subtotalEl.className = "mt-3 text-right text-sm/6 font-medium text-ink"
  subtotalEl.id = `subtotal-${field.key}`

  wrapper.append(top, table, error, subtotalEl)

  // Which row of the page each row that was sent is, so an error can be shown under the right one.
  let sentFrom: number[] = []

  const rows = () => [...table.querySelectorAll<HTMLElement>("tbody[data-item-row]")]

  const cellValue = (row: HTMLElement, column: keyof ItemRow): string =>
    row.querySelector<HTMLInputElement>(`[data-column=${column}]`)!.value.trim()

  const parsed = (row: HTMLElement): ItemRow => {
    const item: ItemRow = {}
    const name = cellValue(row, "name")
    if (name !== "") item.name = name
    for (const column of ["qty", "rate"] as const) {
      const raw = cellValue(row, column)
      if (raw !== "") item[column] = Number(raw)
    }
    return item
  }

  const amountOf = (item: ItemRow) => (item.qty ?? 0) * (item.rate ?? 0)

  function refresh() {
    let subtotal = 0
    const all = rows()
    for (const row of all) {
      const amount = amountOf(parsed(row))
      subtotal += amount
      row.querySelector("[data-amount]")!.textContent = ctx.formatMoney(amount)
      row.querySelector<HTMLButtonElement>("[data-remove]")!.disabled = all.length === 1
    }
    subtotalEl.textContent = `${t("subtotal")}: ${ctx.formatMoney(subtotal)}`
    addButton.hidden = all.length >= maxRows
  }

  function input(column: keyof ItemRow, value: string | number | undefined) {
    const el = document.createElement("input")
    el.dataset.column = column
    el.setAttribute("aria-label", heads[column as keyof typeof heads])
    el.className = CELL_INPUT_CLASS + (column === "name" ? "" : " text-right")
    if (column === "name") {
      el.type = "text"
      el.maxLength = field.name_max_length ?? 80
      el.autocomplete = "off"
    } else {
      el.type = "number"
      el.step = "any"
      el.min = column === "qty" ? "0.01" : "0"
      el.inputMode = "decimal"
    }
    if (value !== undefined) el.value = String(value)
    return el
  }

  function td(className: string, ...children: Node[]) {
    const cell = document.createElement("td")
    cell.className = `p-1 align-top ${className}`
    cell.append(...children)
    return cell
  }

  function addRow(item: ItemRow = {}) {
    const row = document.createElement("tbody")
    row.dataset.itemRow = ""

    const amount = document.createElement("span")
    amount.dataset.amount = ""

    const remove = document.createElement("button")
    remove.type = "button"
    remove.dataset.remove = ""
    remove.className =
      "inline-flex size-9 items-center justify-center rounded-button text-ink-muted hover:bg-danger-soft hover:text-danger focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus disabled:opacity-40 disabled:hover:bg-transparent disabled:hover:text-ink-muted"
    remove.innerHTML = `<span class="hero-trash size-5" aria-hidden="true"></span>`
    const removeText = document.createElement("span")
    removeText.className = "sr-only"
    remove.append(removeText)

    const main = document.createElement("tr")
    main.append(
      td("", input("name", item.name)),
      td("", input("qty", item.qty)),
      td("", input("rate", item.rate)),
      td("hidden pt-3 text-right text-sm/6 text-ink tabular-nums sm:table-cell", amount),
      td("text-right", remove),
    )

    const errorRow = document.createElement("tr")
    const errorCell = document.createElement("td")
    errorCell.colSpan = 5
    errorCell.dataset.rowError = ""
    errorCell.className = "px-1 pb-1 text-sm text-danger empty:hidden"
    errorRow.append(errorCell)

    row.append(main, errorRow)
    table.append(row)

    remove.addEventListener("click", () => {
      row.remove()
      renumber()
      refresh()
      onChange()
    })
    renumber()
    return row
  }

  // The remove buttons say which row they remove.
  function renumber() {
    rows().forEach((row, index) => {
      const text = t("remove_item", { number: index + 1 })
      const button = row.querySelector<HTMLButtonElement>("[data-remove]")!
      button.title = text
      button.querySelector("span:last-child")!.textContent = text
    })
  }

  for (const item of initial && initial.length > 0 ? initial : [{}]) addRow(item)
  refresh()

  table.addEventListener("input", () => {
    refresh()
    onChange()
  })
  addButton.addEventListener("click", () => {
    const row = addRow()
    refresh()
    row.querySelector<HTMLInputElement>("[data-column=name]")!.focus()
  })

  return {
    element: wrapper,
    /** The rows that have something in them. A row with nothing in it is not sent. */
    read(): ItemRow[] {
      sentFrom = []
      const items: ItemRow[] = []
      rows().forEach((row, index) => {
        const item = parsed(row)
        if (isBlank(item)) return
        sentFrom.push(index)
        items.push(item)
      })
      return items
    },
    /** Shows what the server said about this field: `{ "items": [...], "items.2.qty": [...] }`. */
    showErrors(errors: Record<string, string[]>) {
      error.textContent = (errors[field.key] ?? []).join(", ")
      const all = rows()
      for (const row of all) {
        row.querySelector("[data-row-error]")!.textContent = ""
        for (const input of row.querySelectorAll("input")) input.removeAttribute("aria-invalid")
      }
      const pattern = new RegExp(`^${field.key}\\.(\\d+)(?:\\.(\\w+))?$`)
      for (const [key, messages] of Object.entries(errors)) {
        const match = pattern.exec(key)
        if (!match) continue
        const row = all[sentFrom[Number(match[1])]]
        if (!row) continue
        const message = row.querySelector("[data-row-error]")!
        message.textContent = [message.textContent, ...messages].filter(Boolean).join(", ")
        if (match[2]) row.querySelector(`[data-column=${match[2]}]`)?.setAttribute("aria-invalid", "true")
      }
    },
  }
}
