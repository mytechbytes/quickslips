// Laundry bill, design t2: a cash or credit invoice of a dry-cleaning and laundry service, 120 mm wide, in blue: the laundry in a round badge,
// the invoice bar, the customer in a frame, the number, the date and the delivery date, a ruled table (quantity, description, rate, amount
// in whole units and small change), the notes, the total, the amount in words and the terms. The tax is added to the sum, or is part of the
// prices where the country says so. Reads data.json (next to this file). The words come from text.json (`t`), the number and date formats
// from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 120mm, margin: (x: 8mm, y: 8mm), size: 8.5pt)
#set par(leading: 0.55em)
#set block(spacing: 0pt)

#let rows = item-rows(data)
#let subtotal = sum-of(rows.map(row => row.amount))
#let rate = some("tax_percent")
#let tax = if rate != none { calc.round(tax-split(subtotal, rate).tax, digits: 2) } else { 0 }
#let total = if tax-mode == "included" { subtotal } else { subtotal + tax }
#let terms-list = if some("terms") != none { some("terms").split("\n").filter(line => line != "") } else { () }
#let blue = rgb("#2447a0")
#let decimals = region.currency.decimals
#let whole(amount) = str(calc.floor(calc.round(amount * calc.pow(10, decimals)) / calc.pow(10, decimals)))
#let minor(amount) = {
  let scale = int(calc.pow(10, decimals))
  let units = int(calc.round(amount * scale))
  let cents = calc.rem(units, scale)
  let digits = str(cents)
  "0" * (decimals - digits.len()) + digits
}
#let blank-rows = calc.max(0, 9 - rows.len())

#grid(
  columns: (auto, 1fr),
  column-gutter: 4mm,
  box(width: 17mm, height: 17mm, stroke: (paint: blue, thickness: 1.2pt, dash: "dashed"), radius: 50%, align(center + horizon, {
    let logo = picture(data, "logo", 11mm)
    if logo != none { logo } else { text(size: 16pt, fill: blue, upper(data.laundry_name.first())) }
  })),
  align(horizon)[
    #text(size: 12pt, weight: "bold", fill: blue, upper(t.service_title)) \
    #text(size: 7.5pt, weight: "bold", [#data.laundry_name#if some("laundry_address") != none [ · #some("laundry_address").replace("\n", ", ")]])
  ],
)
#v(3mm)
#block(width: 100%, fill: blue, radius: 1mm, inset: 2mm, align(center, text(size: 8pt, fill: white, tracking: 1pt, upper(t.cash_credit_invoice))))
#v(2.5mm)
#block(width: 100%, stroke: 1pt + blue, radius: 2mm, inset: 3mm, [
  #strong(t.name + ":") #data.customer_name \
  #v(1mm)
  #strong(t.address + ":") #if some("customer_address") != none { lines(some("customer_address")) }
])
#v(2.5mm)
#grid(
  columns: (1fr, 1fr),
  row-gutter: 1.5mm,
  [#strong(t.no + ":") #data.invoice_number], [],
  [#strong(t.date + ":") #fmt-date(data.date)], [],
  [#strong(t.delivery + ":") #fmt-date(data.delivery_date)], [],
)
#v(2.5mm)
#block(width: 100%, stroke: 1pt + blue, clip: true, {
  table(
    columns: (auto, 1fr, auto, auto, ..if decimals > 0 { (auto,) } else { () }),
    align: (center, center, right, right, ..if decimals > 0 { (right,) } else { () }),
    stroke: (x, y) => (bottom: 0.4pt + luma(210), left: if x > 0 { 0.4pt + luma(210) }),
    fill: (_, y) => if y == 0 { rgb("#e8eefb") },
    inset: (x: 1.8mm, y: 1.6mm),
    ..(t.qty, t.description, t.rate, region.currency.symbol, ..if decimals > 0 { (if minor-head != none { minor-head } else { t.minor },) } else { () }).map(head => text(weight: "bold", head)),
    ..rows.map(row => ([#fmt-number(row.qty)], row.name, money(row.rate), whole(row.amount), ..if decimals > 0 { (minor(row.amount),) } else { () })).flatten(),
    ..range(blank-rows).map(_ => ([ ], [ ], [ ], [ ], ..if decimals > 0 { ([ ],) } else { () })).flatten(),
  )
  line(length: 100%, stroke: 1pt + blue)
  grid(
    columns: (1fr, auto),
    inset: 2.5mm,
    text(size: 7.5pt)[#t.good_condition \ #t.no_refund],
    align(right)[
      #if rate != none [#text(size: 7.5pt, [#t.tax_amount (#fmt-number(rate)%): #money(tax)]) \ ]
      #text(size: 9pt, [#t.total]) #h(3mm) #text(size: 11pt, weight: "bold", money(total))
    ],
  )
})
#v(3mm)
#text(weight: "bold", size: 8pt, [#t.amount_in_words])
#v(1mm)
#align(center, text(size: 8.5pt, if amount-words(total) != none { amount-words(total) } else { [] }))
#v(1.5mm)
#line(length: 100%, stroke: 0.5pt + blue)
#v(3mm)
#if terms-list.len() > 0 {
  block(width: 100%, stroke: 0.6pt + luma(190), radius: 2mm, fill: luma(250), inset: 3mm, {
    text(size: 8pt, weight: "bold", t.terms)
    v(1.5mm)
    text(size: 6.8pt, terms-list.map(line => [#line]).join(v(1.2mm)))
  })
}
