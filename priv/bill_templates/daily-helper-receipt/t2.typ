// Daily helper receipt, design t2: the receipt, and below it an acknowledgement slip for the helper to keep.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 150mm, margin: (x: 13mm, y: 12mm), size: 10pt)
#set par(leading: 0.75em)

#let amount = data.salary
#let month = month-label(data.month)
#let role = data.working_as
#let declaration = opt(data, "declaration")
// The revenue stamp is stuck on a receipt in India only.
#let stamp(width: 24mm, height: 28mm) = if region.country == "in" {
  revenue-stamp(data, t.revenue_stamp, width: width, height: height)
}
#let heading(content) = align(center, block(text(size: 12pt, weight: "bold", content) + v(0.6mm) + line(length: 100%, stroke: 0.7pt)))

#align(right)[#t.date: #fmt-date(data.receipt_date)]
#v(1mm)
#align(center, box(width: 60mm, heading(t.title)))
#v(2mm)
*#t.working_as:* #role \
*#t.salary_month:* #month \
*#t.amount_paid:* #money(amount) \
*#t.date:* #fmt-date(data.receipt_date)
#v(2mm)
#say(t.received_text, (employer: data.employer_name, amount: money(amount), helper: data.helper_name, role: role, month: month))
#v(1mm)
#align(right)[*#t.employer_name:* #data.employer_name]

#v(3mm)
#line(length: 100%, stroke: (paint: luma(120), thickness: 0.7pt, dash: "dashed"))
#v(3mm)
#align(center, box(width: 70mm, heading(t.ack_title)))
#v(2mm)
*#t.salary_month:* #month \
*#t.amount_paid:* #money(amount) \
*#t.date:* #fmt-date(data.receipt_date)
#v(2mm)
#say(t.received_text, (employer: data.employer_name, amount: money(amount), helper: data.helper_name, role: role, month: month))
#v(1mm)
#align(right)[*#t.helper_name:* #data.helper_name]
#v(3mm)
#grid(
  columns: (1fr, auto),
  stamp(),
  align(bottom, signature-block(data, t.employer_signature, name: data.employer_name)),
)
