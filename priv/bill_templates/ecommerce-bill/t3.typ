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

// E-commerce bill, design t3: a plain invoice: "INVOICE" with the number and the date, "Invoice to" and "Pay to", a boxed table of the
// products with the price, quantity and tax, the payment information and the subtotal, the signatory and the return policy.
#align(right)[
  #picture(data, "logo", 10mm)
  #text(size: 17pt, weight: "bold", upper(t.invoice))
]
#v(1mm)
#align(right)[#t.invoice_no: #strong(data.invoice_number) #h(4mm) #t.date: #strong(fmt-date(data.date))]
#v(1mm)
#line(length: 100%, stroke: 0.5pt + hairline)
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 6mm,
  [
    #head(t.invoice_to + ":") \
    #customer-lines \
    #lines(data.shipping_address)
  ],
  align(right)[
    #head(t.pay_to + ":") \
    #seller-lines
    #if some("platform_name") != none [ \ #some("platform_name")]
  ],
)
#v(3mm)
#block(width: 100%, radius: 2mm, stroke: 0.6pt + luma(190), clip: true, {
  table(
    columns: (1fr, auto, auto, ..(auto,) * tax-count, auto),
    align: (left, right, right, ..(right,) * tax-count, right),
    stroke: (x, y) => (bottom: if y == 0 { 0.6pt + luma(190) }),
    fill: (_, y) => if y == 0 { luma(246) },
    inset: 2mm,
    ..(t.description, t.price, t.qty, ..tax-heads, t.total).map(cell => text(size: 7.5pt, weight: "bold", cell)),
    ..lines-of.map(line => (line.name, money(line.rate), [#fmt-number(line.qty)], ..tax-cells(line), money(line.total))).flatten(),
  )
  line(length: 100%, stroke: 0.6pt + luma(190))
  grid(
    columns: (1fr, 1fr),
    stroke: (x, y) => if x > 0 { (left: 0.6pt + luma(190)) },
    inset: 3mm,
    [
      #text(size: 10pt, weight: "bold", t.payment_info + ":") \
      #option-label("payment_mode", data.payment_mode) \
      #t.amount: #money(grand)
    ],
    [
      #grid(
        columns: (1fr, auto),
        row-gutter: 1.5mm,
        text(size: 10pt, weight: "bold", t.subtotal), text(size: 10pt, weight: "bold", money(subtotal)),
        ..if shipping != 0 { (t.shipping, money(shipping), text(weight: "bold", t.total), text(weight: "bold", money(grand))) } else { () },
      )
    ],
  )
})
#v(4mm)
#signature-block
#v(3mm)
#policy-block
