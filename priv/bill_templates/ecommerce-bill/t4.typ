#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 120mm, margin: (x: 8mm, y: 8mm), size: 8.5pt)
#set par(leading: 0.55em)

#let india = region.country == "in"

// The lines: the price times the quantity, and what the tax makes of it (taken out of the price, or added to it).
#let lines-of = item-rows(data).map(row => {
  let amount = row.qty * row.rate
  let split = tax-split(amount, row.tax)
  (..row, amount: amount, taxable: split.base, tax-amount: split.tax, total: split.total)
})
#let sum(key) = sum-of(lines-of.map(line => line.at(key)))
#let subtotal = sum("total")
#let shipping = num(data, "shipping_charge")
#let grand = subtotal + shipping
#let quantity = sum("qty")

// The tax of a line as a rate over an amount; India has CGST and SGST, each with half the rate and half the tax.
#let rate-amount(rate, amount) = align(right)[#fmt-number(rate)% \ #text(size: 0.88em, fill: muted, money(amount))]
#let tax-cells(line) = if india {
  let half = calc.round(line.tax-amount / 2, digits: 2)
  (rate-amount(line.tax / 2, half), rate-amount(line.tax / 2, line.tax-amount - half))
} else { (rate-amount(line.tax, line.tax-amount),) }
#let tax-heads = if india { ("CGST", "SGST") } else { (tax-name,) }
#let tax-count = tax-heads.len()
#let head(label) = text(weight: "bold", label)
#let kv(label, value) = if value != none [#label: #value \ ]
#let day(key) = if some(key) != none { fmt-date(some(key)) }
#let order-date = day("order_date")
#let customer-lines = [
  #data.customer_name
  #if some("customer_phone") != none [ \ #t.phone: #some("customer_phone")]
]
#let seller-lines = [
  #data.seller_name
  #if some("seller_address") != none [ \ #lines(some("seller_address"))]
  #if some("seller_phone") != none [ \ #t.phone: #some("seller_phone")]
  #if some("seller_tax_id") != none [ \ #tax-id-label: #some("seller_tax_id")]
]
#let signature-block = align(right)[
  #picture(data, "signature", 12mm) \
  #if some("signatory_name") != none [#some("signatory_name") \ ]
  #text(fill: muted, t.authorised)
]
#let policy-block = if some("return_policy") != none {
  line(length: 100%, stroke: 1.2pt + luma(30))
  v(1mm)
  let parts = some("return_policy").split("\n").filter(part => part != "")
  text(size: 7pt)[
    #strong(t.return_policy + ":") #parts.first()
    #for part in parts.slice(1) [ \ #v(0.8mm) #part]
  ]
  v(1mm)
  line(length: 100%, stroke: (paint: luma(80), thickness: 0.8pt, dash: "dotted"))
}

// E-commerce bill, design t4: a tax invoice: the seller with the ship-from address and tax id, the invoice number in a dashed box,
// the order and payment, "Bill to" and "Ship to", a note about the warranty, a table of the products with the gross amount, the
// taxable value and the tax of each and a row of totals, the grand total, the signatory, thanks and the return policy.
#let billing = if some("billing_address") != none { some("billing_address") } else { data.shipping_address }
#let col-head(label) = text(size: 6.8pt, weight: "bold", label)
#align(center, text(size: 17pt, weight: "bold", t.tax_invoice))
#v(1mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 4mm,
  [
    #picture(data, "logo", 10mm)
    #text(size: 10.5pt, weight: "bold", [#t.sold_by: #data.seller_name]) \
    #if some("platform_name") != none [#some("platform_name") \ ]
    #if some("seller_address") != none [#text(style: "italic", weight: "bold", t.ship_from + ":") #lines(some("seller_address")) \ ]
    #if some("seller_phone") != none [#t.phone: #some("seller_phone") \ ]
    #if some("seller_tax_id") != none [#tax-id-label: #some("seller_tax_id")]
  ],
  block(stroke: (paint: luma(40), thickness: 1pt, dash: "dashed"), inset: 2.5mm, [
    #strong(t.invoice_number) \
    #data.invoice_number
  ]),
)
#v(1mm)
#line(length: 100%, stroke: 1.2pt + luma(30))
#v(1.5mm)
#strong(t.order_id + ":") #if some("order_number") != none { some("order_number") } else { "—" } \
#if order-date != none [#strong(t.order_date + ":") #order-date \ ]
#strong(t.invoice_date + ":") #fmt-date(data.date) \
#strong(t.payment + ":") #option-label("payment_mode", data.payment_mode)
#v(3mm)
#text(size: 10.5pt, weight: "bold", t.bill_to) \
#data.customer_name \
#lines(billing) \
#if some("customer_phone") != none [#t.phone: #some("customer_phone")]
#v(3mm)
#text(size: 10.5pt, weight: "bold", t.ship_to) \
#data.customer_name \
#lines(data.shipping_address) \
#if some("customer_phone") != none [#t.phone: #some("customer_phone")]
#v(3mm)
#align(center, text(size: 7.5pt, style: "italic", "*" + t.keep_invoice))
#v(2mm)
#strong(t.total_items + ": " + str(lines-of.len()))
#v(1mm)
#table(
  columns: (1fr, auto, auto, auto, ..(auto,) * tax-count, auto),
  align: (left, right, right, right, ..(right,) * tax-count, right),
  stroke: (x, y) => (bottom: 0.5pt + luma(190)),
  inset: (x: 0.9mm, y: 1.8mm),
  ..(t.title, t.qty, t.gross_amount, t.taxable_value, ..tax-heads, t.total).map(col-head),
  ..lines-of.map(line => (line.name, [#fmt-number(line.qty)], money(line.amount), money(line.taxable), ..if india {
    let half = calc.round(line.tax-amount / 2, digits: 2)
    (money(half), money(line.tax-amount - half))
  } else { (money(line.tax-amount),) }, money(line.total)).map(cell => text(size: 6.6pt, cell))).flatten(),
  table.hline(stroke: 1pt + luma(40)),
  ..(strong(t.total), strong(fmt-number(quantity)), strong(money(sum("amount"))), strong(money(sum("taxable"))), ..if india {
    let half = calc.round(sum("tax-amount") / 2, digits: 2)
    (strong(money(half)), strong(money(sum("tax-amount") - half)))
  } else { (strong(money(sum("tax-amount"))),) }, strong(money(subtotal))).map(cell => text(size: 6.6pt, cell)),
  table.hline(stroke: 1pt + luma(40)),
)
#v(1mm)
#if shipping != 0 [
  #grid(columns: (1fr, auto), t.shipping, money(shipping))
  #v(1mm)
]
#grid(
  columns: (1fr, auto),
  text(size: 12pt, weight: "bold", t.grand_total), text(size: 12pt, weight: "bold", money(grand)),
)
#v(4mm)
#signature-block
#v(3mm)
#line(length: 100%, stroke: 1.2pt + luma(30))
#v(2mm)
#align(right)[
  #text(size: 10pt, t.thank_you) \
  #text(size: 6.5pt, t.for_shopping)
]
#v(2mm)
#policy-block
