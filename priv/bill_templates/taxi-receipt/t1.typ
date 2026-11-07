// Cab bill, design t1: the receipt of a ride, a narrow page with the fare broken down and the route with its times.
// Reads data.json (next to this file). The words come from text.json (`t`), the number and date formats from
// region.json; the helpers read both.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 120mm, margin: (x: 9mm, y: 9mm), size: 9.5pt)

#let toll = num(data, "toll")
#let airport = num(data, "airport_charge")
#let subtotal = data.base_fare + toll + airport
#let rate = opt(data, "tax_percent")
#let split = if rate != none { tax-split(subtotal, rate) } else { (base: subtotal, tax: 0, total: subtotal) }
#let total = split.total
#let vehicle = (opt(data, "vehicle_model"), opt(data, "vehicle_number")).filter(part => part != none)

// A label on the left and an amount on the right.
#let line-item(label, amount, strong-row: false) = grid(
  columns: (1fr, auto),
  column-gutter: 4mm,
  if strong-row { strong(label) } else { text(fill: muted, label) },
  align(right, if strong-row { strong(money(amount)) } else { money(amount) }),
)
#let thick = line(length: 100%, stroke: 1.4pt)

// The pickup and the drop, joined by a dotted line, each with its time.
#let route() = {
  let clock(value) = if value != none { strong(fmt-time(value)) }
  grid(
    columns: (12mm, 4mm, 1fr),
    column-gutter: 1.5mm,
    align: (right + top, center + top, left + top),
    clock(opt(data, "pickup_time")), box(inset: (top: 0.7mm), circle(radius: 1.3mm, fill: rgb("#2e9e5b"), stroke: none)), data.pickup,
    [], align(center, line(angle: 90deg, length: 7mm, stroke: (paint: luma(150), thickness: 0.8pt, dash: "dotted"))), [],
    clock(opt(data, "drop_time")), box(inset: (top: 0.7mm), circle(radius: 1.3mm, fill: rgb("#d64545"), stroke: none)), data.drop,
  )
}

#grid(
  columns: (1fr, auto),
  align: (left + horizon, right + horizon),
  text(size: 8.5pt, weight: "bold", fill: muted, fmt-date(data.date)), picture(data, "logo", 10mm),
)
#v(1mm)
#rule()
#v(3mm)
#text(size: 14pt, weight: "bold", t.receipt_title) \
#text(fill: muted, weight: "bold", size: 8.5pt, t.enjoyed)
#v(4mm)

#grid(
  columns: (1fr, auto),
  text(size: 11.5pt, weight: "bold", t.trip_total), text(size: 12pt, weight: "bold", money(total)),
)
#v(1mm)
#thick
#v(2mm)
#line-item(t.trip_fare, data.base_fare)
#v(1.5mm)
#rule()
#v(1.5mm)
#line-item(t.subtotal, subtotal, strong-row: true)
#if toll != 0 { v(1.5mm); line-item(t.toll, toll) }
#if airport != 0 { v(1.5mm); line-item(t.airport, airport) }
#v(2mm)
#rule()
#v(4mm)

#text(size: 11.5pt, weight: "bold", t.payments)
#v(1.5mm)
#line-item(option-label("payment_mode", data.payment_mode), total)
#if rate != none [
  #v(2mm)
  #text(size: 8pt, fill: muted, t.includes.replace("{total}", money(total)).replace("{tax}", tax-name).replace("{amount}", money(split.tax)))
]
#v(2mm)
#rule()
#v(3mm)

#text(size: 11.5pt, weight: "bold", t.rode_with)
#v(1mm)
#text(size: 8.5pt, fill: muted)[
  #if opt(data, "driver_name") != none [#opt(data, "driver_name") \ ]
  #if opt(data, "vehicle_model") != none [#opt(data, "vehicle_model") \ ]
  #if opt(data, "vehicle_number") != none [#t.plate: #opt(data, "vehicle_number")]
]
#v(3mm)
#route()
#v(3mm)
#text(size: 8.5pt, fill: muted)[#fmt-number(data.distance_km) #t.unit]

#v(4mm)
#text(size: 7.5pt, fill: muted)[
  #strong(data.operator_name)#if opt(data, "operator_address") != none [ · #lines(opt(data, "operator_address"))]
  #if opt(data, "seller_tax_id") != none [ · #tax-id-label: #opt(data, "seller_tax_id")]
]
#if rate != none [#v(1mm) #text(size: 7.5pt, fill: muted, t.fares_incl)]
