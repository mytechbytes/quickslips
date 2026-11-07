// General bill, design t1: a simple bill for any sale, 120 mm wide: the invoice date and number, the seller and the customer, a table of
// the items with the price, the quantity and the tax of each (CGST and SGST in India, one tax elsewhere) and the subtotal, and a row
// with the payment information, the due date and the total amount, and a thank-you. The price includes the tax where the country says
// so. Reads data.json (next to this file). The words come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 120mm, margin: (x: 8mm, y: 8mm), size: 8pt)
#set par(leading: 0.55em)
#set block(spacing: 0pt)

#let india = region.country == "in"
#let accent = rgb("#d9534f")
#let lines-of = item-rows(data).map(row => {
  let amount = row.qty * row.rate
  let split = tax-split(amount, row.tax)
  (..row, amount: amount, taxable: split.base, tax-amount: split.tax, total: split.total)
})
#let total = sum-of(lines-of.map(line => line.total))
#let half(amount) = calc.round(amount / 2, digits: 2)
#let rate-amount(rate, amount) = align(right)[#fmt-number(rate)% \ #text(size: 0.9em, fill: muted, money(amount))]
#let tax-heads = if india { ("CGST", "SGST") } else { (tax-name,) }
#let tax-cells(line) = if india {
  (rate-amount(line.tax / 2, half(line.tax-amount)), rate-amount(line.tax / 2, line.tax-amount - half(line.tax-amount)))
} else { (rate-amount(line.tax, line.tax-amount),) }
#let small-head(label) = text(size: 6.4pt, fill: muted, upper(label))

#align(right)[
  #picture(data, "logo", 10mm)
  #text(fill: muted, [#t.invoice_date:]) #strong(fmt-date(data.date)) \
  #text(fill: muted, [#t.invoice_no:]) #strong(data.invoice_number)
]
#v(2mm)
#line(length: 100%, stroke: 0.6pt + hairline)
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 6mm,
  [
    #small-head(t.sold_by) \
    #strong(data.shop_name) \
    #lines(data.shop_address)
    #if some("seller_tax_id") != none [ \ #tax-id-label: #some("seller_tax_id")]
  ],
  [
    #small-head(t.billed_to) \
    #strong(data.customer_name) · #data.customer_location \
    #lines(data.shipping_address)
  ],
)
#v(3mm)
#line(length: 100%, stroke: 0.6pt + hairline)
#table(
  columns: (1fr, auto, auto, ..(auto,) * tax-heads.len(), auto),
  align: (left, center, right, ..(right,) * tax-heads.len(), right),
  stroke: (x, y) => (bottom: if y == 0 { 0.6pt + hairline }),
  inset: (x: 1.4mm, y: 2.2mm),
  ..(t.description, t.qty, t.price, ..tax-heads, t.subtotal).map(small-head),
  ..lines-of.map(line => (line.name, [#fmt-number(line.qty)], money(line.rate), ..tax-cells(line), strong(money(line.total)))).flatten(),
)
#line(length: 100%, stroke: 0.6pt + hairline)
#v(2mm)
#grid(
  columns: (1.2fr, 1fr, 1fr),
  column-gutter: 4mm,
  row-gutter: 1.5mm,
  small-head(t.payment_info), small-head(t.due_by), small-head(t.total_amount),
  [
    #if some("order_number") != none [#text(size: 7pt)[#t.order_no: #strong(some("order_number"))] \ ]
    #text(size: 7pt)[#t.payment_method: #strong(option-label("payment_mode", data.payment_mode))]
  ],
  text(size: 11pt, fmt-date(data.date)),
  text(size: 11pt, weight: "bold", fill: accent, money(total)),
)
#v(2mm)
#line(length: 100%, stroke: 0.6pt + hairline)
#v(8mm)
#align(right, text(size: 9pt, t.thanks))
