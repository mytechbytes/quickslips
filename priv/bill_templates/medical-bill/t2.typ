// Medical bill, design t2: a provisional bill of a stay: the hospital, the patient and the payer, the admission, a summary of the
// charges with the totals, the balance, then a detailed breakup line by line.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let on-sheet = data.at("paper_size", default: none) != none
#let some(key) = opt(data, key)

// The fixed charges of the form that are not 0, then the itemised lines (units times price).
#let fixed = (
  (t.consultation, num(data, "consultation_fee")), (t.medicines, num(data, "medicines_cost")),
  (t.tests, num(data, "tests_cost")), (t.other, num(data, "other_charges")),
).filter(row => row.at(1) != 0)
#let lines-of = (
  fixed.map(((label, amount)) => (name: label, qty: 1, rate: amount, amount: amount))
    + item-rows(data).map(row => (name: row.name, qty: row.qty, rate: row.rate, amount: row.amount))
)
#let subtotal = sum-of(lines-of.map(line => line.amount))
#let discount = num(data, "discount")
#let taxable = calc.max(subtotal - discount, 0)
#let rate = some("tax_percent")
// Where the tax is part of the prices the total is the taxable amount; where it is added the total is that and the tax.
#let tax = if rate != none { calc.round(tax-split(taxable, rate).tax, digits: 2) } else { 0 }
#let included = tax-mode == "included"
#let total = if included { taxable } else { taxable + tax }
#let without-tax = if included { taxable - tax } else { taxable }
// What was paid: all of it unless the bill says how much; the rest is the balance.
#let paid = data.at("amount_paid", default: total)
#let balance = calc.max(total - paid, 0)
#let time = if some("time") != none { fmt-time(some("time")) }
#let when = fmt-date(data.date) + if time != none { " " + time } else { "" }
#let kv(label, value) = if value != none [*#label:* #value]
#let stack-of(..rows) = rows.pos().filter(row => row != none).join(linebreak())
#let room = if some("room") != none { option-label("room", some("room")) }
#show: base.with(width: 125mm, margin: (x: 8mm, y: 8mm), size: 9pt)
#set par(leading: 0.6em)

#let double-rule() = {
  line(length: 100%, stroke: 1.2pt)
  v(0.8mm)
  line(length: 100%, stroke: 0.6pt)
}
#let heading-of(label) = align(center, text(size: 13pt, weight: "bold", tracking: 0.8pt, upper(label)))
// The groups of the summary: the fixed charges and the itemised lines together.
#let itemised = item-rows(data)
#let summary = (
  fixed.map(((label, amount)) => (label, amount))
    + if itemised.len() > 0 { ((t.itemised, sum-of(itemised.map(row => row.amount))),) } else { () }
)

