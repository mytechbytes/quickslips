import { t } from "./i18n"
import { INPUT_CLASS, SECONDARY_BUTTON_CLASS } from "./styles"
import type { Field } from "./form"

export type ItemRow = { name?: string; qty?: number; rate?: number; code?: string; billing?: string; discount?: number }

type Cell = keyof ItemRow

// The cells of a row, in the order of the field's `cells`; a table that names none has the first three.
const DEFAULT_CELLS: Cell[] = ["name", "qty", "rate"]
const DEFAULT_HEADS: Record<Cell, string> = {
  code: "Code",
  name: "Item",
  billing: "Billing",
  qty: "Qty",
  rate: "Rate ({currency})",
  discount: "Disc. %",
}
// The widths of the cells in rem (the classes below), to tell how wide a table with many cells must be.
const CELL_REM: Record<string, number> = { code: 7, billing: 7, qty: 5, rate: 7, discount: 5, amount: 7, remove: 2.5, name: 14 }
// In a table with many cells the widths are the same on every screen, because it scrolls.
const WIDE_WIDTH: Partial<Record<Cell, string>> = { code: "w-28", billing: "w-28", qty: "w-20", rate: "w-28", discount: "w-20" }
// The widths of the narrow cells; the name takes what is left.
const CELL_WIDTH: Partial<Record<Cell, string>> = {
  code: "w-28",
  billing: "w-28",
  qty: "w-16 sm:w-20",
  rate: "w-20 sm:w-28",
  discount: "w-20",
}

// The table: heads on top, a row per item, the amount of the row and a remove icon at its end. The amount is left out
// on a phone, where the row would not fit; the subtotal is still shown.
const CELL_INPUT_CLASS = INPUT_CLASS.replace("px-3 py-2", "px-2 py-1.5").replace("sm:py-1.5", "sm:py-1")
const HEAD_CLASS = "px-2 py-2 text-xs font-medium text-ink-muted"

// A choice (the billing type) has a value from the start, so it does not count as something typed in.
const isBlank = (row: ItemRow) =>
  (Object.keys(row) as Cell[]).every((cell) => cell === "billing" || row[cell] === undefined || row[cell] === "")

