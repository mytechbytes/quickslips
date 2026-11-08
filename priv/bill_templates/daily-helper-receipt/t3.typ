// Daily helper receipt, design t3: the employer's own declaration that the helper was paid, and the helper's receipt of the
// money below it, with the revenue stamp.
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

#align(center, text(size: 14pt, weight: "bold", t.title))
#v(3mm)
#say(t.certify_self, (amount: money(amount), helper: data.helper_name, role: role, month: month))
#if declaration != none [ #declaration]
#t.reimburse
#v(2mm)
*#t.employer_name:* #data.employer_name \
*#t.date:* #fmt-date(data.receipt_date)

#v(3mm)
#line(length: 100%, stroke: 1.4pt)
#v(3mm)
#align(center, text(size: 12pt, weight: "bold", t.ack_title))
#v(2mm)
*#t.receipt_date_of:* #fmt-date(data.receipt_date) \
*#t.for_month:* #month \
*#t.helper_name:* #data.helper_name \
*#t.working_as:* #role
#v(1mm)
#say(t.received_sum, (amount: money(amount), month: month, employer: data.employer_name))
#v(3mm)
#grid(
  columns: (1fr, auto),
  stamp(),
  align(bottom, signature-block(data, t.employer_signature, name: data.employer_name)),
)
