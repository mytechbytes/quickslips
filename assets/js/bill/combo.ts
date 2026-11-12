import { t } from "./i18n"

const BUTTON_CLASS =
  "flex w-full min-w-0 items-center justify-between gap-2 rounded-field border border-line-strong bg-surface px-2.5 py-1.5 text-left text-sm text-ink focus:border-focus focus:outline-2 focus:-outline-offset-1 focus:outline-focus"
const OPTION_CLASS = "block w-full cursor-pointer truncate px-2.5 py-1.5 text-left text-sm text-ink aria-selected:font-semibold data-[active=true]:bg-surface-muted"

const valueSetter = Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, "value")!

/**
 * Makes a `<select>` that lists saved things (employees, businesses, signatures, stamps) searchable: the select stays in
 * the page, hidden, as the one place the choice is kept and read, and a button in its place opens a list with a box that
 * filters it as the visitor types. Whatever changes the select afterwards (new options, a value set from the script, the
 * `hidden` attribute) shows in the button.
 */
export function makeSearchable(select: HTMLSelectElement) {
  if (select.dataset.searchable === "true") return
  select.dataset.searchable = "true"

  const id = select.id || `combo-${Math.random().toString(36).slice(2, 8)}`
  const wrapper = document.createElement("div")
  wrapper.className = "relative min-w-0 flex-1"
  wrapper.dataset.combo = id

  const button = document.createElement("button")
  button.type = "button"
  button.className = BUTTON_CLASS
  button.setAttribute("aria-haspopup", "listbox")
  button.setAttribute("aria-expanded", "false")
  const label = document.createElement("span")
  label.className = "truncate"
  const chevron = document.createElement("span")
  chevron.setAttribute("aria-hidden", "true")
  chevron.className = "shrink-0 text-ink-muted"
  chevron.textContent = "▾"
  button.append(label, chevron)

  const panel = document.createElement("div")
  panel.className = "absolute inset-x-0 top-full z-30 mt-1 hidden rounded-field border border-line-strong bg-surface shadow-lg"
  const search = document.createElement("input")
  search.type = "search"
  search.autocomplete = "off"
  search.id = `${id}-search`
  search.placeholder = t("search")
  search.setAttribute("aria-label", t("search"))
  search.className = "block w-full rounded-t-field border-0 border-b border-line bg-surface px-2.5 py-1.5 text-sm text-ink focus:outline-2 focus:-outline-offset-2 focus:outline-focus"
  const list = document.createElement("div")
  list.setAttribute("role", "listbox")
  list.className = "max-h-56 overflow-y-auto py-1"
  const none = document.createElement("p")
  none.className = "hidden px-2.5 py-1.5 text-sm text-ink-muted"
  none.textContent = t("search_none")
  panel.append(search, list, none)
  wrapper.append(button, panel)

  select.after(wrapper)
  select.classList.add("sr-only")
  select.tabIndex = -1
  select.setAttribute("aria-hidden", "true")

  let active = -1
  const items = () => Array.from(list.children) as HTMLButtonElement[]

  function show() {
    const chosen = select.selectedOptions[0]
    label.textContent = chosen?.text ?? ""
    label.classList.toggle("text-ink-muted", !select.value)
    wrapper.hidden = select.hidden || select.classList.contains("hidden")
  }

  function fill() {
    const wanted = search.value.trim().toLowerCase()
    list.replaceChildren()
    for (const option of Array.from(select.options)) {
      if (wanted && option.value !== "" && !option.text.toLowerCase().includes(wanted)) continue
      if (wanted && option.value === "") continue
      const item = document.createElement("button")
      item.type = "button"
      item.setAttribute("role", "option")
      item.setAttribute("aria-selected", String(option.value === select.value))
      item.dataset.value = option.value
      item.className = OPTION_CLASS
      item.textContent = option.text
      item.addEventListener("click", () => choose(option.value))
      list.append(item)
    }
    none.classList.toggle("hidden", list.children.length > 0)
    mark(list.children.length > 0 ? Math.max(items().findIndex((i) => i.getAttribute("aria-selected") === "true"), 0) : -1)
  }

  function mark(index: number) {
    active = index
    items().forEach((item, i) => (item.dataset.active = String(i === index)))
    items()[index]?.scrollIntoView({ block: "nearest" })
  }

  function choose(value: string) {
    close()
    if (value === select.value) return
    valueSetter.set!.call(select, value)
    show()
    select.dispatchEvent(new Event("change", { bubbles: true }))
  }

  function open() {
    search.value = ""
    fill()
    panel.classList.remove("hidden")
    button.setAttribute("aria-expanded", "true")
    search.focus()
  }

  function close() {
    panel.classList.add("hidden")
    button.setAttribute("aria-expanded", "false")
  }

  button.addEventListener("click", () => (panel.classList.contains("hidden") ? open() : close()))
  search.addEventListener("input", fill)
  search.addEventListener("keydown", (event) => {
    if (event.key === "Escape") {
      event.preventDefault()
      close()
      button.focus()
    } else if (event.key === "ArrowDown") {
      event.preventDefault()
      mark(Math.min(active + 1, items().length - 1))
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      mark(Math.max(active - 1, 0))
    } else if (event.key === "Enter") {
      event.preventDefault()
      const item = items()[active]
      if (item) choose(item.dataset.value ?? "")
    }
  })
  document.addEventListener("click", (event) => {
    if (!wrapper.contains(event.target as Node)) close()
  })

  // A value set from the script (`select.value = ...`) does not fire `change`: it is noticed here.
  Object.defineProperty(select, "value", {
    get: () => valueSetter.get!.call(select),
    set: (v: string) => {
      valueSetter.set!.call(select, v)
      show()
    },
  })
  new MutationObserver(show).observe(select, { childList: true, subtree: true, attributes: true, attributeFilter: ["hidden", "class"] })
  show()
}
