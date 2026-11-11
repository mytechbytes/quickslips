// Driver salary receipt, design t6: a plain typed record, in capitals with colons, with the declaration, the amount in words,
// two notes and three boxes (payer, revenue stamp, driver's signature).
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 150mm, margin: (x: 12mm, y: 12mm), size: 9.5pt)
#set text(tracking: 0.2pt)
#set par(leading: 0.8em)

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
#let row(label, value) = [#upper(label) : #value \ ]

#line(length: 100%, stroke: 1.6pt)
#v(1mm)
#align(center)[
  #text(size: 17pt, weight: "bold", tracking: 1.2pt, upper(t.record_title)) \
  #text(size: 7.5pt, tracking: 1pt, upper(t.record_sub))
]
#v(1mm)
#line(length: 100%, stroke: 1.6pt)
#v(3mm)
#if when != none { row(t.date, fmt-date(when)) }
#row(t.salary_month, month)
#row(t.employer_name, data.employer_name)
#if code != none { row(t.employee_code, code) }
#row(t.driver_name, data.driver_name)
#if vehicle != none { row(t.vehicle_no, vehicle) }
#for (label, amount) in breakdown { row(label, money(amount)) }
#row(t.amount_paid, strong(money(net)))
#v(1mm)
#line(length: 100%, stroke: (paint: luma(120), thickness: 0.6pt, dash: "dashed"))
#v(1mm)
#upper(t.declaration_label): \
#t.confirm#if declaration != none [ #declaration]
#let words = amount-words-line(net)
#if words != none [#v(2mm) #words]
#v(1mm)
#line(length: 100%, stroke: (paint: luma(120), thickness: 0.6pt, dash: "dashed"))
#v(1mm)
#text(size: 8.5pt)[
  #upper(t.notes): \
  - #t.note_1 \
  - #t.note_2
]
#v(3mm)
#grid(
  columns: (1fr, 1fr, 1fr),
  column-gutter: 3mm,
  ..(
    [#text(size: 8pt, upper(t.payer_details)) \ #v(1mm) #t.name: #data.employer_name#if code != none [ \ #t.employee_code: #code]],
    [#text(size: 8pt, weight: "bold", upper(t.revenue_stamp)) \ #v(1mm) #stamp(width: 100%, height: 22mm)],
    [#text(size: 8pt, upper(t.driver_signature)) \ #v(1mm) #t.name: #data.driver_name \ #{
      let signature = picture(data, "driver_signature", 11mm)
      if signature != none { signature }
    }],
  ).map(cell => block(width: 100%, height: 38mm, stroke: 0.6pt + luma(190), inset: 3mm, radius: 1.5mm, cell)),
)
]
