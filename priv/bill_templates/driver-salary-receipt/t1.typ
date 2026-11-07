// Driver salary receipt, design t1: the certificate an employee hands in to be reimbursed for the pay of the driver: who paid
// whom, how much and for which month, with the declaration. Reads data.json (next to this file). The words come from
// text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 150mm, margin: (x: 13mm, y: 12mm), size: 10pt)
#set par(leading: 0.75em)

#let overtime = num(data, "overtime")
#let allowance = num(data, "allowance")
#let deductions = num(data, "deductions")
// What the driver is paid in a month, and the revenue stamp (stuck on a receipt in India only).
#let net = data.basic_salary + overtime + allowance - deductions
#let stamp(width: 24mm, height: 28mm) = if region.country == "in" {
  box(width: width, height: height, stroke: (paint: luma(120), thickness: 0.7pt, dash: "dashed"), inset: 2mm, align(center + horizon, text(size: 7.5pt, fill: muted, t.revenue_stamp)))
}
#let vehicle = opt(data, "vehicle_number")
#let declaration = opt(data, "declaration")
// The parts of the pay, for the designs that show them: nothing is listed that is 0.
#let breakdown = (
  (t.monthly_salary, data.basic_salary), (t.overtime, overtime), (t.allowance, allowance), (t.deductions, -deductions),
).filter(row => row.at(1) != 0)

#align(right)[#t.date: #fmt-date(data.receipt_date)]
#v(1mm)
#align(center, text(size: 14pt, weight: "bold", t.title))
#v(2mm)
#rule()
#v(4mm)

#say(t.certify, (employer: data.employer_name, amount: money(net), driver: data.driver_name, month: month-label(data.month)))
#if declaration != none [ #declaration]

#t.reimburse

#v(2mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 8mm,
  row-gutter: 5mm,
  if vehicle != none [*#t.vehicle_no:* #vehicle] else [], align(right)[*#t.date:* #fmt-date(data.receipt_date)],
  [*#t.driver_name:* #data.driver_name], align(right)[*#t.employer_name:* #data.employer_name],
)
#v(4mm)
#grid(
  columns: (1fr, auto),
  stamp(),
  align(bottom, signature-block(data, t.employer_signature, name: data.employer_name)),
)
