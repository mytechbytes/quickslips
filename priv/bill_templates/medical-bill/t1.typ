// Medical bill, design t1: the invoice of a hospital, clinic or lab: the invoice number, the hospital, the dates of the stay, the
// patient, a table of the charges, the way of payment, the tax with its CGST and SGST in India, the total and a remark. Reads
// data.json (next to this file). The words come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
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

#text(size: 9pt, weight: "bold", fill: muted)[#t.invoice_no: #data.bill_number]
#v(1mm)
#rule()
#v(2mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 6mm,
  {
    text(size: 13pt, weight: "bold", data.clinic_name)
    linebreak()
    stack-of(
      if some("clinic_address") != none { lines(some("clinic_address")) },
      if some("hospital_details") != none { lines(some("hospital_details")) },
      kv(t.contact, some("clinic_phone")),
      kv(t.reg_no, some("registration_number")),
    )
  },
  align(right + top, picture(data, "logo", 13mm)),
)
#v(1mm)
#kv(t.discharge_date, if some("discharge_date") != none { fmt-date(some("discharge_date")) })
#v(2mm)
#rule()
#v(2mm)
#text(size: 11pt, weight: "bold", t.patient_info)
#v(1.5mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 6mm,
  stack-of(kv(t.patient_name, data.patient_name), kv(t.guardian, some("guardian_name")), kv(t.age, some("patient_details")), kv(t.insurance, if some("insurance") != none { option-label("insurance", some("insurance")) }), kv(t.consultant, some("doctor_name"))),
  stack-of(kv(t.patient_issue, some("patient_issue")), kv(t.admit_date, if some("admit_date") != none { fmt-date(some("admit_date")) }), kv(t.room, room), kv(t.mobile, some("patient_phone")), kv(t.address, if some("patient_address") != none { lines(some("patient_address")) })),
)
#if some("doctor_designation") != none [#v(1mm) #text(size: 8pt, fill: muted)[#some("doctor_name") · #some("doctor_designation")]]
#v(3mm)
#table(
  columns: (1fr, auto, auto, auto),
  align: (left, right, right, right),
  stroke: none,
  fill: (_, row) => if row == 0 { luma(238) } else { none },
  inset: (x: 2mm, y: 2mm),
  table.header(..([#t.details], [#t.units], [#t.price], [#t.amount]).map(cell => text(weight: "bold", cell))),
  ..lines-of.map(line => ([#line.name], [#fmt-number(line.qty)], [#money(line.rate)], [#money(line.amount)])).flatten(),
  table.hline(stroke: 0.5pt + luma(190)),
)
#v(2mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 8mm,
  {
    text(weight: "bold", t.pay_by)
    linebreak()
    option-label("payment_mode", data.payment_mode)
    linebreak()
    [#t.amount_paid: #money(paid)]
  },
  align(right, grid(
    columns: (auto, auto),
    column-gutter: 6mm,
    row-gutter: 1.6mm,
    align: (right, right),
    ..if discount != 0 { ([#t.discount:], [-#money(discount)]) } else { () },
    ..if rate != none { ([#t.tax:], [#fmt-number(rate)%]) } else { () },
    ..for (name, percentage, amount) in tax-parts(rate, tax) { ([#name: #fmt-number(percentage)%], [#money(amount)]) },
    [*#t.taxable:*], [*#money(without-tax)*],
    [*#t.net:*], [*#money(taxable)*],
    text(size: 11pt, weight: "bold")[#t.total_amount:], text(size: 11pt, weight: "bold", money(total)),
  )),
)
#let words = amount-words-line(total)
#if words != none [#v(1mm) #align(right, words)]
#if some("remark") != none [
  #v(3mm)
  #rule()
  #v(2mm)
  #text(weight: "bold", t.remark) \
  #upper(lines(some("remark")))
]
#v(2mm)
#rule()
#v(1mm)
#text(size: 7.5pt, fill: muted)[#t.computer #t.created.replace("{when}", when)]
