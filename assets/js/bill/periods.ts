import type { Field } from "./form"
import { t } from "./i18n"
import { INPUT_CLASS } from "./styles"

/**
 * The period a receipt is for, as the server keeps it (see the `periods` field of `Templates.Validator`): how it is
 * billed, the month each period chosen starts in, and the optional date of the receipt of each.
 */
export type PeriodsValue = { bill_by: string; months: string[]; dates: string[]; numbers?: string[] }

const STEP: Record<string, number> = { Monthly: 1, Quarterly: 3, "Half-yearly": 6, Yearly: 12 }

// "2026-09" as a number of months, and back.
const toIndex = (ym: string) => Number(ym.slice(0, 4)) * 12 + Number(ym.slice(5, 7)) - 1
const toMonth = (index: number) => `${Math.floor(index / 12)}-${String((index % 12) + 1).padStart(2, "0")}`
/** "AIAJD098" gives "AIAJD099", "AB-9" gives "AB-10": the last run of digits goes up by one, with its zeros kept. */
export function nextNumber(value: string): string {
  const match = /^(.*?)(\d+)(\D*)$/.exec(value)
  if (!match) return ""
  const [, head, digits, tail] = match
  return head + String(BigInt(digits) + 1n).padStart(digits.length, "0") + tail
}
const currentMonth = () => new Date().toISOString().slice(0, 7)

// Billed by the year, the table lists the years from the start to this one, up to this many.
const MAX_YEARS = 10

const LABEL_CLASS = "mb-1 block text-sm/5 font-medium text-ink"

/**
 * The field for the period of a salary receipt. One row holds how it is billed (monthly, by the quarter, by the
 * half-year, by the year), the month the first period starts in, and a box for "multiple receipts". Below, a table
 * with borders lists the periods: a tick, the period, and the optional date of its receipt.
 *
 * With one receipt the table has the one row, ticked and fixed. With several it lists every period of the twelve
 * months from the start (twelve months, four quarters, two half-years), or, billed by the year, every year from the
 * start to the current one; the tick in the header ticks or unticks all, and billed monthly a day of the month in the
 * header of the dates gives every row that day. A receipt is made for each period ticked.
 */
