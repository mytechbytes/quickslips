// Courier receipt, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5")

#let freight = data.freight_charge
#let insurance = num(data, "insurance")
#let tax-rate = num(data, "gst_percent")
#let tax = percent(freight + insurance, tax-rate)
#let total = freight + insurance + tax

#letterhead(data, data.courier_name, address: opt(data, "courier_address"), title: "Courier receipt")

#details((
  ([Tracking no.], data.tracking_number),
  ([Order / Invoice no.], opt(data, "order_number")),
  ([Booked on], fmt-date(data.booking_date)),
  ([Service], data.service),
  ([Weight], [#data.weight_kg kg]),
  ([Parcels], [#data.parcels]),
  ([Payment], data.payment_type),
))

#v(4mm)
#let party(label, name, city) = block(width: 100%, inset: 3mm, stroke: 0.5pt + hairline, radius: 1.5mm)[
  #text(size: 7.5pt, fill: muted)[#label] \ *#name* \ #city
]
#grid(
  columns: (1fr, 1fr),
  column-gutter: 4mm,
  party([FROM], data.sender_name, data.sender_city),
  party([TO], data.receiver_name, data.receiver_city),
)

#v(4mm)
#totals(
  (
    ([Freight (#data.service)], freight),
    ([Insurance], insurance),
    ([#tax-name (#tax-rate%)], tax),
  ),
  total,
)

#v(8mm)
#signature-block(data, [Booking clerk])

#footnote[Keep this receipt to track your parcel.]
