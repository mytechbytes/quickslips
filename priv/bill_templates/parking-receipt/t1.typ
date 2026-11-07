// Parking receipt, design t1: a narrow till slip, centred, with dashed lines between its parts. Reads data.json
// (next to this file). The words come from text.json (`t`) and the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 74mm, margin: (x: 5mm, y: 6mm), size: 9pt)
#set text(tracking: 0.3pt)
#set par(leading: 0.55em)
#set align(center)

#picture(data, "logo", 11mm)
#text(size: 10pt, weight: "bold", data.facility_name)
#v(0.5mm)
#text(size: 7.5pt, fill: muted)[
  #lines(data.facility_address)#if opt(data, "facility_phone") != none [ \ #t.tel #opt(data, "facility_phone")]
]
#v(2mm)
#strong(data.receipt_number)
#v(1.5mm)
#dashed()
#v(2mm)
#upper(t.title)
#v(2mm)
#dashed()
#v(3mm)
#if opt(data, "time") != none [#text(size: 14pt, weight: "bold", fmt-time(data.time)) \ ]
#fmt-date(data.date) \
#t.space: #data.space_number
#v(2mm)
#text(size: 13pt, weight: "bold")[#t.paid: #money(data.amount)]
#v(3mm)
#dashed()
#v(2.5mm)
#if opt(data, "thank_you") != none { text(size: 8pt, weight: "bold", lines(opt(data, "thank_you"))) }
