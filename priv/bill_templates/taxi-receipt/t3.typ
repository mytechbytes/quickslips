// Cab bill, design t3: a tax invoice of a hire for the days of a journey, in boxes, with the advance and the balance.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 117mm, margin: (x: 7mm, y: 7mm), size: 9pt)

#let toll = num(data, "toll")
#let airport = num(data, "airport_charge")
#let advance = num(data, "advance_paid")
#let subtotal = data.base_fare + toll + airport
#let rate = opt(data, "tax_percent")
#let split = if rate != none { tax-split(subtotal, rate) } else { (base: subtotal, tax: 0, total: subtotal) }
#let total = split.total
#let box-stroke = 0.9pt
#let vehicle = (opt(data, "vehicle_model"), opt(data, "vehicle_number")).filter(part => part != none)
#let stop-line(label, place, time) = [#label: #place#if time != none [ – #fmt-time(time)]]
#let when = (fmt-date(data.date), opt(data, "pickup_time")).filter(part => part != none)

// "Label: value", or nothing where the field was left empty.
#let kv(label, value) = if value != none [#text(fill: muted, label) #value]

#grid(
  columns: (1fr, auto),
  align: (left + bottom, right + bottom),
  picture(data, "logo", 11mm),
  {
    text(size: 13pt, weight: "bold", upper(t.tax_invoice))
    v(1mm)
    grid(
      columns: (auto, auto),
      column-gutter: 5mm,
      row-gutter: 1.5mm,
      align: (left, right),
      text(fill: muted, t.invoice_no), strong(data.receipt_number),
      text(fill: muted, t.date), strong(fmt-date(data.date)),
    )
  },
)
#v(1mm)
#line(length: 100%, stroke: 1.6pt)
#v(1mm)
#text(weight: "bold", data.operator_name)#if opt(data, "operator_address") != none [ \ #text(size: 8pt, fill: muted, lines(opt(data, "operator_address")))]#if opt(data, "seller_tax_id") != none [ \ #text(size: 8pt, fill: muted)[#tax-id-label: #opt(data, "seller_tax_id")]]
#v(3mm)

#block(width: 100%, stroke: box-stroke, inset: 3mm)[
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 5mm,
    [
      #text(size: 7.5pt, weight: "bold", tracking: 0.4pt, upper(t.billed_to))
      #v(1.5mm)
      #if opt(data, "passenger_name") != none { strong(opt(data, "passenger_name")) }
      #if opt(data, "customer_address") != none [ \ #lines(opt(data, "customer_address"))]
      #if opt(data, "customer_phone") != none [ \ #opt(data, "customer_phone")]
    ],
    [
      #text(size: 7.5pt, weight: "bold", tracking: 0.4pt, upper(t.trip_details))
      #v(1.5mm)
      #kv(t.driver, opt(data, "driver_name")) \
      #kv(t.vehicle_no, opt(data, "vehicle_number")) \
      #kv(t.vehicle, opt(data, "vehicle_model")) \
      #kv(t.date_time, when.join(", "))
    ],
  )
]
#v(3mm)

#table(
  columns: (1fr, auto),
  align: (left, right),
  stroke: box-stroke,
  inset: (x: 3mm, y: 2.4mm),
  table.header(strong(upper(t.particulars)), strong[#upper(t.amount) (#region.currency.symbol)]),
  [
    #if opt(data, "drop_date") != none [#t.period: #fmt-date(data.date) #t.until #fmt-date(opt(data, "drop_date")) \ ]
    #t.distance: #fmt-number(data.distance_km) #t.unit \
    #t.rate: #money(data.base_fare / data.distance_km) / #t.unit \
    #stop-line(t.pick_point, data.pickup, opt(data, "pickup_time")) \
    #stop-line(t.drop_point, data.drop, opt(data, "drop_time"))
    #if toll != 0 [ \ #t.toll: #money(toll)]
    #if airport != 0 [ \ #t.airport: #money(airport)]
    #if rate != none [ \ #tax-name (#fmt-number(rate)%): #money(split.tax)]
  ],
  align(right + top, money(data.base_fare)),
  ..if advance != 0 { (text(fill: muted)[#t.advance], align(right, money(advance))) } else { () },
  [#strong(t.balance)], align(right, strong(money(calc.max(total - advance, 0)))),
  [#t.payment: #option-label("payment_mode", data.payment_mode)], align(right, money(total)),
  table.cell(colspan: 2)[
    #strong(t.total_amount): #text(size: 11pt, weight: "bold", money(total))
    #let words = amount-words-line(total)
    #if words != none [ \ #words]
  ],
)

#v(10mm)
#signature-block(data, t.signatory)
