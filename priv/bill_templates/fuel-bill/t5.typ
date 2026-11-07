// Fuel bill, design t5: a cash memo, a framed form with dotted lines and a table of the fuels (the one that was
// bought is filled in), with the amount split into the currency and its small change.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 86mm, margin: 3mm, size: 8pt)
#set par(leading: 0.5em)

#let fuel = option-label("fuel_type", data.fuel_type)
#let total = data.quantity * data.rate
#let rate = opt(data, "tax_percent")
#let decimals = region.currency.decimals
#let minor = int(calc.round(total * calc.pow(10, decimals)))
#let whole = calc.quo(minor, int(calc.pow(10, decimals)))
#let cents = calc.rem(minor, int(calc.pow(10, decimals)))
#let cents-text = if decimals == 0 { "" } else { "0" * (decimals - str(cents).len()) + str(cents) }
// The amount is two columns (the currency, and its small change) where the currency has small change, else one.
#let split = minor-head != none

// "Label ........ value": a line of a form, filled in.
#let filled(label, value) = [#label #h(1mm) #box(width: 1fr, stroke: (bottom: (paint: luma(90), thickness: 0.6pt, dash: "dotted")), inset: (bottom: 0.6mm), value)]

#let heading-cells = if split { (t.particulars, t.rate, region.currency.symbol, minor-head) } else { (t.particulars, t.rate, region.currency.symbol) }
#let columns = if split { (1fr, auto, auto, auto) } else { (1fr, auto, auto) }

#block(width: 100%, stroke: 1.4pt, inset: 1mm, block(width: 100%, stroke: 0.5pt, inset: (x: 3mm, y: 2.6mm))[
  #grid(
    columns: (1fr, auto),
    column-gutter: 3mm,
    align: (left + top, right + top),
    [#picture(data, "logo", 8mm)
      #text(size: 9pt, weight: "bold", data.station_name)
      #if opt(data, "station_address") != none [ \ #text(size: 6.5pt, fill: muted, lines(opt(data, "station_address")))]
      #if opt(data, "station_phone") != none [ \ #text(size: 6.5pt, fill: muted)[#t.tel #opt(data, "station_phone")]]],
    align(center, text(size: 12pt, weight: "bold")[#upper(t.cash_memo)]),
  )
  #v(1mm)
  #rule()
  #v(1.5mm)
  #grid(
    columns: (1fr, 1fr),
    column-gutter: 4mm,
    row-gutter: 2mm,
    filled(strong(t.no), data.bill_number),
    if opt(data, "time") != none { filled(strong(t.time), fmt-time(data.time)) },
    grid.cell(colspan: 2, filled(strong(t.dated), fmt-date(data.date))),
    grid.cell(colspan: 2, filled(strong(t.vehicle_no), opt(data, "vehicle_number"))),
  )
  #let ids = (
    if opt(data, "fcc_id") != none { t.fcc + ": " + opt(data, "fcc_id") },
    if opt(data, "fip_no") != none { t.fip + ": " + opt(data, "fip_no") },
    if opt(data, "seller_tax_id") != none { tax-id-label + ": " + opt(data, "seller_tax_id") },
  ).filter(id => id != none)
  #if ids.len() > 0 [
    #v(1mm)
    #text(size: 6.5pt, ids.join("  "))
  ]
  #v(2mm)

  #table(
    columns: columns,
    align: (left, right, right, right),
    stroke: 0.6pt,
    inset: (x: 1.5mm, y: 1.6mm),
    table.header(..heading-cells.map(strong)),
    ..for key in ("Petrol", "Diesel", "CNG") {
      let name = option-label("fuel_type", key)
      let used = key == data.fuel_type
      (
        [#name #box(width: 1fr, repeat[.]) #if used [#fmt-number(data.quantity)] #t.unit],
        if used { fmt-number(data.rate, digits: 2) },
        if used { group-digits(str(whole)) },
        ..(if split { (if used { cents-text },) } else { () }),
      )
    },
    table.cell(colspan: 2, align: right, strong(t.total)),
    strong(group-digits(str(whole))),
    ..(if split { (strong(cents-text),) } else { () }),
  )

  #let shown = tax-lines(total, rate)
  #if shown.len() > 0 [
    #v(1mm)
    #align(right, text(size: 7pt, grid(
      columns: (auto, auto),
      column-gutter: 4mm,
      row-gutter: 1mm,
      align: (left, right),
      ..shown.map(((label, amount)) => (text(fill: muted, label), money(amount))).flatten(),
    )))
  ]
  #let words = amount-words-line(total)
  #if words != none [#v(1mm) #align(right, text(size: 7pt)[#words])]

  #v(2mm)
  #grid(
    columns: (1fr, 1fr),
    [#strong(t.thanks)],
    align(right)[#strong(t.all_tax_included)],
  )
  #v(0.5mm)
  #align(center, text(size: 7pt)[#t.payment: #option-label("payment_mode", data.payment_mode)])
  #v(2mm)
  #grid(
    columns: (auto, 1fr, auto),
    column-gutter: 2mm,
    align: (left + bottom, center + bottom, right + bottom),
    text(size: 7pt)[#t.eoe],
    text(size: 7pt, weight: "bold", upper(t.happy_journey)),
    {
      let signature = picture(data, "signature", 8mm)
      if signature != none { signature; linebreak() }
      text(size: 7pt)[#t.signatory]
    },
  )
])
