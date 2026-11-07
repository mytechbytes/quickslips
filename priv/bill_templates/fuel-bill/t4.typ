// Fuel bill, design t4: the thermal receipt of t3 with the numbers of the station on top (phone, FCC, FIP, nozzle) and
// the tax registration below.
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

#row(t.tel, opt(data, "station_phone"))
#row(t.receipt_no, data.bill_number)
#row(t.fcc, opt(data, "fcc_id"))
#row(t.fip, opt(data, "fip_no"))
#row(t.nozzle, opt(data, "nozzle_number"))
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
#v(2mm)
#row(tax-id-label, opt(data, "seller_tax_id"))
#row(t.dealer, opt(data, "dealer_name"))
#v(1mm)
#dashed()
#v(1.5mm)
#align(center, upper(t.save_money))
