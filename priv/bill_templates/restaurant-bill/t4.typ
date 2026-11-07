// Restaurant bill, design t4: a bill typed in capitals: the restaurant in big letters, the bill number, a table of items, the totals
// (the tax lines, the round off), the way of payment and a line of thanks.
#import "_shared/helpers.typ": *
#let data = json("data.json")

#let items = item-rows(data)
#let subtotal = sum-of(items.map(row => row.amount))
#let service-rate = num(data, "service_percent")
#let service = calc.round(subtotal * service-rate / 100, digits: 2)
#let taxable = subtotal + service
#let rate = opt(data, "gst_percent")
// Where the tax is part of the price (Spain, Germany...) the total is the taxable amount; where it is added (India, the
// United States) the total is that and the tax.
#let tax = if rate != none { calc.round(tax-split(taxable, rate).tax, digits: 2) } else { 0 }
#let included = tax-mode == "included"
#let total = if included { taxable } else { taxable + tax }
#let some(key) = opt(data, key)
#let time = if some("time") != none { fmt-time(some("time")) }
#let ids = (
  if some("gstin") != none { tax-id-label + ": " + some("gstin") },
  if some("fssai_number") != none { "FSSAI Lic. No.: " + some("fssai_number") },
).filter(id => id != none)
#show: base.with(width: 80mm, margin: (x: 5mm, y: 6mm), size: 8pt)
#set text(tracking: 0.15pt)
#set par(leading: 0.55em)

// A price or an amount without the currency sign, with the decimals of the currency: "120.00".
#let plain(n) = money(n).replace(region.currency.symbol, "").replace("\u{a0}", "").trim()

// Where India rounds the total to a whole rupee, the bill says by how much.
#let rounded = if region.country == "in" and total != calc.round(total) { calc.round(total) } else { total }
#let round-off = rounded - total
#let upper-row(label, value) = if value != none { upper(label + ": ") + value }

#align(center)[
  #picture(data, "logo", 9mm)
  #text(size: 13pt, weight: "bold", upper(data.restaurant_name))
  #if some("restaurant_address") != none [ \ #text(size: 7pt, upper(lines(some("restaurant_address"))))]
  #for id in ids [ \ #text(size: 7pt, upper(id))]
  \ #text(size: 8.5pt, weight: "bold", upper(t.bill_no + ": " + data.bill_number))
]
#v(1mm)
#dashed()
#v(1mm)
#grid(
  columns: (1fr, auto),
  row-gutter: 1.5mm,
  [#upper-row(t.table, some("table_number"))#if time != none [#if some("table_number") != none [ · ]#upper(t.time + ": " + time)]], upper(t.date + ": " + fmt-date(data.date)),
  grid.cell(colspan: 2, if some("customer_name") != none { upper(t.customer + ": " + some("customer_name")) }),
)
#v(1mm)
#dashed()
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  stroke: none,
  inset: (x: 0.5mm, y: 1.2mm),
  ..([#strong(upper(t.description))], [#strong(upper(t.qty))], [#strong(upper(t.price))], [#strong(upper(t.amount))]),
  table.hline(stroke: (paint: luma(80), thickness: 0.5pt, dash: "dashed")),
  ..items.map(row => ([#upper(row.name)], [#fmt-number(row.qty)], [#plain(row.rate)], [#plain(row.amount)])).flatten(),
  table.hline(stroke: (paint: luma(80), thickness: 0.5pt, dash: "dashed")),
)
#grid(
  columns: (1fr, auto),
  row-gutter: 1.6mm,
  upper(t.subtotal), align(right, money(subtotal)),
  ..if service != 0 { (upper(t.service + " @ " + fmt-number(service-rate) + "%"), align(right, money(service))) } else { () },
  ..for (name, percentage, amount) in tax-parts(rate, tax) { (upper(name + " @ " + fmt-number(percentage) + "%"), align(right, money(amount))) },
  ..if round-off != 0 { (align(right, upper("( + ) " + t.round_off)), align(right, money(round-off))) } else { () },
)
#v(1mm)
#dashed()
#v(1mm)
#grid(columns: (1fr, auto), text(size: 12pt, weight: "bold", upper(t.total)), text(size: 12pt, weight: "bold", money(rounded)))
#v(1mm)
#dashed()
#v(1mm)
#if included [
  #align(center, text(weight: "bold", upper(t.above_incl)))
  #v(1mm)
]
#if rate != none {
  grid(columns: (1fr, auto), upper(t.total_tax), align(right, money(tax)))
  v(1mm)
}
#dashed()
#v(1mm)
#grid(columns: (1fr, auto), strong(upper(t.paid_by + ":")), strong(upper(option-label("payment_mode", data.payment_mode))))
#v(1mm)
#dashed()
#v(1mm)
#align(center, text(weight: "bold")[#upper(t.thanks_visit)])
