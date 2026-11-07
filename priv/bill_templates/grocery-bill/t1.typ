// Grocery bill, design t1: a retail invoice in capitals, after the bill of a store's till: the store with its phone and FSSAI number,
// "Retail invoice", the bill number, date and time, the items with their rate, quantity and amount, the total, the tax (CGST and
// SGST in India) and the net amount, the payment, the transaction and the customer. Reads data.json (next to this file). The words
// come from text.json (`t`), the number and date formats from region.json.
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
#show: base.with(width: 117mm, margin: (x: 6mm, y: 7mm), size: 8.5pt)
#set text(weight: "bold", tracking: 0.25pt)
#set par(leading: 0.6em)

#align(center)[
  #picture(data, "logo", 10mm)
  #text(size: 12pt, upper(data.store_name))
  #if some("store_address") != none [ \ #upper(lines(some("store_address")))]
  #if some("store_phone") != none [ \ #upper(t.phone): #some("store_phone")]
  #if some("gstin") != none [ \ #upper(tax-id-label): #some("gstin")]
  #if some("fssai_number") != none [ \ FSSAI NO.: #some("fssai_number")]
  \ \ #upper(t.retail_invoice)
]
#v(1mm)
#upper(t.bill_no): #data.bill_number \
#upper(t.bill_date): #fmt-date(data.date)#if time != none [ #h(4mm) #upper(t.time): #time]
#v(1mm)
#dashed()
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  stroke: none,
  inset: (x: 1mm, y: 1.4mm),
  ..([#upper(t.particulars)], [#upper(t.rate)], [#upper(t.qty)], [#upper(t.amount)]),
  table.hline(stroke: (paint: luma(60), thickness: 0.6pt, dash: "dashed")),
  ..rows.map(row => ([#row.name], [#money(row.rate * (1 - row.discount / 100))], [#fmt-number(row.qty)], [#money(row.amount)])).flatten(),
  table.hline(stroke: (paint: luma(60), thickness: 0.6pt, dash: "dashed")),
)
#align(right, grid(
  columns: (auto, auto),
  column-gutter: 6mm,
  row-gutter: 1.8mm,
  align: (right, right),
  upper(t.total), money(subtotal),
  ..if discount != 0 { (upper(t.discount), [-#money(discount)]) } else { () },
  ..for (name, percentage, amount) in tax-parts(rate, tax) { ([#upper(name) #fmt-number(percentage)%], money(amount)) },
  text(size: 10pt, upper(t.net_amount)), text(size: 10pt, money(total)),
))
#v(1mm)
#dashed()
#v(1mm)
#align(center)[
  #upper(t.payment_method): #option-label("payment_mode", data.payment_mode) \
  #if some("transaction_id") != none [#upper(t.transaction): #some("transaction_id") \ ]
  #if some("customer_name") != none [#upper(t.customer): #some("customer_name") \ ]
  #v(1mm)
  #upper(t.thanks)
]
