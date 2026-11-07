// Laundry bill, design t1: a bill with a yellow head, 120 mm wide: the laundry, the invoice ID, the date and the delivery date, "Bill to", a
// table of the garments (quantity, price, total), the subtotal, the tax and the grand total with the payment method, and the terms and
// conditions. The tax is added to the subtotal, or is part of the prices where the country says so. Reads data.json (next to this file).
// The words come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 120mm, margin: (x: 8mm, y: 0mm), size: 8.5pt)
#set page(margin: (x: 8mm, top: 0mm, bottom: 8mm))
#set par(leading: 0.55em)
#set block(spacing: 0pt)

#let rows = item-rows(data)
#let subtotal = sum-of(rows.map(row => row.amount))
#let rate = some("tax_percent")
#let tax = if rate != none { calc.round(tax-split(subtotal, rate).tax, digits: 2) } else { 0 }
#let total = if tax-mode == "included" { subtotal } else { subtotal + tax }
#let terms-list = if some("terms") != none { some("terms").split("\n").filter(line => line != "") } else { () }
#let yellow = rgb("#f6cf3c")
#let spaced(body) = text(tracking: 0.8pt, upper(body))

#move(dx: -8mm, block(width: 100% + 16mm, fill: yellow, inset: (x: 8mm, top: 9mm, bottom: 7mm), align(center)[
  #picture(data, "logo", 10mm)
  #text(size: 9pt, weight: "bold", data.laundry_name) \
  #if some("laundry_address") != none [#text(size: 7pt, lines(data.laundry_address)) \ ]
  #v(2mm)
  #text(size: 17pt, weight: "bold", tracking: 1pt, [\##data.invoice_number]) \
  #v(1.5mm)
  #text(size: 7.5pt, spaced([#t.date #fmt-date(data.date)])) \
  #text(size: 7.5pt, spaced([#t.delivery_date #fmt-date(data.delivery_date)]))
]))
#v(5mm)
#text(size: 7.5pt, weight: "bold", spaced(t.bill_to))
#v(1mm)
#strong(data.customer_name)
#if some("customer_address") != none [ \ #lines(some("customer_address"))]
#v(5mm)
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  stroke: (x, y) => (bottom: 0.5pt + luma(225)),
  inset: (x: 1.5mm, y: 2.4mm),
  ..(t.description, t.qty, t.price, t.total).map(head => text(size: 7.5pt, weight: "bold", tracking: 0.5pt, upper(head))),
  ..rows.map(row => (row.name, [#fmt-number(row.qty)], money(row.rate), money(row.amount))).flatten(),
)
#v(4mm)
#align(right, block(width: 62mm, {
  let line-of(label, value, bold: false) = {
    grid(columns: (1fr, auto), column-gutter: 4mm, inset: (y: 1.6mm), text(size: 7.5pt, weight: if bold { "bold" } else { "regular" }, spaced(label)), text(weight: if bold { "bold" } else { "regular" }, value))
    line(length: 100%, stroke: 0.4pt + luma(225))
  }
  line-of(t.subtotal, money(subtotal))
  if rate != none {
    line-of(t.tax_pct, [#fmt-number(rate) %])
    line-of(t.tax_amount, money(tax))
  }
  line-of(t.grand_total, money(total), bold: true)
  line-of(t.payment_method, option-label("payment_mode", data.payment_mode))
}))
#v(5mm)
#if terms-list.len() > 0 [
  #text(size: 7.5pt, weight: "bold", spaced(t.terms))
  #v(1.5mm)
  #text(size: 7pt, terms-list.map(line => [#line]).join(v(1.2mm)))
]
