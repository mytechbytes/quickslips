// Mobile bill, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5")

#let plan = data.plan_charge
#let other = num(data, "other_charges")
#let tax-rate = num(data, "gst_percent")
#let tax = percent(plan + other, tax-rate)
#let total = plan + other + tax

#letterhead(
  data,
  data.operator_name,
  address: opt(data, "operator_address"),
  gstin: opt(data, "gstin"),
  title: "Mobile bill",
)

#details((
  ([Bill no.], data.bill_number),
  ([Date], fmt-date(data.bill_date)),
  ([Customer], data.customer_name),
  ([Mobile number], data.mobile_number),
  ([Plan type], data.plan_type),
  ([Validity], opt(data, "validity")),
  ([Paid by], data.payment_mode),
))

#v(5mm)
#bill-table(
  ([Description], [Amount]),
  (
    ([#data.plan_name], [#money(plan)]),
    ..if other > 0 { (([Other charges], [#money(other)]),) } else { () },
  ),
)

#v(3mm)
#totals((([Subtotal], plan + other), ([#tax-name (#tax-rate%)], tax)), total)

#v(8mm)
#signature-block(data, [Authorised signatory])

#footnote[Thank you for choosing us.]
