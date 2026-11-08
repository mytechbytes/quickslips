// Daily helper receipt, design t1: the certificate an employee hands in to be reimbursed for the pay of a household helper: who
// paid whom, as what, how much and for which month, with the declaration. Reads data.json (next to this file). The words
// come from text.json (`t`), the number and date formats from region.json.
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
#align(center, text(size: 14pt, weight: "bold", t.title))
#v(2mm)
#rule()
#v(4mm)

#say(t.certify, (employer: data.employer_name, amount: money(amount), helper: data.helper_name, role: role, month: month))
#if declaration != none [ #declaration]

#t.reimburse

#v(2mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 8mm,
  row-gutter: 5mm,
  [*#t.date:* #fmt-date(data.receipt_date)], align(right)[*#t.payment_method:* #option-label("payment_mode", data.payment_mode)],
  [*#t.helper_name:* #data.helper_name], align(right)[*#t.employer_name:* #data.employer_name],
)
#v(4mm)
#grid(
  columns: (1fr, auto),
  stamp(),
  align(bottom, signature-block(data, t.employer_signature, name: data.employer_name)),
)
