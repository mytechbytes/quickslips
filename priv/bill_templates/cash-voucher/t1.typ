// Cash voucher, design t1: a ruled cash voucher, 120 mm wide: the voucher number and "Cash voucher", paid to, the date and the address, a
// table of the particulars with the amounts in whole units and small change, the total in figures, its words under it, and four boxes:
// prepared by, checked by, approved by and "received the full payment described above by" with the resident certificate number, the date
// and the place, and a dashed line to cut. Reads data.json (next to this file). The words come from text.json (`t`), the number and date
// formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 120mm, margin: (x: 7mm, y: 7mm), size: 8.5pt)
#set par(leading: 0.55em)
#set block(spacing: 0pt)

#let rows = item-rows(data, quantity: false)
#let total = sum-of(rows.map(row => row.amount))
#let frame = 1pt + luma(30)
#let decimals = region.currency.decimals
#let whole(amount) = str(calc.floor(calc.round(amount * calc.pow(10, decimals)) / calc.pow(10, decimals)))
#let minor(amount) = {
  let scale = int(calc.pow(10, decimals))
  let units = int(calc.round(amount * scale))
  let digits = str(calc.rem(units, scale))
  "0" * (decimals - digits.len()) + digits
}
#let underline-field(body, width: 1fr) = box(width: width, stroke: (bottom: 0.6pt + luma(60)), inset: (bottom: 0.8mm), body)
#let blank-rows = calc.max(0, 3 - rows.len())
#let amount-cells(amount) = if decimals > 0 { (align(right, [#region.currency.symbol #whole(amount)]), align(right, minor(amount))) } else { (align(right, money(amount)),) }
#let sign-line = line(length: 100%, stroke: 0.6pt + luma(60))

#grid(
  columns: (1fr, auto),
  [],
  align(right, text(size: 9pt, weight: "bold", [#t.no #data.voucher_number])),
)
#align(center, text(size: 17pt, weight: "bold", tracking: 1pt, underline(upper(t.cash_voucher))))
#v(3mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 5mm,
  [#strong(upper(t.paid_to + ":")) #underline-field(data.paid_to, width: 1fr)],
  [#strong(upper(t.date + ":")) #underline-field(fmt-date(data.date), width: 1fr)],
)
#v(2.5mm)
#strong(upper(t.address + ":")) #underline-field(data.address.replace("\n", ", "), width: 100%)
#v(3mm)
#block(width: 100%, stroke: frame, {
  table(
    columns: (1fr, auto, ..if decimals > 0 { (auto,) } else { () }),
    stroke: (x, y) => (bottom: if y >= 0 { 0.6pt + luma(60) }, left: if x > 0 { 0.6pt + luma(60) }),
    inset: (x: 2mm, y: 2mm),
    align: (left, right, ..if decimals > 0 { (right,) } else { () }),
    table.cell(align: center, strong(upper(t.particular))), table.cell(colspan: if decimals > 0 { 2 } else { 1 }, align: center, strong(upper(t.amount))),
    ..rows.map(row => (row.name, ..amount-cells(row.amount))).flatten(),
    ..range(blank-rows).map(_ => ([ ], ..(if decimals > 0 { ([ ], [ ]) } else { ([ ],) }))).flatten(),
  )
  grid(
    columns: (1fr, auto, auto),
    stroke: (x, y) => (left: if x > 0 { 0.6pt + luma(60) }),
    inset: 2mm,
    strong(upper(t.amount)), strong(upper(t.total)), align(right, strong(money(total))),
  )
  line(length: 100%, stroke: 0.6pt + luma(60))
  block(inset: 2mm, text(size: 7.5pt)[#strong(t.in_words + ":") #if amount-words(total) != none { amount-words(total) }])
  line(length: 100%, stroke: frame)
  grid(
    columns: (1fr, 1fr, 1fr, 1.5fr),
    stroke: (x, y) => (left: if x > 0 { frame }),
    inset: 2.2mm,
    [#text(size: 7.5pt, weight: "bold", upper(t.prepared_by + ":")) \ #v(1mm) #data.prepared_by \ #v(1mm) #picture(data, "signature", 5mm) #v(4mm) #sign-line],
    [#text(size: 7.5pt, weight: "bold", upper(t.checked_by + ":")) \ #v(1mm) #data.checked_by \ #v(1mm) #picture(data, "driver_signature", 5mm) #v(4mm) #sign-line],
    [#text(size: 7.5pt, weight: "bold", upper(t.approved_by + ":")) \ #v(1mm) #data.approved_by \ #v(1mm) #picture(data, "signature_3", 5mm) #v(4mm) #sign-line],
    [
      #text(size: 7.5pt, weight: "bold", upper(t.received_by)) \
      #v(7mm)
      #sign-line
      #v(2mm)
      #if some("resident_certificate") != none [#text(size: 7.5pt, weight: "bold", upper(t.res_cert)) #some("resident_certificate") \ #v(1.5mm)]
      #text(size: 7.5pt)[#strong(upper(t.date)) #if some("received_date") != none { fmt-date(some("received_date")) } else { fmt-date(data.date) }] \
      #v(1.5mm)
      #text(size: 7.5pt)[#strong(upper(t.place)) #some("place")]
    ],
  )
})
#v(4mm)
#line(length: 100%, stroke: (paint: luma(80), thickness: 0.8pt, dash: "dashed"))
