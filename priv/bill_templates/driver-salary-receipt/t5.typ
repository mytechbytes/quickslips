// Driver salary receipt, design t5: a payroll voucher: a table of the payer, the driver, the vehicle, the month and the
// amount, an acknowledgement with the amount in words, and three boxes (received by, revenue stamp, prepared by).
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 150mm, margin: (x: 12mm, y: 12mm), size: 9.5pt)
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
#let grey = luma(244)
#let rows = (
  (t.employer_name, data.employer_name),
  ..if code != none { ((t.employee_code, code),) } else { () },
  (t.driver_name, data.driver_name),
  ..if vehicle != none { ((t.vehicle_no, vehicle),) } else { () },
  (t.salary_month, month),
  ..if when != none { ((t.receipt_date, fmt-date(when)),) } else { () },
  ..breakdown.map(((label, amount)) => (text(fill: muted, label), text(fill: muted, money(amount)))),
  (strong(t.amount_paid), strong(money(net))),
)

#grid(
  columns: (1fr, auto),
  align: (left + bottom, right + top),
  [#text(size: 20pt, weight: "bold", tracking: 1pt, upper(t.payroll_voucher)) \ #text(size: 8.5pt, fill: muted, t.voucher_sub)],
  [],
)
#v(3mm)
#table(
  columns: (42mm, 1fr),
  stroke: 0.6pt + luma(190),
  inset: (x: 3mm, y: 2.2mm),
  ..rows.map(((label, value)) => (if type(label) == str { strong(label) } else { label }, value)).flatten(),
)
#v(3mm)
#block(width: 100%, fill: grey, stroke: 0.6pt + luma(190), inset: 4mm, radius: 1.5mm)[
  #text(size: 7.5pt, fill: muted, tracking: 0.5pt, upper(t.acknowledgement)) \
  #v(1mm)
  #say(t.ack_voucher, (driver: data.driver_name, employer: data.employer_name, month: month))
  #let words = amount-words-line(net)
  #if words != none [#v(1mm) #align(left, words)]
  #if declaration != none [#v(1mm) #declaration]
]
#v(3mm)
#grid(
  columns: (1fr, 1fr, 1fr),
  column-gutter: 3mm,
  ..(
    [#text(size: 8pt, weight: "bold", upper(t.received_by)) \ #v(1mm) #t.name: #data.driver_name \ #{
      let signature = picture(data, "driver_signature", 11mm)
      if signature != none { signature }
    }],
    [#text(size: 8pt, weight: "bold", upper(t.revenue_stamp)) \ #v(1mm) #stamp(width: 100%, height: 22mm)],
    [#text(size: 8pt, weight: "bold", upper(t.prepared_by)) \ #v(1mm) #t.name: #data.employer_name#if code != none [ \ #t.employee_code: #code] \ #{
      let signature = picture(data, "signature", 11mm)
      if signature != none { signature }
    }],
  ).map(cell => block(width: 100%, height: 38mm, stroke: 0.6pt + luma(190), inset: 3mm, radius: 1.5mm, cell)),
)
]
