// Restaurant bill, design t3: a compact bill: the restaurant in bold, a table of items under a rule, small tax lines, a big
// total between two dotted rules, and the details of the bill and two lines of thanks below.
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
#show: base.with(width: 95mm, margin: (x: 6mm, y: 6mm), size: 8.5pt)
#set par(leading: 0.55em)

#let dotted() = line(length: 100%, stroke: (paint: luma(80), thickness: 0.7pt, dash: "dotted"))

#align(center)[
  #picture(data, "logo", 9mm)
  #text(size: 12pt, weight: "bold", data.restaurant_name)
  #if some("restaurant_address") != none [ \ #lines(some("restaurant_address"))]
  #for id in ids [ \ #text(size: 7.5pt, fill: muted, id)]
]
#v(1mm)
#dotted()
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  stroke: none,
  inset: (x: 0.5mm, y: 1.3mm),
  ..([#strong(t.item)], [#strong(t.qty)], [#strong(t.price)], [#strong(t.subtotal)]),
  table.hline(stroke: 0.8pt),
  ..items.map(row => ([#row.name], [#fmt-number(row.qty)], [#money(row.rate)], [#money(row.amount)])).flatten(),
)
#v(1mm)
#grid(
  columns: (1fr, auto),
  [#t.subtotal], money(subtotal),
)
#v(1mm)
#text(size: 7.5pt)[
  #if service != 0 [#t.service: #fmt-number(service-rate)% #money(service) \ ]
  #for (name, percentage, amount) in tax-parts(rate, tax) [#name: #fmt-number(percentage)% #money(amount) \ ]
]
#v(1mm)
#dotted()
#v(1mm)
#grid(columns: (1fr, auto), text(size: 11pt, weight: "bold", upper(t.total)), text(size: 11pt, weight: "bold", money(total)))
#v(1mm)
#dotted()
#v(2mm)
#t.paid_by: #option-label("payment_mode", data.payment_mode)
#v(1mm)
#text(size: 7.5pt)[
  #fmt-date(data.date)#if time != none [ : #time] \
  #t.receipt_no: #data.bill_number \
  #if some("table_number") != none [#t.table: #some("table_number") \ ]
  #if some("customer_name") != none [#t.customer: #some("customer_name")]
]
#v(2mm)
#align(center, text(weight: "bold")[#upper(t.save_paper) \ #t.support_local])
