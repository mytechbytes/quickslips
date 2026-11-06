// Fuel bill, design t1. Reads data.json (next to this file).
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5", margin: (x: 14mm, y: 14mm))

// The server adds `logo` and `signature` to the data when the user picked a saved business that has them.
#align(center)[
  #picture(data, "logo", 14mm)
  #text(size: 14pt, weight: "bold")[#data.station_name]
  #if opt(data, "station_address") != none [ \ #lines(opt(data, "station_address"))]
]

#v(2mm)
#rule()
#v(3mm)

#grid(
  columns: (1fr, 1fr),
  row-gutter: 3mm,
  [*Bill no.* #data.bill_number], align(right)[*Date* #fmt-date(data.date)],
  [*Vehicle* #if opt(data, "vehicle_number") != none [#opt(data, "vehicle_number")] else [-]],
  align(right)[*Fuel* #data.fuel_type],
)

#v(4mm)

#bill-table(
  ([Item], [Qty (L)], [Rate], [Amount]),
  (([#data.fuel_type], [#data.quantity], [#money(data.rate)], [#money(data.quantity * data.rate)]),),
)

#v(2mm)
#align(right)[#text(size: 12pt, weight: "bold")[Total: #money(data.quantity * data.rate)]]

#if opt(data, "signature") != none [
  #v(8mm)
  #signature-block(data, [Authorised signatory])
]

#footnote[Thank you. Visit again.]
