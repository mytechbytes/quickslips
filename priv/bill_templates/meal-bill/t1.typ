// Meal bill, design t1: the tax invoice of a food-delivery order, written for a restaurant: the brand on top, who it is on
// behalf of, the invoice, the customer and the delivery, a table with the tax on each line (CGST and SGST in India), the
// total in words, and the legal details of the platform with a signatory. Reads data.json (next to this file). The words
// come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 170mm, margin: (x: 10mm, y: 10mm), size: 8.5pt)
#set par(leading: 0.6em)

#let some(key) = opt(data, key)
#let india = region.country == "in"
#let included = tax-mode == "included"
#let kv(label, value) = if value != none [*#label:* #value]
#let stack-of(..rows) = rows.pos().filter(row => row != none).join(linebreak())

// The lines: what is billed, the discount, the net value, the tax and the total of each line (the tax is added to the net
// value, or is already in it).
#let lines-of = item-rows(data, quantity: false).map(row => {
  let net = row.amount
  let split = tax-split(net, row.tax)
  let tax = calc.round(split.tax, digits: 2)
  let first = calc.round(tax / 2, digits: 2)
  (
    name: row.name, gross: row.rate, discount: row.rate - net, net: net, rate: row.tax,
    tax: tax, cgst: first, sgst: tax - first, total: if included { net } else { net + tax },
  )
})
#let sum(key) = sum-of(lines-of.map(row => row.at(key)))
#let total = sum("total")

#grid(
  columns: (1fr, auto),
  align: (left + horizon, right + horizon),
  [#picture(data, "logo", 10mm) #if some("brand_name") != none { text(size: 20pt, weight: "bold", some("brand_name")) }],
  align(center)[#text(size: 14pt, weight: "bold", t.tax_invoice) \ #text(size: 8pt, fill: muted, upper(t.original))],
)
#v(3mm)
#text(weight: "bold", t.on_behalf) \
#stack-of(
  strong(if some("legal_name") != none { some("legal_name") } else { data.restaurant_name }),
  if some("legal_name") != none { data.restaurant_name },
  if some("restaurant_address") != none { text(fill: muted, lines(some("restaurant_address"))) },
  kv(t.restaurant + " " + tax-id-label, some("restaurant_gstin")),
  kv(t.restaurant + " FSSAI", some("restaurant_fssai")),
)
#v(3mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  stack-of(kv(t.invoice_no, data.invoice_number), kv(t.order_id, some("order_id"))),
  stack-of(kv(t.invoice_date, fmt-date(data.date))),
)
#v(2mm)
#stack-of(
  kv(t.customer, data.customer_name),
  kv(t.delivery_address, if some("delivery_address") != none { lines(some("delivery_address")) }),
  kv(t.place, some("place_of_supply")),
  kv(t.hsn, some("hsn_code")),
  kv(t.service, some("service_description")),
)
#v(3mm)

// The head of the table: with CGST and SGST in India, else with one tax.
#let money-head(label) = [#label (#region.currency.symbol)]
#let tax-heads = if india {
  ([CGST \ (#t.rate)], money-head("CGST"), [SGST \ (#t.rate)], money-head("SGST"))
} else {
  ([#t.tax \ (#t.rate)], money-head(t.tax))
}
#let tax-cells(row) = if india {
  ([#fmt-number(row.rate / 2)%], money(row.cgst), [#fmt-number(row.rate / 2)%], money(row.sgst))
} else {
  ([#fmt-number(row.rate)%], money(row.tax))
}
#let tax-sums = if india { (none, money(sum("cgst")), none, money(sum("sgst"))) } else { (none, money(sum("tax"))) }
#table(
  columns: (1fr, auto, auto, auto, ..(auto,) * tax-heads.len(), auto),
  align: (left, right, right, right, ..(right,) * tax-heads.len(), right),
  stroke: 0.6pt,
  inset: (x: 1.6mm, y: 1.6mm),
  table.header(..([#t.particulars], [#t.gross], [#t.discount], [#t.net], ..tax-heads, [#t.total]).map(cell => text(size: 7.5pt, weight: "bold", cell))),
  ..lines-of.map(row => (
    row.name, money(row.gross), money(row.discount), money(row.net), ..tax-cells(row), money(row.total),
  )).flatten(),
  table.cell(align: right, strong(t.total)), strong(money(sum("gross"))), strong(money(sum("discount"))), strong(money(sum("net"))),
  ..tax-sums.map(cell => if cell == none { [] } else { strong(cell) }),
  strong(money(total)),
)
#v(3mm)
#let words = amount-words-line(total)
#if words != none { align(left, words) }
#v(1mm)
#stack-of(
  if india and some("reverse_charge") != none { [#t.reverse: #option-label("reverse_charge", some("reverse_charge"))] },
  kv(t.payment_note, if some("payment_note") != none { lines(some("payment_note")) }),
)

#v(4mm)
#line(length: 100%, stroke: 0.5pt + luma(190))
#v(2mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 8mm,
  {
    text(weight: "bold", upper(t.for))
    linebreak()
    stack-of(
      if some("platform_company") != none { lines(some("platform_company")) },
      if some("brand_name") != none and some("platform_company") == none { some("brand_name") },
      kv("PAN", some("platform_pan")),
      kv("CIN", some("platform_cin")),
      kv(tax-id-label, some("platform_tax_id")),
      kv("FSSAI", some("platform_fssai")),
    )
  },
  align(bottom, signature-block(data, t.authorised, name: some("signatory_name"))),
)
