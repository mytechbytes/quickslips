// Electricity bill, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a4", margin: 18mm, size: 10.5pt)

#let previous = data.previous_reading
#let current = data.current_reading
#let units = calc.max(0, current - previous)
#let energy = units * data.rate_per_unit
#let fixed = num(data, "fixed_charge")
#let tax-rate = num(data, "tax_percent")
#let tax = percent(energy + fixed, tax-rate)
#let total = energy + fixed + tax

#letterhead(data, data.issuer_name, address: opt(data, "issuer_address"), title: "Electricity bill")

#details(
  (
    ([Bill no.], data.bill_number),
    ([Bill date], fmt-date(data.bill_date)),
    ([Due date], if opt(data, "due_date") != none { fmt-date(data.due_date) }),
    ([Consumer], data.consumer_name),
    ([Consumer no.], data.consumer_number),
    ([Billing month], month-label(data.billing_month)),
  ),
  columns: 3,
)

#v(4mm)
#details((([Service address], lines(data.service_address)),), columns: 1)

#v(8mm)
#bill-table(
  ([Previous reading], [Current reading], [Units used], [Rate per unit]),
  (([#previous], [#current], [#units], [#money(data.rate_per_unit)]),),
  columns: (1fr,) * 4,
)

#v(3mm)
#totals(
  (
    ([Energy charges (#units units)], energy),
    ([Fixed charge], fixed),
    ([Duty and tax (#tax-rate%)], tax),
  ),
  total,
  label: "Amount payable",
)

#if opt(data, "due_date") != none [
  #v(6mm)
  Please pay by *#fmt-date(data.due_date)* to avoid a late fee.
]

#footnote[This is a computer generated bill.]
