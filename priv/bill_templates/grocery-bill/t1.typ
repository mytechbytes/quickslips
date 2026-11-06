// Grocery bill, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5")

#let items = item-rows(data)
#let subtotal = sum-of(items.map(row => row.amount))
#let discount = num(data, "discount")
#let total = subtotal - discount

#letterhead(
  data,
  data.store_name,
  address: opt(data, "store_address"),
  gstin: opt(data, "gstin"),
  ids: if opt(data, "fssai_number") != none { ([FSSAI Lic. No.: #opt(data, "fssai_number")],) } else { () },
  title: "Bill",
)

#details((
  ([Bill no.], data.bill_number),
  ([Date], fmt-date(data.date)),
  ([Customer], opt(data, "customer_name")),
  ([Paid by], data.payment_mode),
))

#v(4mm)
#bill-table(
  ([Item], [Qty], [Price], [Amount]),
  items.map(row => ([#row.name], [#fmt-number(row.qty)], [#money(row.rate)], [#money(row.amount)])),
)

#v(3mm)
#totals((([Subtotal], subtotal), ([Discount], -discount)), total)

#footnote[Prices include tax where it applies. Thank you for shopping with us.]
