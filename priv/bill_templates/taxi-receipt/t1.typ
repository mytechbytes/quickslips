// Taxi receipt, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5")

#let toll = num(data, "toll")
#let tax-rate = num(data, "tax_percent")
#let tax = percent(data.base_fare, tax-rate)
#let total = data.base_fare + toll + tax

#letterhead(data, data.operator_name, address: opt(data, "operator_address"), title: "Taxi receipt")

#details((
  ([Receipt no.], data.receipt_number),
  ([Date], fmt-date(data.date)),
  ([Passenger], opt(data, "passenger_name")),
  ([Vehicle], opt(data, "vehicle_number")),
  ([Distance], [#data.distance_km km]),
  ([Paid by], data.payment_mode),
))

#v(4mm)
#block(width: 100%, inset: 3mm, stroke: 0.5pt + hairline, radius: 1.5mm)[
  #grid(
    columns: (auto, 1fr),
    row-gutter: 2.5mm,
    column-gutter: 5mm,
    text(fill: muted)[From], data.pickup,
    text(fill: muted)[To], data.drop,
  )
]
#v(4mm)

#totals(
  (
    ([Fare for #data.distance_km km], data.base_fare),
    ([Toll and parking], toll),
    ([#tax-name (#tax-rate%)], tax),
  ),
  total,
)

#v(8mm)
#signature-block(data, [Driver or operator])

#footnote[Thank you for riding with us.]
