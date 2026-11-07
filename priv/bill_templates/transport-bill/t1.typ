// Transport bill, design t1: a goods consignment note, ruled in blue, with the route, the consignor and the consignee, the
// numbers of the consignment and the freight (to pay or paid). Reads data.json (next to this file). The words come from
// text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 140mm, margin: 6mm, size: 8pt)

#let ink = rgb("#26388a")
#let frame = 0.8pt + ink
#set par(leading: 0.5em)

// A box of the form: its label in small blue capitals, and what was filled in under it.
#let slot(label, value, size: 8.5pt) = [
  #text(size: 6.2pt, weight: "bold", fill: ink, upper(label)) \
  #if value != none { text(size: size, weight: "bold", value) }
]
#let some(key) = opt(data, key)
#let multi(key) = if some(key) != none { lines(some(key)) }
#let with-label(label, value) = if value != none [#label #value]

#block(width: 100%, stroke: 1.6pt + ink, inset: 1.2mm, block(width: 100%, stroke: 0.6pt + ink, {
  // The parts of the form touch each other: no gap between the tables.
  set block(spacing: 0pt)
  // The head: the transporter, with its numbers and the place of delivery.
  table(
    columns: (1fr,),
    stroke: none,
    inset: (x: 2.5mm, y: 2mm),
    align(center)[
      #picture(data, "logo", 10mm)
      #text(size: 13pt, weight: "bold", fill: ink, data.company_name) \
      #if some("company_address") != none [#text(size: 7.5pt, lines(some("company_address"))) \ ]
      #if some("company_phone") != none [#text(size: 7.5pt)[#t.tel #some("company_phone")] \ ]
      #text(size: 6.5pt, weight: "bold", fill: ink, upper(t.heading))
    ],
  )
  // The number, the kind of copy and the route.
  table(
    columns: (30mm, 1fr, 28mm, 28mm),
    stroke: frame,
    inset: 2mm,
    slot(t.gc_no, data.gc_number, size: 11pt),
    align(horizon, text(size: 10pt, weight: "bold", upper(t.title))),
    slot(t.from, [#some("from_place") \ #text(size: 7pt, some("from_phone"))]),
    slot(t.to, [#some("to_place") \ #text(size: 7pt, some("to_phone"))]),
  )
  // The body: the parties and the goods on the left, the numbers in the middle, the freight on the right.
  table(
    columns: (1fr, 31mm, 17mm, 17mm),
    stroke: frame,
    inset: 2mm,
    align: top + left,
    table.cell(rowspan: 2, slot(t.consignor, multi("consignor"))),
    slot(t.date, fmt-date(data.date)),
    table.cell(rowspan: 7, align: top + center, slot(t.to_pay, if some("to_pay") != none { money(some("to_pay")) })),
    table.cell(rowspan: 7, align: top + center, slot(t.paid, if some("paid") != none { money(some("paid")) })),
    slot(t.booking, if some("booking_date") != none { fmt-date(some("booking_date")) }),
    table.cell(rowspan: 2, slot(t.consignee, multi("consignee"))),
    slot(t.eta, if some("eta_date") != none { fmt-date(some("eta_date")) }),
    slot(t.articles, if some("articles") != none { fmt-number(some("articles")) }),
    table.cell(rowspan: 2, slot(t.description, multi("description"))),
    slot(t.pm_no, some("pm_number")),
    slot(t.actual_weight, some("actual_weight")),
    table.cell(rowspan: 4, {
      text(size: 7pt)[#t.note_labour]
      v(1.5mm)
      if some("seller_tax_id") != none { text(weight: "bold", fill: ink)[#tax-id-label: #some("seller_tax_id")]; linebreak() }
      if some("delivery_at") != none { text(weight: "bold", fill: ink)[#t.delivery_at: #some("delivery_at")]; linebreak() }
      v(1mm)
      text(size: 7pt)[#t.note_insurance]
    }),
    slot(t.charged_weight, some("charged_weight")),
    table.cell(rowspan: 3, slot(t.remarks, multi("remarks"))),
    table.cell(colspan: 2, rowspan: 3, align: top + left, {
      slot(t.signature, none)
      v(8mm)
      let signature = picture(data, "signature", 11mm)
      if signature != none { signature; linebreak() }
      if some("signatory_name") != none { text(size: 7.5pt, weight: "bold", some("signatory_name")) }
    }),
  )
  // The small print.
  table(
    columns: (1fr,),
    stroke: frame,
    inset: 2mm,
    text(size: 6.8pt)[
      • #t.note_validity \
      • #t.note_docs
    ],
  )
}))
