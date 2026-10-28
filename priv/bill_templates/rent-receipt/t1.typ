// Rent receipt, design t1.
#let data = json("data.json")
#let preview = sys.inputs.at("mode", default: "final") == "preview"

#set page(
  paper: "a5",
  margin: (x: 16mm, y: 16mm),
  background: if preview {
    rotate(-30deg, text(size: 54pt, weight: "bold", fill: luma(225))[PREVIEW])
  },
)
#set text(font: "Noto Sans", size: 10.5pt)
#set par(leading: 0.7em)

#let opt(key) = {
  let value = data.at(key, default: none)
  if value == none or value == "" { none } else { value }
}

#let months = ("January", "February", "March", "April", "May", "June", "July",
  "August", "September", "October", "November", "December")
#let month-label(ym) = {
  let (y, m) = ym.split("-").map(int)
  months.at(m - 1) + " " + str(y)
}
#let fmt-date(iso) = {
  let (y, m, d) = iso.split("-").map(int)
  datetime(year: y, month: m, day: d).display("[day]/[month]/[year]")
}
#let money(n) = {
  let paise = int(calc.round(n * 100))
  let frac = calc.rem(paise, 100)
  "₹ " + str(calc.quo(paise, 100)) + "." + (if frac < 10 { "0" } else { "" }) + str(frac)
}

#align(center)[#text(size: 15pt, weight: "bold")[RENT RECEIPT]]
#v(2mm)
#line(length: 100%, stroke: 0.5pt + luma(180))
#v(4mm)

#align(right)[Date: #fmt-date(data.receipt_date)]
#v(2mm)

Received *#money(data.monthly_rent)* from *#data.tenant_name* towards the rent for the
month of *#month-label(data.month)* for the property situated at:

#pad(left: 5mm)[#data.property_address]

Payment mode: *#data.payment_mode*.

#v(14mm)

#align(right)[
  #line(length: 45mm, stroke: 0.5pt)
  #v(-2mm)
  *#data.landlord_name* \
  Landlord
  #if opt("landlord_pan") != none [ \ PAN: #opt("landlord_pan")]
]
