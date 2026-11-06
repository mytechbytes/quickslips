// Gym membership receipt, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5")

#let joining = num(data, "joining_fee")
#let tax-rate = num(data, "gst_percent")
#let tax = percent(data.fee + joining, tax-rate)
#let total = data.fee + joining + tax

#letterhead(
  data,
  data.gym_name,
  address: opt(data, "gym_address"),
  gstin: opt(data, "gstin"),
  title: "Membership receipt",
)

#details((
  ([Receipt no.], data.receipt_number),
  ([Date], fmt-date(data.date)),
  ([Member], data.member_name),
  ([Phone], opt(data, "member_phone")),
  ([Plan], data.plan),
  ([Valid], [#fmt-date(data.start_date) to #fmt-date(data.end_date)]),
  ([Paid by], data.payment_mode),
))

#v(5mm)
#totals(
  (
    ([Membership fee (#data.plan)], data.fee),
    ([Joining fee], joining),
    ([GST (#tax-rate%)], tax),
  ),
  total,
)

#v(8mm)
#signature-block(data, [Authorised signatory])

#footnote[Stay fit. See you at the gym.]
