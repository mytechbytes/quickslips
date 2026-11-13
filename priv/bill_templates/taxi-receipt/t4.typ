// Cab bill, design t4: a plain receipt, the total first and the facts of the trip below.
#import "_shared/helpers.typ": *
#let data = json("data.json")
// The receipt and the invoice number, optional: only those given are printed.
#let numbers = ((t.receipt_number, opt(data, "receipt_number")), (t.invoice_number, opt(data, "invoice_number"))).filter(pair => pair.at(1) != none)
#show: base.with(width: 117mm, margin: (x: 8mm, y: 8mm), size: 9.5pt)

#let toll = num(data, "toll")
#let airport = num(data, "airport_charge")
#let extras = toll + airport
#let subtotal = data.base_fare + extras
#let rate = opt(data, "tax_percent")
#let split = if rate != none { tax-split(subtotal, rate) } else { (base: subtotal, tax: 0, total: subtotal) }
#let total = split.total
#let vehicle = (opt(data, "vehicle_model"), opt(data, "vehicle_number")).filter(part => part != none)

#let row(label, amount, bold: false) = grid(
  columns: (1fr, auto),
  column-gutter: 4mm,
  if bold { strong(label) } else { label },
  align(right, if bold { strong(amount) } else { amount }),
)
// A small grey label on the left, the value on the right; nothing for an empty field.
#let fact(label, value) = if value != none {
  block(below: 2mm, grid(columns: (auto, 1fr), column-gutter: 4mm, align: horizon, text(size: 8pt, fill: muted, label), align(right, value)))
}

#grid(
  columns: (1fr, auto),
  align: (left + top, right + top),
  [#picture(data, "logo", 9mm) \ #text(size: 11pt, weight: "bold", data.operator_name)],
  align(right)[#text(size: 8.5pt, fill: muted)[#t.total: #money(total) \ #fmt-date(data.date)]],
)
#v(4mm)
#text(size: 13pt, weight: "bold", t.thanks_riding)#if opt(data, "passenger_name") != none [ #text(size: 13pt, weight: "bold", opt(data, "passenger_name"))] \
#text(size: 8.5pt, fill: muted, t.enjoyed)
#v(2mm)
#rule()
#v(2mm)
#grid(
  columns: (1fr, auto),
  text(size: 15pt, weight: "bold", t.total), text(size: 20pt, weight: "bold", money(total)),
)
#v(2mm)
#rule()
#v(2mm)
#row(t.trip_fare, money(data.base_fare), bold: true)
#v(1.5mm)
#row(t.subtotal, money(data.base_fare))
#v(1.5mm)
#row(t.fees, money(extras))
#v(3mm)
#row(t.before_tax, money(split.base))
#if rate != none { v(1.5mm); row([#tax-name (#fmt-number(rate)%)], money(split.tax)) }
#v(2mm)
#rule()
#v(3mm)

#for (label, value) in numbers { fact(label, strong(value)) }
#fact(t.driver, opt(data, "driver_name"))
#fact(t.pickup, data.pickup)
#fact(t.drop, data.drop)
#fact(t.cab_no, opt(data, "vehicle_number"))
#fact(t.vehicle, opt(data, "vehicle_model"))
#fact(t.distance, [#fmt-number(data.distance_km) #t.unit])
#fact(t.time, if opt(data, "pickup_time") != none or opt(data, "drop_time") != none {
  (opt(data, "pickup_time"), opt(data, "drop_time")).map(value => if value != none { fmt-time(value) } else { "–" }).join(" – ")
})
#fact(t.payment, option-label("payment_mode", data.payment_mode))
#fact(t.paid, strong(money(total)))
#if opt(data, "operator_address") != none or opt(data, "seller_tax_id") != none [
  #v(2mm)
  #text(size: 7.5pt, fill: muted)[
    #if opt(data, "operator_address") != none [#lines(opt(data, "operator_address"))]
    #if opt(data, "seller_tax_id") != none [ \ #tax-id-label: #opt(data, "seller_tax_id")]
  ]
]
