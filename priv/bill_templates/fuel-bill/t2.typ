// Fuel bill, design t2: the slip of the pump, a narrow strip with a label over each value.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 64mm, margin: (x: 4.5mm, y: 5mm), size: 8.5pt)
#set par(leading: 0.5em)

#let fuel = option-label("fuel_type", data.fuel_type)
#let total = data.quantity * data.rate
#let rate = opt(data, "tax_percent")
#let density = opt(data, "density")

#align(center)[
  #picture(data, "logo", 9mm)
  #text(size: 10.5pt, weight: "bold", data.station_name)
  #if opt(data, "station_address") != none [ \ #text(size: 7pt, fill: muted, lines(opt(data, "station_address")))]
  #if opt(data, "station_phone") != none [ \ #text(size: 7pt, fill: muted)[#t.tel #opt(data, "station_phone")]]
  #if opt(data, "dealer_name") != none [ \ #text(size: 7pt, fill: muted)[#t.dealer: #opt(data, "dealer_name")]]
  #if opt(data, "seller_tax_id") != none [ \ #text(size: 7pt, fill: muted)[#tax-id-label: #opt(data, "seller_tax_id")]]
]
#v(1mm)
#align(center, strong(upper(t.original)))
#v(1.5mm)
#grid(
  columns: (1fr, auto),
  strong(fmt-date(data.date)), if opt(data, "time") != none { strong(fmt-time(data.time)) },
)
#v(2mm)

// A label in capitals, and the value under it.
#let slot(label, value) = if value != none {
  block(below: 2mm, breakable: false)[#strong(upper(label + ":")) \ #value]
}

#slot(t.bill_no, data.bill_number)
#slot(t.vehicle_no, opt(data, "vehicle_number"))
#slot(t.nozzle, opt(data, "nozzle_number"))
#slot(t.product, fuel)
#slot(t.density, if density != none { [#fmt-number(density) kg/m³] })
#slot(t.rate + "/" + t.unit, money(data.rate))
#slot(t.volume, [#fmt-number(data.quantity) #t.unit])
#slot(t.amount, strong(money(total)))
#for (label, amount) in tax-lines(total, rate) [
  #slot(label, money(amount))
]

#v(1mm)
#align(center, strong(t.thanks))
