// Fuel bill, design t6: the print of a dot-matrix pump, a label on the left and the value on the right.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 66mm, margin: (x: 4.5mm, y: 5mm), size: 8.5pt)
#set par(leading: 0.5em)

#let fuel = option-label("fuel_type", data.fuel_type)
#let total = data.quantity * data.rate
#let rate = opt(data, "tax_percent")
#let density = opt(data, "density")

// A label in grey on the left, the value in bold on the right; nothing for an empty field.
#let row(label, value) = if value != none {
  block(below: 2.6mm, grid(columns: (auto, 1fr), column-gutter: 3mm, text(fill: muted, label), align(right, strong(value))))
}

#align(center)[
  #picture(data, "logo", 9mm)
  #text(size: 10pt, weight: "bold", data.station_name)
  #if opt(data, "station_address") != none [ \ #text(size: 7pt, fill: muted, lines(opt(data, "station_address")))]
  #if opt(data, "seller_tax_id") != none [ \ #text(size: 7pt, fill: muted)[#tax-id-label: #opt(data, "seller_tax_id")]]
]
#v(2mm)

#grid(
  columns: (1fr, auto),
  text(fill: muted, fmt-date(data.date)), if opt(data, "time") != none { strong(fmt-time(data.time)) },
)
#v(2.6mm)
#row(t.receipt_no, data.bill_number)
#row(t.pump, opt(data, "nozzle_number"))
#row(t.grade, fuel)
#row(t.volume, [#fmt-number(data.quantity) #t.unit])
#row(t.unit_price, money(data.rate))
#row(t.amount, money(total))
#for (label, amount) in tax-lines(total, rate) { row(label, money(amount)) }
#row(t.density, if density != none { [#fmt-number(density) kg/m³] })
#row(t.vehicle_no, opt(data, "vehicle_number"))
