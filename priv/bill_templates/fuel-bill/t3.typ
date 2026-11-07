// Fuel bill, design t3: a thermal till receipt, in capitals with a row for each fact.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 69mm, margin: (x: 4.5mm, y: 5mm), size: 8pt)
#set text(weight: "bold", tracking: 0.25pt)
#set par(leading: 0.55em)

#let fuel = option-label("fuel_type", data.fuel_type)
#let total = data.quantity * data.rate
#let rate = opt(data, "tax_percent")

// "LABEL: value" in capitals, nothing for an empty field.
#let row(label, value) = if value != none { block(below: 1.6mm, upper(label + ": ") + value) }

#align(center)[
  #picture(data, "logo", 9mm)
  #upper(t.welcome) \
  #text(size: 9pt, upper(data.station_name))
  #if opt(data, "station_address") != none [ \ #upper(lines(opt(data, "station_address")))]
]
#v(1.5mm)
#dashed()
#v(2mm)

#row(t.receipt_no, data.bill_number)
#v(2mm)
#row(t.product, fuel)
#row(t.rate + "/" + t.unit, money(data.rate))
#row(t.amount, money(total))
#row(t.volume, fmt-number(data.quantity) + " " + t.unit)
#for (label, amount) in tax-lines(total, rate) { row(label, money(amount)) }
#v(2mm)
#row(t.vehicle_no, opt(data, "vehicle_number"))
#row(t.customer, opt(data, "customer_name"))
#v(2mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 3mm,
  upper(t.date + ": ") + fmt-date(data.date), if opt(data, "time") != none { upper(t.time + ": ") + fmt-time(data.time) },
)
#v(2mm)
#row(t.payment, option-label("payment_mode", data.payment_mode))
#v(1mm)
#dashed()
#v(1.5mm)
#align(center, upper(t.save_money))
