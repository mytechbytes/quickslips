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
  revenue-stamp(data, t.revenue_stamp, width: width, height: height)
}
#let vehicle = opt(data, "vehicle_number")
#let declaration = opt(data, "declaration")
// The parts of the pay, for the designs that show them: nothing is listed that is 0.
#let breakdown = (
  (t.monthly_salary, data.basic_salary), (t.overtime, overtime), (t.allowance, allowance), (t.deductions, -deductions),
).filter(row => row.at(1) != 0)
#let code = opt(data, "employee_code")
#let employee = data.employer_name + if code != none { " (" + code + ")" } else { "" }
// A receipt for each month chosen, or one for the quarter, half-year or year (see `salary-periods` of the helpers), one on
// each page of the PDF.
#let receipts = salary-periods(data)
#for (i, receipt) in receipts.enumerate() [
#if i > 0 { pagebreak() }
#let month = receipt.label
#let when = receipt.date
#let net = net * receipt.months
#let breakdown = breakdown.map(((label, amount)) => (label, amount * receipt.months))
#v(1mm)
#align(center, text(size: 14pt, weight: "bold", t.title))
#v(2mm)
#rule()
#v(4mm)

#let period = receipt.months > 1
#let address = opt(data, "employer_address")
#say(if period { t.certify_plain_period } else { t.certify_plain }, (amount: money(net), driver: data.driver_name, month: month))
#if declaration != none [ #v(1mm) #lines(declaration)]
#v(1mm)
#t.ack_reimburse
#v(1mm)
#t.ack_further

#v(2mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 8mm,
  row-gutter: 5mm,
  [*#t.employer_name:* #data.employer_name#if code != none [ \ *#t.employee_code:* #code]#if address != none [ \ *#t.employee_address:* #lines(address)]],
  if when != none { align(right)[*#t.date:* #fmt-date(when)] } else [],
  [*#t.driver_name:* #data.driver_name#if vehicle != none [ \ *#t.vehicle_no:* #vehicle]], [],
)
#v(4mm)
#grid(
  columns: (1fr, auto),
  stamp(),
  align(bottom, signature-block(data, t.employer_signature, name: employee)),
)
]
