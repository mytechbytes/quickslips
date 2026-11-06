// Internet bill, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a4", margin: 18mm, size: 10.5pt)

#let plan = data.plan_charge
#let other = num(data, "other_charges")
#let discount = num(data, "discount")
#let tax-rate = num(data, "gst_percent")
#let subtotal = plan + other - discount
#let tax = percent(subtotal, tax-rate)
#let total = subtotal + tax

#letterhead(
  data,
  data.provider_name,
  address: opt(data, "provider_address"),
  gstin: opt(data, "gstin"),
  title: "Internet bill",
)

#details(
  (
    ([Bill no.], data.bill_number),
    ([Bill date], fmt-date(data.bill_date)),
    ([Due date], if opt(data, "due_date") != none { fmt-date(data.due_date) }),
    ([Account no.], data.account_number),
    ([Billing period], [#fmt-date(data.period_start) to #fmt-date(data.period_end)]),
  ),
  columns: 3,
)

#v(5mm)
#details(
  (
    (
      [Billed to],
      [*#data.customer_name*#if opt(data, "customer_address") != none [ \ #lines(opt(data, "customer_address"))]],
    ),
  ),
  columns: 1,
)

#v(8mm)
#bill-table(
  ([Description], [Amount]),
  (
    ([#data.plan_name], [#money(plan)]),
    ..if other > 0 { (([Installation and other charges], [#money(other)]),) } else { () },
    ..if discount > 0 { (([Discount], [-#money(discount)]),) } else { () },
  ),
)

#v(3mm)
#totals((([Subtotal], subtotal), ([#tax-name (#tax-rate%)], tax)), total, label: "Amount due")

#if opt(data, "due_date") != none [
  #v(6mm)
  Please pay by *#fmt-date(data.due_date)* to keep your connection running.
]

#footnote[This is a computer generated bill.]
