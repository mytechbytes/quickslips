// Driver salary receipt, design t7: the receipt of the employer, written in the employer's name: who pays, the pay broken down in a table, the amount
// in words, and the signatures of the employer and the driver.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 150mm, margin: (x: 12mm, y: 12mm), size: 10pt)
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
#let memo = receipt.number
#let net = net * receipt.months
#let breakdown = breakdown.map(((label, amount)) => (label, amount * receipt.months))
#let period = receipt.months > 1
#let address = opt(data, "employer_address")

#v(1mm)
#align(center, text(size: 15pt, weight: "bold", t.title))
#v(1mm)
#align(center, text(size: 8.5pt, fill: muted, t.er_sub))
#v(2mm)
#rule()
#v(3mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  [*#t.er_name:* #data.employer_name#if code != none [ \ *#t.er_code:* #code]#if address != none [ \ *#t.er_address:* #lines(address)]],
  align(right)[#if memo != none [*#t.memo_number:* #memo \ ]#if when != none [*#t.date:* #fmt-date(when)]],
)
#v(3mm)
#say(if period { t.er_paid_period } else { t.er_paid }, (amount: money(net), driver: data.driver_name, employer: data.employer_name, month: month))
#if declaration != none [ #v(1mm) #lines(declaration)]
#v(3mm)
#table(
  columns: (1fr, auto),
  align: (left, right),
  stroke: 0.6pt + luma(190),
  inset: (x: 3mm, y: 2.2mm),
  [*#t.driver_name*], [#data.driver_name],
  ..if vehicle != none { ([*#t.vehicle_no*], [#vehicle]) } else { () },
  [*#t.period*], [#month],
  ..breakdown.map(((label, amount)) => (text(fill: muted, label), text(fill: muted, money(amount)))).flatten(),
  [*#t.amount_paid*], [*#money(net)*],
)
#let words = amount-words-line(net)
#if words != none [#v(2mm) #words]
#v(4mm)
#stamp()
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 6mm,
  align(left + bottom, box(width: 52mm, signature-block(data, t.er_signature))),
  align(right + bottom, signature-block(data, t.ack_thumb, key: "driver_signature", name: data.driver_name)),
)
]
