// Fuel bill, design t1: a receipt with the details in two columns and a summary table. Reads data.json (next to
// this file). The words come from text.json (`t`) and the number and date formats from region.json; the helpers
// read both.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 203mm, margin: (x: 13mm, y: 12mm), size: 10pt)

#let fuel = option-label("fuel_type", data.fuel_type)
#let total = data.quantity * data.rate
#let rate = opt(data, "tax_percent")

// "Label: value", or nothing where the field was left empty.
#let kv(label, value) = if value != none [#label: #value]
#let block-of(title, ..rows) = {
  text(size: 11pt, weight: "bold", title)
  v(0.5mm)
  rows.pos().filter(row => row != none).join(linebreak())
}

// The server adds `logo` and `signature` to the data when the user picked a saved business that has them.
#grid(
  columns: (1fr, auto),
  align: (left + horizon, right + horizon),
  text(size: 21pt, weight: "bold", t.receipt_title), picture(data, "logo", 14mm),
)
#v(1mm)
#rule()
#v(3mm)

#grid(
  columns: (1fr, 1fr),
  column-gutter: 10mm,
  row-gutter: 5mm,
  {
    block-of(
      t.billed_to,
      kv(t.customer, opt(data, "customer_name")),
      kv(t.vehicle_no, opt(data, "vehicle_number")),
      kv(t.fuel_type, fuel),
    )
    v(4mm)
    block-of(t.payment, option-label("payment_mode", data.payment_mode))
  },
  align(right, {
    block-of(
      t.receipt_details,
      kv(t.receipt_no, data.bill_number),
      kv(t.date, fmt-date(data.date)),
      kv(t.time, if opt(data, "time") != none { fmt-time(data.time) }),
    )
    v(4mm)
    block-of(
      t.station,
      strong(data.station_name),
      if opt(data, "station_address") != none { lines(opt(data, "station_address")) },
      kv(t.tel, opt(data, "station_phone")),
      kv(tax-id-label, opt(data, "seller_tax_id")),
    )
  }),
)

#v(5mm)
#block(width: 100%, fill: luma(240), inset: (x: 3mm, y: 2.2mm), text(weight: "bold", t.summary))
#table(
  columns: (1fr, 1fr, 1fr),
  align: (left, center, right),
  stroke: none,
  inset: (x: 3mm, y: 2.6mm),
  table.hline(stroke: 0.5pt + hairline),
  strong(t.fuel_rate), strong(t.quantity), strong(t.total_amount),
  table.hline(stroke: 0.5pt + hairline),
  money(data.rate), [#fmt-number(data.quantity) #t.unit], money(total),
  table.hline(stroke: 0.5pt + hairline),
)

// Where the country has a tax on fuel that is part of the price (IVA in Spain), the bill shows what the price holds.
#let lines-of-tax = tax-lines(total, rate)
#align(right, {
  if lines-of-tax.len() > 0 {
    grid(
      columns: (auto, auto),
      column-gutter: 6mm,
      row-gutter: 1.5mm,
      align: (left, right),
      ..lines-of-tax.map(((label, amount)) => (text(fill: muted, label), money(amount))).flatten(),
    )
    v(1.5mm)
  }
  text(size: 12pt, weight: "bold")[#t.total: #money(total)]
  let words = amount-words-line(total)
  if words != none { v(1.5mm); words }
})

#v(5mm)
#align(center)[
  #text(weight: "bold", upper(t.thanks_fuelling)) \
  #v(1mm)
  #t.queries \
  #v(1mm)
  #upper(t.save_fuel)
]

#if opt(data, "signature") != none [
  #v(6mm)
  #signature-block(data, t.signatory)
]
