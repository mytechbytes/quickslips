// Rent receipt, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5", margin: (x: 16mm, y: 16mm), size: 10.5pt)
#set par(leading: 0.7em)

#align(center)[#text(size: 15pt, weight: "bold")[RENT RECEIPT]]
#v(2mm)
#rule()
#v(4mm)

#align(right)[Date: #fmt-date(data.receipt_date)]
#v(2mm)

Received *#money(data.monthly_rent)* from *#data.tenant_name* towards the rent for the
month of *#month-label(data.month)* for the property situated at:

#pad(left: 5mm)[#lines(data.property_address)]

Payment mode: *#data.payment_mode*.

#v(6mm)

// The landlord signs. With a saved signature it is drawn above the line, otherwise there is room to sign by hand.
#signature-block(
  data,
  [Landlord] + if opt(data, "landlord_pan") != none [ \ PAN: #opt(data, "landlord_pan")],
  name: data.landlord_name,
)
