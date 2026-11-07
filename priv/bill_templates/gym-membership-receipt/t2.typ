// Gym membership receipt, design t2: an invoice, 120 mm wide: the invoice number and date, the gym phone and a coloured corner with the
// user, the customer and the mobile number, the account summary in cards (bill from, billing cycle, due date, amount, payment mode), a
// table of the billing details with the subtotal, the tax and the total, the instructions for the gym, the remark and the signature.
// Reads data.json (next to this file). The words come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#let india = region.country == "in"

// The money: the membership fee, the joining fee and the extra items make the subtotal; the tax is added to it, or is part of it where
// the country says so.
#let joining = num(data, "joining_fee")
#let extras = item-rows(data)
#let extras-total = sum-of(extras.map(row => row.amount))
#let subtotal = data.fee + joining + extras-total
#let rate = num(data, "gst_percent")
#let split = tax-split(subtotal, rate)
#let taxable = split.base
#let tax = calc.round(split.tax, digits: 2)
#let total = if tax-mode == "included" { subtotal } else { subtotal + tax }
#let plan-label = option-label("plan", data.plan)
#show: base.with(width: 120mm, margin: (x: 8mm, y: 8mm), size: 8.5pt)
#set par(leading: 0.6em)
#set block(spacing: 0pt)
#let accent = rgb("#e8756b")
#let card(label, value) = box(width: 100%, fill: luma(240), radius: 3mm, inset: (x: 2mm, y: 3mm), align(center)[
  #text(size: 7pt, fill: muted, label) \
  #v(1mm)
  #text(weight: "bold", value)
])
#let numbered = if some("instructions") != none { some("instructions").split("\n").filter(line => line != "") } else { () }
#let cycle = if some("billing_cycle") != none { option-label("billing_cycle", some("billing_cycle")) } else { plan-label }

#align(right, text(size: 9pt)[
  #strong(t.invoice_no) #data.receipt_number \
  #t.invoice_date: #fmt-date(data.date)
])
#v(2mm)
#block(width: 100%, {
  grid(
    columns: (1fr, 62%),
    align(left + horizon, [
      #picture(data, "logo", 10mm)
      #if some("gym_phone") != none [#text(size: 9pt, some("gym_phone")) \ ]
      #text(size: 7.5pt, fill: muted, data.gym_name)
    ]),
    block(fill: accent, radius: (top-left: 14mm, rest: 3mm), inset: (left: 12mm, right: 4mm, y: 4mm), align(right, text(size: 8.5pt, fill: white)[
      #if some("user_number") != none [#strong(t.user_id + ":") #some("user_number") \ ]
      #strong(t.customer_name + ":") #data.member_name \
      #if some("member_address") != none [#strong(t.address + ":") #lines(some("member_address")) \ ]
      #if some("member_phone") != none [#strong(t.mobile + ":") #some("member_phone")]
    ])),
  )
})
#v(4mm)
#text(size: 10pt, weight: "bold", t.account_summary)
#v(2mm)
#grid(
  columns: (1fr, 1fr, 1fr),
  column-gutter: 2mm,
  card(t.bill_from_date, fmt-date(data.start_date)), card(t.billing_cycle, cycle), card(t.due_date, fmt-date(data.end_date)),
)
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 2mm,
  card(t.amount, money(total)), card(t.payment_mode, option-label("payment_mode", data.payment_mode)),
)
#v(4mm)
#block(width: 100%, stroke: 0.6pt + luma(190), clip: true, {
  block(width: 100%, fill: luma(245), inset: 2.4mm, strong(t.billing_details))
  table(
    columns: (1fr, auto, auto, auto),
    align: (left, right, right, right),
    stroke: 0.5pt + luma(200),
    inset: 2.2mm,
    ..(t.gym_item, t.unit, t.net_amount, t.total).map(head => strong(head)),
    [#t.membership_fee (#plan-label)], [1], money(data.fee), money(data.fee),
    ..if joining > 0 { (t.joining_fee, [1], money(joining), money(joining)) } else { () },
    ..extras.map(row => (row.name, [#fmt-number(row.qty)], money(row.rate), money(row.amount))).flatten(),
    table.cell(colspan: 2, []), t.subtotal, money(taxable),
    table.cell(colspan: 2, []), [#t.tax_pct], [#fmt-number(rate) %],
    table.cell(colspan: 2, []), t.taxable_amount, money(taxable),
    table.cell(colspan: 2, []), strong(t.total), strong(money(total)),
  )
})
#if numbered.len() > 0 [
  #v(4mm)
  #text(size: 10pt, weight: "bold", t.instructions_title)
  #v(1.5mm)
  #pad(left: 3mm, text(size: 8pt, numbered.map(line => [#line]).join(v(2mm))))
]
#v(5mm)
#grid(
  columns: (1fr, auto),
  [#strong(t.remark) #if some("remarks") != none [ \ #some("remarks")]],
  align(right)[#picture(data, "signature", 11mm) \ #strong(t.signature)],
)
