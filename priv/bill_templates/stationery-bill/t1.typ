// Stationery bill, design t1: a small shop receipt, 120 mm wide: the receipt number and the date on the right, the shop and the customer
// in boxes, a ruled table of the items (rate, quantity, amount), the remarks on the left and the subtotal, the tax (CGST and SGST in
// India) and the total on the right, the payment method and a line to save paper. The tax is added to the subtotal, or is part of
// the prices where the country says so. Reads data.json (next to this file). The words come from text.json (`t`), the number and
// date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 120mm, margin: (x: 8mm, y: 7mm), size: 8.5pt)
#set par(leading: 0.55em)

#let rows = item-rows(data)
#let subtotal = sum-of(rows.map(row => row.amount))
#let rate = some("tax_percent")
#let tax = if rate != none { calc.round(tax-split(subtotal, rate).tax, digits: 2) } else { 0 }
#let total = if tax-mode == "included" { subtotal } else { subtotal + tax }
#let line-color = luma(70)
#let box-frame = 0.6pt + line-color

#line(length: 100%, stroke: 0.6pt + hairline)
#v(1.5mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 4mm,
  [
    #picture(data, "logo", 11mm)
    #text(size: 11pt, weight: "bold", data.shop_name) \
    #lines(data.shop_address)
    #if some("seller_tax_id") != none [ \ #tax-id-label: #some("seller_tax_id")]
  ],
  align(right)[
    #text(size: 11pt, weight: "bold", [#t.receipt_no: #data.invoice_number]) \
    #text(size: 8pt, fill: muted, [#t.date: #fmt-date(data.date)])
  ],
)
#v(2.5mm)
#grid(
  columns: (1fr, 1.5fr),
  column-gutter: 4mm,
  block(width: 100%, stroke: box-frame, inset: 2mm)[
    #text(size: 6.8pt, fill: muted, upper(t.billed_to)) \
    #strong(data.customer_name)
  ],
  block(width: 100%, stroke: box-frame, inset: 2mm)[
    #text(size: 6.8pt, fill: muted, upper(t.address)) \
    #lines(data.customer_address)
  ],
)
#v(3mm)
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  stroke: box-frame,
  inset: (x: 2mm, y: 1.8mm),
  ..(t.item, t.rate, t.quantity, t.amount).map(head => text(weight: "bold", head)),
  ..rows.map(row => (row.name, money(row.rate), [#fmt-number(row.qty)], money(row.amount))).flatten(),
)
#v(3mm)
#grid(
  columns: (1fr, 52mm),
  column-gutter: 5mm,
  {
    if some("remarks") != none {
      text(size: 7.5pt, style: "italic", t.remarks + ":")
      linebreak()
      text(size: 7.5pt, lines(some("remarks")))
    }
  },
  table(
    columns: (1fr, auto),
    align: (left, right),
    stroke: box-frame,
    inset: (x: 2mm, y: 1.6mm),
    t.subtotal, money(subtotal),
    ..for (name, percentage, amount) in tax-parts(rate, tax) { ([#name: #fmt-number(percentage)%], money(amount)) },
    table.cell(fill: luma(240), strong(t.total_amount)), table.cell(fill: luma(240), strong(money(total))),
  ),
)
#v(2mm)
#align(right, text(size: 7.5pt, fill: muted, [#t.payment_method: #option-label("payment_mode", data.payment_mode)]))
#v(2mm)
#line(length: 100%, stroke: 0.6pt + hairline)
#v(1.5mm)
#align(center, text(size: 7pt, fill: muted, upper(t.save_paper)))
