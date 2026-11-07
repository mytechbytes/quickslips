// Driver salary receipt, design t2: the receipt, and below it an acknowledgement slip for the driver to keep.
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

#let month = month-label(data.month)
#let heading(content) = align(center, block(text(size: 12pt, weight: "bold", content) + v(0.6mm) + line(length: 100%, stroke: 0.7pt)))

#align(right)[#t.date: #fmt-date(data.receipt_date)]
#v(1mm)
#align(center, box(width: 60mm, heading(t.title)))
#v(2mm)
#if vehicle != none [*#t.vehicle_no:* #vehicle \ ]
*#t.salary_month:* #month \
*#t.amount_paid:* #money(net) \
*#t.date:* #fmt-date(data.receipt_date)
#v(2mm)
#say(t.received_text, (employer: data.employer_name, amount: money(net), driver: data.driver_name, month: month))
#v(1mm)
#align(right)[*#t.employer_name:* #data.employer_name]

#v(3mm)
#line(length: 100%, stroke: (paint: luma(120), thickness: 0.7pt, dash: "dashed"))
#v(3mm)
#align(center, box(width: 70mm, heading(t.ack_title)))
#v(2mm)
*#t.salary_month:* #month \
*#t.amount_paid:* #money(net) \
*#t.date:* #fmt-date(data.receipt_date)
#v(2mm)
#say(t.received_text, (employer: data.employer_name, amount: money(net), driver: data.driver_name, month: month))
#v(1mm)
#align(right)[*#t.driver_name:* #data.driver_name]
#v(3mm)
#grid(
  columns: (1fr, auto),
  stamp(),
  align(bottom, signature-block(data, t.employer_signature, name: data.employer_name)),
)