export function createPeriodsField(field: Field, initial: PeriodsValue | undefined, onChange: () => void) {
  const lang = document.documentElement.lang || "en"
  const monthName = (ym: string) =>
    new Intl.DateTimeFormat(lang, { month: "short", year: "numeric", timeZone: "UTC" }).format(new Date(`${ym}-01T00:00:00Z`))

  let billBy = initial?.bill_by ?? field.options?.[0] ?? "Monthly"
  const startMonths = [...(initial?.months ?? [])].sort()
  let first = startMonths[0] ?? currentMonth()
  let several = startMonths.length > 1
  // The periods ticked, by the month they start in, and the date typed for each (kept when a period is ticked off and on).
  const chosen = new Set<string>(startMonths.length > 0 ? startMonths : [first])
  const dates = new Map<string, string>()
  ;(initial?.months ?? []).forEach((m, i) => {
    const date = initial?.dates?.[i]
    if (date) dates.set(m, date)
  })

  // The optional number of each receipt (a cash memo or voucher number), for a field that has the column.
  const hasNumbers = field.numbers === true
  const numbers = new Map<string, string>()
  // The numbers typed by hand: the others are the next of the number above them (AIAJD098, AIAJD099, AIAJD100).
  const typed = new Set<string>()
  ;(initial?.months ?? []).forEach((m, i) => {
    const number = initial?.numbers?.[i]
    if (number) {
      numbers.set(m, number)
      typed.add(m)
    }
  })

  const step = () => STEP[billBy] ?? 1
  const periodLabel = (start: string) =>
    step() === 1 ? monthName(start) : `${monthName(start)} – ${monthName(toMonth(toIndex(start) + step() - 1))}`
  /** The starts of the periods listed: one with a single receipt; else the twelve months from the first, or each year up to this one. */
  const starts = () => {
    if (!several) return [first]
    if (billBy === "Yearly") {
      const years = Math.min(Math.max(new Date().getFullYear() - Number(first.slice(0, 4)) + 1, 1), MAX_YEARS)
      return Array.from({ length: years }, (_, i) => toMonth(toIndex(first) + i * 12))
    }
    return Array.from({ length: 12 / step() }, (_, i) => toMonth(toIndex(first) + i * step()))
  }

  const root = document.createElement("div")
  root.dataset.fieldType = "periods"
  root.className = "sm:col-span-2 space-y-3"
  const id = `field-${field.key}`

  const row = document.createElement("div")
  row.className = "grid gap-x-3 gap-y-2.5 sm:grid-cols-3"

  const cell = (label: string, control: HTMLElement) => {
    const wrapper = document.createElement("div")
    const el = document.createElement("label")
    el.htmlFor = control.id
    el.className = LABEL_CLASS
    el.textContent = label
    wrapper.append(el, control)
    return wrapper
  }

  const by = document.createElement("select")
  by.id = `${id}-by`
  by.className = INPUT_CLASS
  for (const option of field.options ?? []) by.append(new Option(field.option_labels?.[option] ?? option, option))
  by.value = billBy

  const start = document.createElement("input")
  start.type = "month"
  start.id = `${id}-start`
  start.className = INPUT_CLASS
  start.value = first

  // "Multiple receipts": a box, under a label line of its own so that it lines up with the two controls beside it.
  const multiple = document.createElement("input")
  multiple.type = "checkbox"
  multiple.id = `${id}-multiple`
  multiple.checked = several
  multiple.className = "size-4 rounded border-line-strong text-primary focus:outline-2 focus:outline-focus"
  const multipleLabel = document.createElement("label")
  multipleLabel.htmlFor = multiple.id
  multipleLabel.className = "flex min-h-10 cursor-pointer items-center gap-2 text-sm/5 font-medium text-ink sm:min-h-9"
  multipleLabel.append(multiple, document.createTextNode(t("periods_multiple")))
  const multipleCell = document.createElement("div")
  const spacer = document.createElement("span")
  spacer.className = LABEL_CLASS + " invisible"
  spacer.setAttribute("aria-hidden", "true")
  spacer.textContent = "."
  multipleCell.append(spacer, multipleLabel)

  row.append(cell(t("periods_bill_by") + (field.required ? " *" : ""), by), cell(t("periods_start_month"), start), multipleCell)

  // The table, with its border and its lines between the rows and the columns.
  const frame = document.createElement("div")
  frame.className = "overflow-hidden rounded-card border border-line"
  const table = document.createElement("table")
  table.id = `${id}-table`
  table.className = "w-full border-collapse text-sm/5"
  table.innerHTML =
    `<thead class="bg-surface-muted"><tr class="text-left text-xs font-semibold uppercase tracking-wider text-ink-muted">` +
    `<th scope="col" class="w-12 border-b border-line px-3 py-2"></th>` +
    `<th scope="col" class="border-b border-l border-line px-3 py-2"></th>` +
    `<th scope="col" class="border-b border-l border-line px-3 py-2"><div class="flex flex-wrap items-center justify-between gap-2"><span></span></div></th>` +
    (hasNumbers ? `<th scope="col" class="border-b border-l border-line px-3 py-2"></th>` : "") +
    `</tr></thead><tbody></tbody>`
  frame.append(table)

  const checkAll = document.createElement("input")
  checkAll.type = "checkbox"
  checkAll.id = `${id}-check-all`
  checkAll.className = "size-4 rounded border-line-strong text-primary focus:outline-2 focus:outline-focus"
  checkAll.setAttribute("aria-label", t("periods_check_all"))
  table.querySelector("th:nth-child(1)")!.append(checkAll)
  table.querySelector("th:nth-child(2)")!.textContent = t("periods_period")
  table.querySelector("th:nth-child(3) span")!.textContent = t("periods_date")

  if (hasNumbers) table.querySelector("th:nth-child(4)")!.textContent = field.number_label ?? ""

  // The day of the month for every row (billed monthly, with several receipts).
  const day = document.createElement("select")
  day.id = `${id}-day`
  day.className = INPUT_CLASS + " !w-auto !py-1 text-xs normal-case tracking-normal"
  day.setAttribute("aria-label", t("periods_day"))
  day.append(new Option(t("periods_day"), ""))
  for (let d = 1; d <= 31; d++) day.append(new Option(String(d), String(d)))
  table.querySelector("th:nth-child(3) div")!.append(day)

  const body = table.querySelector("tbody")!

  const error = document.createElement("p")
  error.id = `error-${field.key}`
  error.className = "mt-1.5 text-sm text-danger"

  root.append(row, frame, error)

  const pad = (n: number) => String(n).padStart(2, "0")
  /** "2026-02" and 31 give "2026-02-28": a day that the month does not have is its last one. */
  function dayOf(month: string, d: number) {
    const last = new Date(Date.UTC(Number(month.slice(0, 4)), Number(month.slice(5, 7)), 0)).getUTCDate()
    return `${month}-${pad(Math.min(d, last))}`
  }

  function syncHeader() {
    const list = starts()
    const ticked = list.filter((m) => chosen.has(m)).length
    checkAll.checked = ticked === list.length
    checkAll.indeterminate = ticked > 0 && ticked < list.length
    checkAll.disabled = !several
    day.classList.toggle("hidden", !(several && billBy === "Monthly"))
  }

  /** Gives every ticked row without a typed number the next of the one above it. */
  function renumber() {
    if (!hasNumbers) return
    let previous = ""
    body.querySelectorAll<HTMLInputElement>("input[data-number]").forEach((input) => {
      const month = input.dataset.month!
      if (!chosen.has(month) && several) return
      if (typed.has(month)) previous = numbers.get(month) ?? ""
      else {
        const next = previous ? nextNumber(previous) : ""
        input.value = next
        if (next) numbers.set(month, next)
        else numbers.delete(month)
        previous = next
      }
    })
  }

  function drawRows() {
    body.replaceChildren()
    starts().forEach((month, i) => {
      const tr = document.createElement("tr")

      const tick = document.createElement("td")
      tick.className = "border-b border-line px-3 py-1.5 last:border-b-0"
      const box = document.createElement("input")
      box.type = "checkbox"
      box.id = `${id}-tick-${i}`
      box.value = month
      box.checked = !several || chosen.has(month)
      box.disabled = !several // one receipt: the one row is ticked and cannot be changed
      box.className = "size-4 rounded border-line-strong text-primary focus:outline-2 focus:outline-focus"
      tick.append(box)

      const name = document.createElement("td")
      name.className = "border-b border-l border-line px-3 py-1.5"
      const label = document.createElement("label")
      label.htmlFor = box.id
      label.className = "cursor-pointer text-ink"
      label.textContent = periodLabel(month)
      name.append(label)

      const when = document.createElement("td")
      when.className = "border-b border-l border-line px-3 py-1.5"
      const date = document.createElement("input")
      date.type = "date"
      date.id = `${id}-date-${i}`
      date.dataset.month = month
      date.className = INPUT_CLASS
      date.value = dates.get(month) ?? ""
      date.disabled = !box.checked
      date.setAttribute("aria-label", `${t("periods_date")}: ${periodLabel(month)}`)
      date.addEventListener("input", () => {
        if (date.value) dates.set(month, date.value)
        else dates.delete(month)
      })

      box.addEventListener("change", () => {
        if (box.checked) chosen.add(month)
        else if (chosen.size > 1) chosen.delete(month)
        else box.checked = true // a receipt needs a period
        date.disabled = !box.checked
        syncHeader()
        onChange()
      })
      when.append(date)
      tr.append(tick, name, when)
      if (hasNumbers) {
        const cellNumber = document.createElement("td")
        cellNumber.className = "border-b border-l border-line px-3 py-1.5"
        const number = document.createElement("input")
        number.type = "text"
        number.id = `${id}-number-${i}`
        number.dataset.number = "true"
        number.dataset.month = month
        number.maxLength = 30
        number.className = INPUT_CLASS
        number.value = numbers.get(month) ?? ""
        number.disabled = !box.checked
        number.setAttribute("aria-label", `${field.number_label ?? ""}: ${periodLabel(month)}`)
        number.addEventListener("input", () => {
          const value = number.value.trim()
          if (value) {
            numbers.set(month, value)
            typed.add(month)
          } else {
            numbers.delete(month)
            typed.delete(month)
          }
          renumber()
        })
        box.addEventListener("change", () => {
          number.disabled = !box.checked
          renumber()
        })
        cellNumber.append(number)
        tr.append(cellNumber)
      }
      body.append(tr)
    })
    // The last row has no line under it: the frame has the border.
    for (const c of body.lastElementChild?.children ?? []) (c as HTMLElement).classList.replace("border-b", "border-b-0")
    renumber()
    syncHeader()
  }

  /** Keeps what is ticked to the periods listed, and at least one. */
  function fit() {
    const here = new Set(starts())
    for (const m of [...chosen]) if (!here.has(m)) chosen.delete(m)
    if (chosen.size === 0) chosen.add(first)
    if (!several) for (const m of [...chosen].sort().slice(1)) chosen.delete(m)
    day.value = ""
  }

  by.addEventListener("change", () => {
    billBy = by.value
    fit()
    drawRows()
    onChange()
  })
  start.addEventListener("change", () => {
    if (!/^\d{4}-\d{2}$/.test(start.value)) return
    first = start.value
    chosen.clear() // the periods are new ones: the first is ticked
    chosen.add(first)
    drawRows()
    onChange()
  })
  multiple.addEventListener("change", () => {
    several = multiple.checked
    fit()
    drawRows()
    onChange()
  })
  checkAll.addEventListener("change", () => {
    if (checkAll.checked) for (const m of starts()) chosen.add(m)
    else {
      chosen.clear()
      chosen.add(first) // a receipt needs a period: the first stays
    }
    drawRows()
    onChange()
  })
  day.addEventListener("change", () => {
    if (!day.value) return
    // The same day of its month on every row (a row that is not ticked keeps the date for when it is).
    for (const m of starts()) dates.set(m, dayOf(m, Number(day.value)))
    drawRows()
    onChange()
  })
  body.addEventListener("input", onChange)

  fit()
  drawRows()

  return {
    element: root,
    read(): PeriodsValue {
      const list = starts().filter((m) => chosen.has(m) || !several)
      const value: PeriodsValue = { bill_by: billBy, months: list, dates: list.map((m) => dates.get(m) ?? "") }
      if (hasNumbers) value.numbers = list.map((m) => numbers.get(m) ?? "")
      return value
    },
    showErrors(errors: Record<string, string[]>) {
      error.textContent = (errors[field.key] ?? []).join(", ")
    },
  }
}
