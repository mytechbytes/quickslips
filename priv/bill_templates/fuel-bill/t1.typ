// Tinymist: Fuel bill, design t1. Reads data.json (next to this file).
#let data = json("data.json")
#let preview = sys.inputs.at("mode", default: "final") == "preview"

#set page(
  paper: "a5",
  margin: (x: 14mm, y: 14mm),
  background: if preview {
    rotate(-30deg, text(size: 54pt, weight: "bold", fill: luma(225))[QUICK SLIPS])
  },
)
#set text(font: "Noto Sans", size: 10pt)

// Optional fields may be missing or empty.
#let opt(key) = {
  let value = data.at(key, default: none)
  if value == none or value == "" { none } else { value }
}

#let fmt-date(iso) = {
  let (y, m, d) = iso.split("-").map(int)
  datetime(year: y, month: m, day: d).display("[day]/[month]/[year]")
}

// Display money as ₹ 1234.50 from a number of rupees.
#let money(n) = {
  let paise = int(calc.round(n * 100))
  let frac = calc.rem(paise, 100)
  "₹ " + str(calc.quo(paise, 100)) + "." + (if frac < 10 { "0" } else { "" }) + str(frac)
}

#align(center)[
  #text(size: 14pt, weight: "bold")[#data.station_name]
  #if opt("station_address") != none [ \ #opt("station_address")]
]

#v(2mm)
#line(length: 100%, stroke: 0.5pt + luma(180))
#v(3mm)

#grid(
  columns: (1fr, 1fr),
  row-gutter: 3mm,
  [*Bill no.* #data.bill_number], align(right)[*Date* #fmt-date(data.date)],
  [*Vehicle* #if opt("vehicle_number") != none [#opt("vehicle_number")] else [-]],
  align(right)[*Fuel* #data.fuel_type],
)

#v(4mm)

#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  stroke: none,
  inset: (x: 2mm, y: 3mm),
  table.hline(stroke: 0.5pt),
  [*Item*], [*Qty (L)*], [*Rate*], [*Amount*],
  table.hline(stroke: 0.5pt),
  [#data.fuel_type], [#data.quantity], [#money(data.rate)], [#money(data.quantity * data.rate)],
  table.hline(stroke: 0.5pt),
)

#v(2mm)
#align(right)[#text(size: 12pt, weight: "bold")[Total: #money(data.quantity * data.rate)]]

#place(bottom + center, text(size: 8pt, fill: luma(120))[Thank you. Visit again.])