const isNumeric = (cell: Cell) => cell === "qty" || cell === "rate" || cell === "discount"

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
  const cells = (field.cells ?? DEFAULT_CELLS) as Cell[]
  const hasQty = cells.includes("qty")
  const heads = Object.fromEntries(
    cells.map((cell) => [cell, ({ ...DEFAULT_HEADS, ...field.columns }[cell] ?? cell).replace("{currency}", ctx.currency)]),
  ) as Record<Cell, string>
  const maxRows = field.max_rows ?? 30

  const wrapper = document.createElement("div")
  wrapper.id = `field-${field.key}`
  // A grid item does not shrink below its content: without this a wide table would stretch the form on a phone.
  wrapper.className = "min-w-0"

  const addButton = document.createElement("button")
  addButton.type = "button"
  addButton.id = `add-${field.key}`
  addButton.className = SECONDARY_BUTTON_CLASS
  addButton.innerHTML = `<span class="hero-plus size-4" aria-hidden="true"></span>`
  const addText = document.createElement("span")
  addText.textContent = t("add_item")
  addButton.append(addText)

  // A table in a box: the heads on a tinted row, a line between the rows, and a foot with the button that adds a
  // row on the left and the subtotal on the right. The name of the field is the caption, for those who hear it.
  const table = document.createElement("table")
  table.className = "w-full table-fixed border-collapse"
  // A table with many cells is wider than the form: the name keeps room to be read and the box scrolls sideways.
  if (cells.length > 3) {
    const width = cells.reduce((sum, cell) => sum + (CELL_REM[cell] ?? 0), CELL_REM.amount + CELL_REM.remove)
    table.style.minWidth = `${width}rem`
  }
  table.id = `items-${field.key}`
  const caption = document.createElement("caption")
  caption.className = "sr-only"
  caption.textContent = field.label + (field.required ? " *" : "")
  table.append(caption)
  const headRow = document.createElement("tr")
  headRow.className = "bg-surface-muted"
  const headCells: string[][] = [
    ...cells.map((cell) => [
      heads[cell],
      `${cells.length > 3 ? WIDE_WIDTH[cell] : (CELL_WIDTH[cell] ?? "")} ${isNumeric(cell) ? "text-right" : ""}`,
    ]),
    [t("amount"), "hidden w-28 text-right sm:table-cell"],
  ]
  for (const [text, className] of headCells) {
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
  subtotalEl.className = "text-right text-sm/6 font-medium text-ink"
  subtotalEl.id = `subtotal-${field.key}`

  const foot = document.createElement("div")
  foot.className = "flex items-center justify-between gap-3 border-t border-line px-2 py-2"
  foot.append(addButton, subtotalEl)

  // A table with many cells is wider than a phone: the box scrolls sideways.
  const box = document.createElement("div")
  box.className = "overflow-x-auto rounded-card border border-line"
  box.append(table, foot)

  wrapper.append(box, error)

  // Which row of the page each row that was sent is, so an error can be shown under the right one.
  let sentFrom: number[] = []

  const rows = () => [...table.querySelectorAll<HTMLElement>("tbody[data-item-row]")]

  const cellValue = (row: HTMLElement, column: Cell): string =>
    row.querySelector<HTMLInputElement | HTMLSelectElement>(`[data-column=${column}]`)!.value.trim()

  const parsed = (row: HTMLElement): ItemRow => {
    const item: ItemRow = {}
    for (const cell of cells) {
      const raw = cellValue(row, cell)
      if (raw === "") continue
      if (isNumeric(cell)) item[cell as "qty" | "rate" | "discount"] = Number(raw)
      else item[cell as "name" | "code" | "billing"] = raw
    }
    return item
  }

  // Quantity times rate, less the discount; a table without a quantity has one of each.
  const amountOf = (item: ItemRow) =>
    (hasQty ? (item.qty ?? 0) : 1) * (item.rate ?? 0) * (1 - Math.min(item.discount ?? 0, 100) / 100)

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

  function input(column: Cell, value: string | number | undefined) {
    if (column === "billing") {
      const select = document.createElement("select")
      select.dataset.column = column
      select.setAttribute("aria-label", heads[column])
      select.className = CELL_INPUT_CLASS
      for (const option of field.billing_options ?? []) {
        const el = document.createElement("option")
        el.value = option
        el.textContent = field.option_labels?.[option] ?? option
        select.append(el)
      }
      if (value !== undefined) select.value = String(value)
      return select
    }
    const el = document.createElement("input")
    el.dataset.column = column
    el.setAttribute("aria-label", heads[column])
    el.className = CELL_INPUT_CLASS + (isNumeric(column) ? " text-right" : "")
    if (column === "name" || column === "code") {
      el.type = "text"
      el.maxLength = column === "name" ? (field.name_max_length ?? 80) : (field.code_max_length ?? 30)
      el.autocomplete = "off"
    } else {
      el.type = "number"
      el.step = "any"
      el.min = column === "qty" ? "0.01" : "0"
      if (column === "discount") el.max = "100"
      el.inputMode = "decimal"
    }
    if (value !== undefined) el.value = String(value)
    return el
  }

  function td(className: string, ...children: Node[]) {
    const cell = document.createElement("td")
    cell.className = `border-t border-line px-2 py-1.5 align-middle ${className}`
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
      ...cells.map((cell) => td("", input(cell, item[cell]))),
      td("hidden text-right text-sm/6 text-ink tabular-nums sm:table-cell", amount),
      td("text-right", remove),
    )

    const errorRow = document.createElement("tr")
    const errorCell = document.createElement("td")
    errorCell.colSpan = cells.length + 2
    errorCell.dataset.rowError = ""
    errorCell.className = "px-2 pb-1 text-sm text-danger empty:hidden"
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
    row.querySelector<HTMLInputElement>(`[data-column=${cells[0]}]`)!.focus()
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
        for (const input of row.querySelectorAll("input, select")) input.removeAttribute("aria-invalid")
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