#grid(
  columns: (auto, 1fr),
  column-gutter: 4mm,
  box(width: 16mm, height: 16mm, stroke: 0.8pt + luma(150), radius: 2mm, inset: 1mm, align(center + horizon, {
    let logo = picture(data, "logo", 12mm)
    if logo != none { logo } else { text(size: 16pt, weight: "bold", fill: luma(120), "+") }
  })),
  {
    text(size: 18pt, weight: "bold", data.clinic_name)
    linebreak()
    stack-of(
      if some("registration_number") != none { [#t.reg_no #some("registration_number")] },
      if some("clinic_address") != none { lines(some("clinic_address")) },
      if some("hospital_details") != none { lines(some("hospital_details")) },
      [#if some("clinic_phone") != none [#t.phone: #some("clinic_phone")]#if some("clinic_phone") != none and time != none [ | ]#if time != none [#t.timing: #time]],
    )
  },
)
#v(2mm)
#line(length: 100%, stroke: 1pt)
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 6mm,
  {
    stack-of(
      kv(t.patient_uid, data.bill_number), kv(t.name, data.patient_name), kv(t.patient_issue, some("patient_issue")),
      kv(t.age, some("patient_details")), kv(t.address, if some("patient_address") != none { lines(some("patient_address")) }), kv(t.contact, some("patient_phone")),
    )
    if some("payer_name") != none or some("payer_address") != none {
      v(1.5mm)
      text(weight: "bold", t.payer)
      linebreak()
      stack-of(kv(t.name, some("payer_name")), kv(t.address, if some("payer_address") != none { lines(some("payer_address")) }))
    }
    if some("doctor_name") != none {
      v(1.5mm)
      text(weight: "bold", t.consulting_doctors)
      linebreak()
      [#some("doctor_name")#if some("doctor_designation") != none [ (#some("doctor_designation"))]]
    }
  },
  stack-of(
    kv(t.date, fmt-date(data.date)), kv(t.admission_no, data.bill_number),
    kv(t.admission_date, if some("admit_date") != none { fmt-date(some("admit_date")) }),
    kv(t.discharge_date, if some("discharge_date") != none { fmt-date(some("discharge_date")) }),
    kv(t.bed, room),
  ),
)
#v(3mm)
#double-rule()
#v(1.5mm)
#heading-of(t.provisional)
#v(1mm)
#table(
  columns: (auto, 1fr, auto),
  align: (left, left, right),
  stroke: none,
  inset: (x: 1.5mm, y: 1.6mm),
  table.hline(stroke: 0.6pt),
  ..([#t.room_type], [#t.particulars], [#t.amount]).map(cell => text(weight: "bold", cell)),
  table.hline(stroke: 0.6pt),
  ..summary.map(((label, amount)) => ([#if room != none { room } else { [–] }], [#label], [#money(amount)])).flatten(),
  table.hline(stroke: 0.6pt + luma(190)),
)
#align(right, grid(
  columns: (auto, auto),
  column-gutter: 5mm,
  row-gutter: 1.5mm,
  align: (right, right),
  [#t.total_bill:], [#money(subtotal)],
  [#t.discount:], [#money(discount)],
  [#t.taxable:], [#money(without-tax)],
  ..for (name, percentage, amount) in tax-parts(rate, tax) { ([#name (#fmt-number(percentage)%):], [#money(amount)]) },
  [#t.payable:], [#money(total)],
  [#t.balance:], [#money(balance)],
  [*#t.amount_paid:*], [*#money(paid)*],
))
#v(2mm)
#double-rule()
// In the browser preview the next part is a page of its own.
#if preview and not on-sheet { pagebreak(weak: true) }
#v(1.5mm)
#heading-of(t.breakup)
#v(1mm)
#table(
  columns: (auto, auto, 1fr, auto, auto, auto),
  align: (left, left, left, right, right, right),
  stroke: none,
  inset: (x: 1.2mm, y: 1.5mm),
  table.hline(stroke: 0.6pt),
  ..([#t.room_type], [#t.date_time], [#t.particulars], [#t.rate], [#t.units], [#t.amount]).map(cell => text(size: 8pt, weight: "bold", cell)),
  table.hline(stroke: 0.6pt),
  ..lines-of.map(line => (
    if room != none { room } else { [–] }, text(size: 8pt, when), line.name, money(line.rate), fmt-number(line.qty), money(line.amount),
  )).flatten(),
  table.hline(stroke: 0.6pt + luma(190)),
)
#v(2mm)
#text(size: 8.5pt)[
  #stack-of(
    kv(t.payment_mode, option-label("payment_mode", data.payment_mode)),
    if region.country == "in" and rate != none { kv(t.gst_type, t.intra) },
    if rate != none { kv(t.gst_pct, [#fmt-number(rate)%]) },
    kv(t.insurance, if some("insurance") != none { option-label("insurance", some("insurance")) }),
    if some("remark") != none { lines(some("remark")) },
    [*#t.notes:* #t.computer #t.created.replace("{when}", when)],
  )
]
