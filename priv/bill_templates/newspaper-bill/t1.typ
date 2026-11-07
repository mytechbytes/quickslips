// Newspaper bill, design t1: a small bill of a newspaper agency, 106 mm wide: the agency with its phones, the customer and the month,
// the bill number and the payment, a ruled table (quantity, description, rate, total), the subtotal, the service charge for the
// delivery at home and the grand total, the date and the signature. Reads data.json (next to this file). The words come from
// text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 106mm, margin: (x: 6mm, y: 6mm), size: 8.5pt)
#set par(leading: 0.55em)
#set block(spacing: 0pt)

#let rows = item-rows(data)
#let subtotal = sum-of(rows.map(row => row.amount))
#let service = num(data, "service_charge")
#let grand = subtotal + service
#let frame = 0.7pt + luma(40)
#let underline(body) = box(stroke: (bottom: 0.6pt + luma(60)), inset: (x: 1mm, bottom: 0.6mm), text(fill: rgb("#a3203c"), body))
#let prefix = if some("name_prefix") != none { option-label("name_prefix", some("name_prefix")) } else { "" }

#align(center)[
  #picture(data, "logo", 9mm)
  #text(size: 12pt, weight: "bold", tracking: 0.8pt, upper(data.agency_name)) \
  #text(size: 7pt, fill: muted, lines(data.agency_address)) \
  #if some("agency_mobile") != none or some("agency_phone") != none [
    #text(size: 8pt)[
      #if some("agency_mobile") != none [#t.mobile : #some("agency_mobile")]
      #if some("agency_mobile") != none and some("agency_phone") != none [ • ]
      #if some("agency_phone") != none [#t.phone : #some("agency_phone")]
    ]
  ]
]
#v(1.5mm)
#line(length: 100%, stroke: frame)
#v(2mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 4mm,
  row-gutter: 2.4mm,
  [#prefix #underline(data.customer_name)], [#t.month #underline([#option-label("month", data.month) #data.bill_year])],
  [#t.bill_no #underline(data.bill_number)], align(right)[#t.payment #underline(option-label("payment_mode", data.payment_mode))],
)
#v(2.5mm)
#table(
  columns: (auto, 1fr, auto, auto),
  align: (center, left, right, right),
  stroke: frame,
  inset: (x: 1.6mm, y: 1.5mm),
  ..(t.qty, t.description, t.rate, t.total).map(head => text(weight: "bold", upper(head))),
  ..rows.map(row => ([#fmt-number(row.qty)], row.name, money(row.rate), money(row.amount))).flatten(),
)
#grid(
  columns: (1fr, auto, auto),
  stroke: (x, y) => (left: frame, right: frame, bottom: frame),
  inset: (x: 1.6mm, y: 1.5mm),
  align: (right, right, right),
  grid.cell(colspan: 2, text(tracking: 0.4pt, t.subtotal)), money(subtotal),
  grid.cell(colspan: 2)[
    #t.service \
    #text(size: 6pt, style: "italic", t.service_note)
  ], money(service),
  grid.cell(colspan: 2, strong(upper(t.grand_total))), strong(money(grand)),
)
#v(3mm)
#grid(
  columns: (1fr, auto),
  [#t.date #underline(fmt-date(data.date))],
  align(right + bottom)[
    #picture(data, "signature", 9mm) \
    #text(size: 6.5pt, fill: muted, t.customer_signature)
  ],
)
