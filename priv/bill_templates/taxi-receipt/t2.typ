// Cab bill, design t2: the summary of a ride and, below it, the invoice of the driver with the tax split in two lines.
#import "_shared/helpers.typ": *
#let data = json("data.json")
// The receipt and the invoice number, optional: only those given are printed.
#let numbers = ((t.receipt_number, opt(data, "receipt_number")), (t.invoice_number, opt(data, "invoice_number"))).filter(pair => pair.at(1) != none)
#show: base.with(width: 117mm, margin: (x: 6mm, y: 6mm), size: 9pt)

#let toll = num(data, "toll")
#let airport = num(data, "airport_charge")
#let subtotal = data.base_fare + toll + airport
#let rate = opt(data, "tax_percent")
#let split = if rate != none { tax-split(subtotal, rate) } else { (base: subtotal, tax: 0, total: subtotal) }
#let total = split.total
#let vehicle = (opt(data, "vehicle_model"), opt(data, "vehicle_number")).filter(part => part != none)
#let grey = luma(232)
#let card(body) = block(width: 100%, stroke: 0.6pt + luma(190), inset: 4.5mm, body)
#let row(label, amount) = grid(columns: (1fr, auto), column-gutter: 3mm, label, align(right, amount))

// The pickup and the drop, joined by a dotted line, each with its time.
#let route() = {
  let clock(value) = if value != none { strong(fmt-time(value)) }
  grid(
    columns: (11mm, 4mm, 1fr),
    column-gutter: 1.2mm,
    align: (right + top, center + top, left + top),
    clock(opt(data, "pickup_time")), box(inset: (top: 0.6mm), circle(radius: 1.2mm, fill: rgb("#2e9e5b"), stroke: none)), text(size: 8pt, data.pickup),
    [], align(center, line(angle: 90deg, length: 6mm, stroke: (paint: luma(150), thickness: 0.8pt, dash: "dotted"))), [],
    clock(opt(data, "drop_time")), box(inset: (top: 0.6mm), circle(radius: 1.2mm, fill: rgb("#d64545"), stroke: none)), text(size: 8pt, data.drop),
  )
}

// The tax of the invoice: half and half where India splits it (CGST and SGST), else one line with the name of the tax.
#let tax-rows() = {
  if rate == none { return () }
  if region.country == "in" {
    let half = rate / 2
    let first = calc.round(split.tax / 2, digits: 2)
    (("CGST", half, first), ("SGST", half, split.tax - first))
  } else {
    ((tax-name, rate, split.tax),)
  }
}

#card[
  #grid(
    columns: (1fr, auto),
    text(size: 8pt, fill: muted, fmt-date(data.date)), picture(data, "logo", 9mm),
  )
  #align(center)[
    #text(size: 22pt, weight: "bold", money(total)) \
    #text(size: 9.5pt, t.thanks_travel)#if opt(data, "passenger_name") != none [ #strong(opt(data, "passenger_name"))]
  ]
  #v(1mm)
  #rule()
  #v(2mm)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 5mm,
    {
      text(size: 10.5pt, weight: "bold", t.ride_details)
      v(2mm)
      route()
      v(2mm)
      text(size: 8.5pt, weight: "bold", t.rode_with)
      linebreak()
      text(size: 8pt, fill: muted)[
        #if opt(data, "driver_name") != none [#opt(data, "driver_name") \ ]
        #if vehicle.len() > 0 [#vehicle.join(" · ") \ ]
        #fmt-number(data.distance_km) #t.unit
      ]
    },
    {
      text(size: 10.5pt, weight: "bold", t.bill_details)
      v(2mm)
      block(width: 100%, fill: grey, inset: 2mm, row(t.trip_fare, money(data.base_fare)))
      if toll != 0 { block(width: 100%, inset: 2mm, row(t.toll, money(toll))) }
      if airport != 0 { block(width: 100%, fill: grey, inset: 2mm, row(t.airport, money(airport))) }
      block(width: 100%, inset: 2mm, row(strong(t.total_bill), strong(money(total))))
      if rate != none { text(size: 7.5pt, fill: muted, t.includes_taxes.replace("{amount}", money(split.tax))) }
      v(1.5mm)
      text(size: 7pt, fill: muted, t.promise)
    },
  )
  #v(2mm)
  #align(center, text(size: 10.5pt, weight: "bold", t.payment))
  #rule()
  #v(1mm)
  #row([#t.paid_by #option-label("payment_mode", data.payment_mode)], money(total))
  #rule()
  #v(2mm)
  #block(width: 100%, fill: grey, inset: 3mm)[
    #align(center, text(size: 8pt)[#t.complaint #if opt(data, "operator_address") != none [ \ #lines(opt(data, "operator_address"))]])
  ]
]

// In the browser preview the invoice is a page of its own, below the summary of the ride.
#if preview { pagebreak() } else { v(4mm) }

#card[
  #align(center)[
    #text(size: 8.5pt, fill: muted, t.original) \
    #text(size: 14pt, weight: "bold", t.driver_invoice)
  ]
  #v(1mm)
  #align(right, text(size: 8.5pt, t.service))
  #if opt(data, "seller_tax_id") != none { align(right, text(size: 8pt, fill: muted)[#tax-id-label: #opt(data, "seller_tax_id")]) }
  #v(1mm)
  #rule()
  #v(1.5mm)
  #row(numbers.map(((label, value)) => [#text(fill: muted, label) #strong(value)]).join(linebreak()), [#text(fill: muted, t.invoice_date) #strong(fmt-date(data.date))])
  #v(1.5mm)
  #rule()
  #v(1.5mm)
  #row([#text(fill: muted, t.customer) #if opt(data, "passenger_name") != none [#strong(opt(data, "passenger_name"))]], [#text(fill: muted, t.mobile) #if opt(data, "customer_phone") != none [#strong(opt(data, "customer_phone"))]])
  #v(1.5mm)
  #rule()
  #v(1.5mm)
  #text(fill: muted, t.pickup_address) #data.pickup
  #v(1.5mm)
  #rule()
  #v(1.5mm)
  #row(strong(t.description), strong[#t.amount (#region.currency.symbol)])
  #v(1.5mm)
  #line(length: 100%, stroke: 1pt)
  #v(1.5mm)
  #row(strong(t.ride_fee), money(data.base_fare))
  #if toll != 0 { v(2mm); row(strong(t.toll), money(toll)) }
  #if airport != 0 { v(2mm); row(strong(t.airport), money(airport)) }
  #for (name, percentage, amount) in tax-rows() {
    v(2mm)
    row([#strong(name) \ #text(fill: muted, size: 8pt)[#fmt-number(percentage) %]], money(amount))
  }
  #v(2mm)
  #line(length: 100%, stroke: (paint: luma(120), thickness: 0.6pt, dash: "dashed"))
  #v(1.5mm)
  #row(strong(t.subtotal), money(split.base))
  #v(1.5mm)
  #line(length: 100%, stroke: 1pt)
  #v(1.5mm)
  #row(strong(t.total), text(size: 12pt, weight: "bold", money(total)))
  #let words = amount-words-line(total)
  #if words != none [#v(1mm) #words]
  #v(1.5mm)
  #rule()
  #v(1.5mm)
  #text(size: 7.5pt, t.note)
]
