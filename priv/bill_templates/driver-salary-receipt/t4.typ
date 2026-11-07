// Driver salary receipt, design t4: a receipt for each month, quarter, half-year or year of a period (up to 12 months), one on
// each page of the PDF; without a period it is the receipt of the month.
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

// A receipt for each month, quarter, half-year or year of the period (see `receipt-periods` of the helpers).
#let periods = receipt-periods(data)
#let count = periods.len()

#for (i, receipt) in periods.enumerate() {
  if i > 0 { pagebreak() }
  let period = receipt.label
  let amount = net * receipt.months

  align(right)[#t.date: #fmt-date(data.receipt_date)]
  v(1mm)
  align(center, text(size: 14pt, weight: "bold", t.title))
  if count > 1 { align(center, text(size: 8.5pt, fill: muted, t.receipt_of.replace("{number}", str(i + 1)).replace("{total}", str(count)))) }
  v(2mm)
  rule()
  v(4mm)
  say(t.certify_period, (employer: data.employer_name, amount: money(amount), driver: data.driver_name, period: period))
  if declaration != none [ #declaration]
  parbreak()
  [#t.reimburse]
  v(2mm)
  grid(
    columns: (1fr, auto),
    column-gutter: 8mm,
    row-gutter: 5mm,
    if vehicle != none [*#t.vehicle_no:* #vehicle] else [], align(right)[*#t.period:* #period],
    [*#t.driver_name:* #data.driver_name], align(right)[*#t.employer_name:* #data.employer_name],
  )
  v(4mm)
  grid(
    columns: (1fr, auto),
    stamp(),
    align(bottom, signature-block(data, t.employer_signature, name: data.employer_name)),
  )
}
