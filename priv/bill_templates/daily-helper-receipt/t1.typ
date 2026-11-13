// Daily helper receipt, design t1: the certificate an employee hands in to be reimbursed for the pay of the helper: who paid
// whom, how much and for which month, with the declaration. Reads data.json (next to this file). The words come from
// text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paged: true, width: 150mm, margin: (x: 13mm, y: 12mm), size: 10pt)
#set par(leading: 0.75em)

// What the helper is paid in a month, and the revenue stamp (stuck on a receipt in India only).
#let net = data.salary
#let stamp(width: 24mm, height: 28mm) = if region.country == "in" {
  revenue-stamp(data, t.revenue_stamp, width: width, height: height)
}
#let role = data.working_as
#let declaration = opt(data, "declaration")
#let employee = data.employer_name
// A receipt for each month chosen, or one for the quarter, half-year or year (see `salary-periods` of the helpers), one on
// each page of the PDF.
#let receipts = salary-periods(data)
#for (i, receipt) in receipts.enumerate() [
#if i > 0 { pagebreak() }
#fit-page[
#let month = receipt.label
#let when = receipt.date
#let memo = receipt.number
#let net = net * receipt.months
#v(1mm)
#align(center, text(size: 14pt, weight: "bold", t.title))
#v(2mm)
#rule()
#v(4mm)

#let period = receipt.months > 1
#let address = opt(data, "employer_address")
#say(if period { t.certify_plain_period } else { t.certify_plain }, (amount: money(net), helper: data.helper_name, role: role, month: month))
#if declaration != none [ #v(1mm) #lines(declaration)]
#v(1mm)
#t.ack_reimburse
#v(1mm)
#t.ack_further

#v(2mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 8mm,
  row-gutter: 5mm,
  [*#t.employer_name:* #data.employer_name#if address != none [ \ *#t.employer_address:* #lines(address)]],
  if when != none or memo != none { align(right)[#if memo != none [*#t.memo_number:* #memo \ ]#if when != none [*#t.date:* #fmt-date(when)]] } else [],
  [*#t.helper_name:* #data.helper_name], [],
)
#v(4mm)
#grid(
  columns: (1fr, auto),
  stamp(),
  align(bottom, signature-block(data, t.employer_signature, name: employee)),
)
]
]
