// Daily helper receipt, design t3: the employer's own declaration that the helper was paid, and the helper's receipt of the
// money below it, with the revenue stamp.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 150mm, margin: (x: 13mm, y: 12mm), size: 10pt)
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
#let month = receipt.label
#let when = receipt.date
#let memo = receipt.number
#let net = net * receipt.months

#align(center, text(size: 14pt, weight: "bold", t.title))
#v(3mm)
#let address = opt(data, "employer_address")
#say(t.certify_self, (amount: money(net), helper: data.helper_name, role: role, month: month))
#if declaration != none [ #declaration]
#t.reimburse
#v(2mm)
#if memo != none [*#t.memo_number:* #memo \ ]*#t.employer_name:* #data.employer_name#if address != none [ \ *#t.employer_address:* #lines(address)]#if when != none [ \ *#t.date:* #fmt-date(when)]

#grid(
  columns: (1fr, auto),
  [],
  align(bottom, signature-block(data, t.employer_signature, name: employee)),
)

#v(1mm)
#line(length: 100%, stroke: 1.4pt)
#v(3mm)
#align(center, text(size: 12pt, weight: "bold", t.ack_title))
#v(2mm)
#if memo != none [*#t.memo_number:* #memo \ ]
#if when != none [*#t.receipt_date_of:* #fmt-date(when) \ ]
*#t.for_month:* #month \
*#t.helper_name:* #data.helper_name \
#v(1mm)
#say(t.received_sum, (amount: money(net), month: month, employer: data.employer_name))
#v(3mm)
#grid(
  columns: (1fr, auto),
  stamp(),
  align(bottom, signature-block(data, t.ack_thumb, key: "driver_signature")),
)
#align(right)[*#t.helper_name:* #data.helper_name]
]
