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

// E-commerce bill, design t2: the order confirmation: "Your order is confirmed!", the customer's greeting, the order, the shipping
// address and the seller in small labelled boxes, a receipt summary with the lines of each product, the subtotal and the total,
// a note about the shipping email, thanks and help, the signatory and the return policy.
#let accent = rgb("#2e7d32")
#let slot(label, value) = if value != none [
  #text(size: 7pt, fill: muted, label) \
  #text(size: 9pt, value)
]
#text(size: 15pt, weight: "bold", t.order_confirmed) \
#v(1mm)
#text(size: 10pt, [#t.hello #data.customer_name,])
#v(1mm)
#line(length: 100%, stroke: 0.5pt + hairline)
#v(1.5mm)
#grid(
  columns: (1fr, 1fr, 1fr),
  row-gutter: 3mm,
  column-gutter: 3mm,
  slot(t.order_date, if order-date != none { order-date } else { fmt-date(data.date) }),
  slot(t.order_number, some("order_number")),
  slot(t.payment_method, option-label("payment_mode", data.payment_mode)),
  slot(t.mobile, some("customer_phone")),
  slot(tax-id-label, some("seller_tax_id")),
  [],
)
#v(2mm)
#slot(t.shipping_address, lines(data.shipping_address))
#v(2mm)
#slot(t.sold_by, [
  #data.seller_name#if some("platform_name") != none [ (#some("platform_name"))]
  #if some("seller_address") != none [ \ #lines(some("seller_address"))]
  #if some("seller_phone") != none [ \ #t.phone: #some("seller_phone")]
])
#v(1.5mm)
#line(length: 100%, stroke: 0.5pt + hairline)
#v(1.5mm)
#text(size: 11pt, weight: "bold", t.receipt_summary)
#v(1.5mm)
#for line in lines-of [
  #grid(
    columns: (1fr, auto),
    column-gutter: 4mm,
    [
      #strong(line.name) \
      #text(size: 7.5pt)[
        #t.qty: #fmt-number(line.qty) #h(3mm) #t.rate: #money(line.rate) \
        #for (name, rate, amount) in tax-parts(line.tax, line.tax-amount) [#name: #fmt-number(rate)% #h(2mm) #name #t.amt: #money(amount) \ ]
      ]
    ],
    align(bottom, text(size: 10pt, weight: "bold", money(line.total))),
  )
  #v(1.5mm)
]
#line(length: 100%, stroke: 0.5pt + hairline)
#v(1.5mm)
#grid(
  columns: (1fr, auto),
  row-gutter: 2.5mm,
  align(center, text(size: 10pt, t.subtotal)), text(size: 10pt, weight: "bold", money(subtotal)),
  ..if shipping != 0 { (align(center, text(size: 10pt, t.shipping)), text(size: 10pt, weight: "bold", money(shipping))) } else { () },
  align(center, text(size: 10pt, weight: "bold", t.total)), text(size: 10pt, weight: "bold", fill: accent, money(grand)),
)
#v(1.5mm)
#line(length: 100%, stroke: 0.5pt + hairline)
#v(1mm)
#text(size: 7.5pt, fill: muted, t.confirmation_note)
#v(1mm)
#line(length: 100%, stroke: 0.5pt + hairline)
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  text(size: 10pt, weight: "bold", t.thanks_shopping),
  align(right)[
    #text(size: 10pt, weight: "bold", t.need_help)
    #if some("platform_website") != none [ \ #text(size: 7.5pt, some("platform_website"))]
    #if some("seller_phone") != none [ \ #text(size: 7.5pt, some("seller_phone"))]
  ],
)
#v(3mm)
#signature-block
#v(3mm)
#policy-block
