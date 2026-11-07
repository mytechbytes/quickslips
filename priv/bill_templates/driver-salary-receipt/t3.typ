// Driver salary receipt, design t3: the employer's own declaration that the driver was paid, and the driver's receipt of the
// money below it, with the revenue stamp.
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

#align(center, text(size: 14pt, weight: "bold", t.title))
#v(3mm)
#say(t.certify_self, (amount: money(net), driver: data.driver_name, month: month))
#if declaration != none [ #declaration]
#t.reimburse
#v(2mm)
*#t.employer_name:* #data.employer_name \
*#t.date:* #fmt-date(data.receipt_date)

#v(3mm)
#line(length: 100%, stroke: 1.4pt)
#v(3mm)
#align(center, text(size: 12pt, weight: "bold", t.ack_title))
#v(2mm)
*#t.receipt_date_of:* #fmt-date(data.receipt_date) \
*#t.for_month:* #month \
*#t.driver_name:* #data.driver_name \
#if vehicle != none [*#t.vehicle_no:* #vehicle \ ]
#v(1mm)
#say(t.received_sum, (amount: money(net), month: month, employer: data.employer_name))
#v(3mm)
#grid(
  columns: (1fr, auto),
  stamp(),
  align(bottom, signature-block(data, t.employer_signature, name: data.employer_name)),
)
