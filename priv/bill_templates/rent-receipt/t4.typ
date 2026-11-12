// Rent receipt, design t4: a formal receipt: a table of the landlord, the tenant, the property, the period and the amount,
// the landlord's acknowledgement with the amount in words, three conditions and a signature.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 140mm, margin: (x: 12mm, y: 12mm), size: 9.5pt)
#set par(leading: 0.8em)

#let receipts = salary-periods(data)
#for (i, receipt) in receipts.enumerate() [
#if i > 0 { pagebreak() }
#let month = receipt.label
#let when = receipt.date
#let rent = data.monthly_rent * receipt.months
#let period = receipt.months > 1
#let facts = (
  (t.landlord, data.landlord_name + if opt(data, "landlord_pan") != none { " (PAN: " + opt(data, "landlord_pan") + ")" } else { "" }),
  (t.tenant, data.tenant_name),
  (t.property, lines(data.property_address)),
  (t.rental_period, month),
  (t.amount_received, money(rent)),
  (t.mode, option-label("payment_mode", data.payment_mode)),
  ..if when != none { ((t.receipt_date, fmt-date(when)),) } else { () },
)

#align(center)[
  #text(size: 22pt, weight: "bold", tracking: 1.2pt, upper(t.title)) \
  #text(size: 9pt, style: "italic", fill: muted, t.subtitle)
]
#v(2mm)
#line(length: 100%, stroke: 1.6pt)
#v(3mm)
#table(
  columns: (38mm, 1fr),
  stroke: 0.8pt,
  inset: (x: 2.5mm, y: 1.8mm),
  ..facts.map(((label, value)) => (text(weight: "bold", upper(label)), value)).flatten(),
)
#v(3mm)
#say(t.ack, (landlord: data.landlord_name, amount: money(rent), tenant: data.tenant_name, period: month))
#let words = amount-words-line(rent)
#if words != none { words }

#say(t.premises, (address: data.property_address.replace("\n", ", ")))

#v(1mm)
#line(length: 100%, stroke: (paint: luma(120), thickness: 0.6pt, dash: "dashed"))
#v(1mm)
#text(size: 8.5pt)[
  1. #t.term_1 \
  2. #t.term_2 \
  3. #t.term_3
]
#v(4mm)
#signature-block(data, t.landlord_signature, name: data.landlord_name)
#v(2mm)
#text(size: 8.5pt)[#t.name: #data.landlord_name \ #t.month: #month]
]
