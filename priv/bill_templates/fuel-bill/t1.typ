// Fuel bill, design t1. Reads data.json (next to this file). The words come from text.json (`t`) and the
// number and date formats from region.json; the helpers read both.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5", margin: (x: 14mm, y: 14mm))

#let fuel = option-label("fuel_type", data.fuel_type)
#let total = data.quantity * data.rate

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
  [*#t.bill_no* #data.bill_number], align(right)[*#t.date* #fmt-date(data.date)],
  [*#t.vehicle* #if opt(data, "vehicle_number") != none [#opt(data, "vehicle_number")] else [-]],
  align(right)[*#t.fuel* #fuel],
)

#v(4mm)

#bill-table(
  (t.item, t.quantity, t.rate, t.amount),
  (([#fuel], [#fmt-number(data.quantity)], [#money(data.rate)], [#money(total)]),),
)

#v(2mm)
#align(right)[#text(size: 12pt, weight: "bold")[#t.total: #money(total)]]

#if opt(data, "signature") != none [
  #v(8mm)
  #signature-block(data, t.signatory)
]

#footnote[#t.thanks]
