// Gym membership receipt, design t1: a plain receipt on A5: the gym and "Membership receipt", the member, the plan and its period, the
// fees, the extra items, the tax and the total, and the signatory. Reads data.json (next to this file). The words come from text.json
// (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#let india = region.country == "in"

// The money: the membership fee, the joining fee and the extra items make the subtotal; the tax is added to it, or is part of it where
// the country says so.
#let joining = num(data, "joining_fee")
#let extras = item-rows(data)
#let extras-total = sum-of(extras.map(row => row.amount))
#let subtotal = data.fee + joining + extras-total
#let rate = num(data, "gst_percent")
#let split = tax-split(subtotal, rate)
#let taxable = split.base
#let tax = calc.round(split.tax, digits: 2)
#let total = if tax-mode == "included" { subtotal } else { subtotal + tax }
#let plan-label = option-label("plan", data.plan)
#show: base.with(paper: "a5")

#letterhead(
  data,
  data.gym_name,
  address: some("gym_address"),
  gstin: some("gstin"),
  title: t.membership_receipt,
)

#details((
  (t.receipt_no, data.receipt_number),
  (t.date, fmt-date(data.date)),
  (t.member, data.member_name),
  (t.phone, some("member_phone")),
  (t.plan, plan-label),
  (t.valid, [#fmt-date(data.start_date) #t.to #fmt-date(data.end_date)]),
  (t.paid_by, option-label("payment_mode", data.payment_mode)),
))

#v(5mm)
#totals(
  (
    ([#t.membership_fee (#plan-label)], data.fee),
    (t.joining_fee, joining),
    ..extras.map(row => ([#row.name × #fmt-number(row.qty)], row.amount)),
    ..if tax-mode == "included" { ((t.subtotal, taxable),) } else { () },
    ((if india { "GST" } else { tax-name }) + " (" + fmt-number(rate) + "%)", tax),
  ),
  total,
)

#v(8mm)
#signature-block(data, t.authorised)

#footnote(t.stay_fit)
