// Restaurant bill, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5")

#let items = line-items(data, 5)
#let subtotal = sum-of(items.map(row => row.amount))
#let service-rate = num(data, "service_percent")
#let service = percent(subtotal, service-rate)
#let tax-rate = num(data, "gst_percent")
#let tax = percent(subtotal + service, tax-rate)
#let total = subtotal + service + tax

#letterhead(
  data,
  data.restaurant_name,
  address: opt(data, "restaurant_address"),
  gstin: opt(data, "gstin"),
  title: "Bill",
)

#details((
  ([Bill no.], data.bill_number),
  ([Date], fmt-date(data.date)),
  ([Table], opt(data, "table_number")),
  ([Customer], opt(data, "customer_name")),
  ([Paid by], data.payment_mode),
))

#v(4mm)
#bill-table(
  ([Item], [Qty], [Rate], [Amount]),
  items.map(row => ([#row.name], [#row.qty], [#money(row.rate)], [#money(row.amount)])),
)

#v(3mm)
#totals(
  (
    ([Subtotal], subtotal),
    ([Service charge (#service-rate%)], service),
    ([GST (#tax-rate%)], tax),
  ),
  total,
)

#footnote[Thank you. Visit again.]
