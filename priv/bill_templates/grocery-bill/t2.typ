// Grocery bill, design t2: an invoice with the savings: a table of the items with their net price and total, a sub total in a tinted bar,
// a dashed box with the total saving in money and in percent, the total, and the payment, the transaction and the customer.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)

// What the items are: the price times the quantity (the list price), and with the discount of each line the net amount.
#let rows = item-rows(data)
#let list-total = sum-of(rows.map(row => row.qty * row.rate))
#let subtotal = sum-of(rows.map(row => row.amount))
#let discount = calc.min(num(data, "discount"), subtotal)
#let taxable = subtotal - discount
#let rate = some("tax_percent")
// Where the tax is part of the prices the total is what is left after the discount; where it is added the total has it on top.
#let tax = if rate != none { calc.round(tax-split(taxable, rate).tax, digits: 2) } else { 0 }
#let included = tax-mode == "included"
#let total = if included { taxable } else { taxable + tax }
#let saving = list-total - subtotal + discount
#let saving-pct = if list-total == 0 { 0 } else { saving / list-total * 100 }
#let time = if some("time") != none { fmt-time(some("time")) }
#let kv(label, value) = if value != none [#label: #value]
#show: base.with(width: 119mm, margin: (x: 7mm, y: 7mm), size: 9pt)
#set par(leading: 0.6em)

#let bar-fill = rgb("#fbe8bd")
#let bar(label, value, size: 10pt) = block(width: 100%, fill: bar-fill, inset: (x: 3mm, y: 2.4mm), radius: 1.2mm, grid(
  columns: (1fr, auto), text(size: size, weight: "bold", label), text(size: size, weight: "bold", value),
))

#align(center)[
  #picture(data, "logo", 11mm)
  #text(size: 13pt, weight: "bold", data.store_name)
  #if some("store_address") != none [ \ #lines(some("store_address"))]
  #if some("store_phone") != none [ \ #t.phone: #some("store_phone")]
  #if some("gstin") != none [ \ #tax-id-label: #some("gstin")]
  #if some("fssai_number") != none [ \ FSSAI No.: #some("fssai_number")]
  \ #text(size: 8pt, fill: muted)[#t.bill_no: #data.bill_number · #fmt-date(data.date)#if time != none [ #time]]
]
#v(2mm)
#table(
  columns: (auto, 1fr, auto, auto, auto),
  align: (left, left, right, right, right),
  stroke: none,
  inset: (x: 1.5mm, y: 1.6mm),
  table.header(..([#t.sn], [#t.item_name], [#t.qty], [#t.unit_price], [#t.total]).map(cell => text(weight: "bold", cell))),
  table.hline(stroke: 0.8pt),
  ..rows.enumerate().map(((index, row)) => (
    [#(index + 1)], row.name, [#fmt-number(row.qty)], [#money(row.rate * (1 - row.discount / 100))], [#money(row.amount)],
  )).flatten(),
  table.hline(stroke: (paint: luma(150), thickness: 0.5pt, dash: "dotted")),
)
#v(2mm)
#bar(t.sub_total, money(subtotal))
#v(2mm)
#block(width: 100%, stroke: (paint: rgb("#3a9a5c"), thickness: 0.8pt, dash: "dashed"), inset: (x: 3mm, y: 2.4mm), radius: 1.2mm, grid(
  columns: (1fr, auto),
  row-gutter: 2.4mm,
  [#t.saving:], align(right, money(saving)),
  [#t.saving_pct:], align(right, [#fmt-number(saving-pct, digits: 2)%]),
))
#if discount != 0 or rate != none [
  #v(1.5mm)
  #align(right, grid(
    columns: (auto, auto),
    column-gutter: 6mm,
    row-gutter: 1.5mm,
    align: (right, right),
    ..if discount != 0 { ([#t.discount:], [-#money(discount)]) } else { () },
    ..for (name, percentage, amount) in tax-parts(rate, tax) { ([#name #fmt-number(percentage)%:], money(amount)) },
  ))
]
#v(2mm)
#bar(t.total, money(total))
#v(2mm)
#align(center)[
  #t.payment_method: #option-label("payment_mode", data.payment_mode) \
  #if some("transaction_id") != none [#t.transaction: #some("transaction_id") \ ]
  #if some("customer_name") != none [#t.customer: #some("customer_name") \ ]
  #v(1mm)
  #t.thanks
]
