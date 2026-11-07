// Restaurant bill, design t2: a receipt with dashed lines: the restaurant, "Receipt" in the first line, who and where on two sides,
// a table of items, the totals, and the time at the foot.
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
#show: base.with(width: 106mm, margin: (x: 6mm, y: 6mm), size: 9pt)
#set par(leading: 0.6em)

#let rule-with(label) = grid(columns: (1fr, auto, 1fr), column-gutter: 2mm, align(horizon, dashed()), text(size: 8pt, upper(label)), align(horizon, dashed()))

#align(center)[
  #picture(data, "logo", 10mm)
  #text(size: 12pt, weight: "bold", data.restaurant_name)
  #if some("restaurant_address") != none [ \ #text(weight: "bold", size: 8.5pt, lines(some("restaurant_address")))]
  #for id in ids [ \ #text(size: 8pt, fill: muted, id)]
]
#v(1mm)
#rule-with(t.receipt)
#v(1mm)
#grid(
  columns: (1fr, auto),
  row-gutter: 1.5mm,
  [#strong(t.customer + ":") #if some("customer_name") != none { some("customer_name") }], [#strong(t.bill_no + ":") #data.bill_number],
  [#if some("table_number") != none [#strong(t.table + ":") #some("table_number")]], [#strong(t.date + ":") #fmt-date(data.date)],
)
#v(1mm)
#dashed()
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  stroke: none,
  inset: (x: 1mm, y: 1.4mm),
  ..([#strong(t.item)], [#strong(t.price)], [#strong(t.qty)], [#strong(t.total)]),
  table.hline(stroke: (paint: luma(80), thickness: 0.5pt, dash: "dashed")),
  ..items.map(row => ([#row.name], [#money(row.rate)], [#fmt-number(row.qty)], [#money(row.amount)])).flatten(),
  table.hline(stroke: (paint: luma(80), thickness: 0.5pt, dash: "dashed")),
)
#align(right, grid(
  columns: (auto, auto, auto),
  column-gutter: 4mm,
  row-gutter: 1.6mm,
  align: (right, right, right),
  [#t.subtotal:], [], money(subtotal),
  ..if service != 0 { ([#t.service:], [#fmt-number(service-rate)%], money(service)) } else { () },
  ..for (name, percentage, amount) in tax-parts(rate, tax) { ([#name:], [#fmt-number(percentage)%], money(amount)) },
))
#v(1mm)
#dashed()
#v(1mm)
#grid(
  columns: (1fr, auto),
  [#t.paid_by: #option-label("payment_mode", data.payment_mode)], text(size: 11pt, weight: "bold")[#t.total: #money(total)],
)
#v(1mm)
#dashed()
#v(1mm)
#align(center, text(fill: muted)[\*\*#t.save_paper \ #if time != none [#t.time: #time]])
#v(1mm)
#dashed()
