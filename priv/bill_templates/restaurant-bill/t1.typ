// Restaurant bill, design t1: a thermal slip in capitals, after the pixel receipts of a till: a welcome, the restaurant, the
// date, time, customer, table and receipt number, the items, the totals with the tax, the way of payment and two lines of thanks.
// Reads data.json (next to this file). The words come from text.json (`t`), the number and date formats from region.json.
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
#show: base.with(width: 106mm, margin: (x: 5mm, y: 5mm), size: 8.5pt)
#set text(weight: "bold", tracking: 0.25pt)
#set par(leading: 0.55em)

// "LABEL: value" in capitals, nothing for an empty field.
#let row(label, value) = if value != none { upper(label + ": ") + value }

#align(center)[
  #picture(data, "logo", 10mm)
  #upper(t.welcome) \
  #text(size: 11pt, upper(data.restaurant_name))
  #if some("restaurant_address") != none [ \ #upper(lines(some("restaurant_address")))]
  #for id in ids [ \ #upper(id)]
  \ #upper(t.original)
]
#v(2mm)
#grid(
  columns: (1fr, auto),
  upper(t.date + ": ") + fmt-date(data.date), if time != none { upper(t.time + ": ") + time },
)
#v(1mm)
#row(t.customer, some("customer_name")) \
#row(t.table, some("table_number")) \
#row(t.receipt_no, data.bill_number)
#v(2mm)
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  stroke: none,
  inset: (x: 1mm, y: 0.8mm),
  ..([#upper(t.description)], [#upper(t.qty)], [#upper(t.price)], [#upper(t.subtotal)]),
  table.hline(stroke: 0.5pt),
  ..items.map(row => ([#row.name], [#fmt-number(row.qty)], [#money(row.rate)], [#money(row.amount)])).flatten(),
  table.hline(stroke: 0.5pt),
)
#v(1mm)
#align(right, grid(
  columns: (auto, auto),
  column-gutter: 4mm,
  row-gutter: 1.6mm,
  align: (right, right),
  upper(t.subtotal + ":"), money(subtotal),
  ..if service != 0 { (upper(t.service + " (" + fmt-number(service-rate) + "%):"), money(service)) } else { () },
  ..for (name, percentage, amount) in tax-parts(rate, tax) { (upper(name + ": " + fmt-number(percentage) + "%"), money(amount)) },
  text(size: 10pt, upper(t.total + ":")), text(size: 10pt, money(total)),
))
#v(2mm)
#row(t.paid_by, option-label("payment_mode", data.payment_mode))
#v(1mm)
#align(center)[#upper(t.save_paper) \ #upper(t.thanks_meal)]
