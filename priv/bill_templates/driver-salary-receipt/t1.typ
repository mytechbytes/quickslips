// Driver salary receipt, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5", margin: (x: 16mm, y: 16mm), size: 10.5pt)
#set par(leading: 0.7em)

#let overtime = num(data, "overtime")
#let allowance = num(data, "allowance")
#let deductions = num(data, "deductions")
#let net = data.basic_salary + overtime + allowance - deductions

#align(center)[#text(size: 15pt, weight: "bold")[SALARY RECEIPT]]
#v(2mm)
#rule()
#v(4mm)

#align(right)[Date: #fmt-date(data.receipt_date)]
#v(2mm)

Received *#money(net)* from *#data.employer_name* as salary for the month of
*#month-label(data.month)*, for work as a driver#if opt(data, "vehicle_number") != none [ of vehicle *#opt(data, "vehicle_number")*].

Payment mode: *#data.payment_mode*.

#v(2mm)
#totals(
  (
    ([Monthly salary], data.basic_salary),
    ([Overtime], overtime),
    ([Fuel and other allowance], allowance),
    ([Advance or deductions], -deductions),
  ),
  net,
  label: "Net amount",
)

#v(8mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  block(width: 52mm, {
    v(13mm)
    line(length: 100%, stroke: 0.5pt)
    v(-1mm)
    strong(data.driver_name)
    linebreak()
    text(size: 9pt, fill: muted)[Driver]
  }),
  signature-block(data, [Employer], name: data.employer_name),
)

#if opt(data, "employer_address") != none [
  #v(4mm)
  #text(size: 9pt, fill: muted)[Employer's address: #lines(opt(data, "employer_address"))]
]
