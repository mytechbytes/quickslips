// Donation receipt, design t1: the receipt of an NGO or trust, 160 mm wide: the organisation with its registration, e-mail, website
// and phone, "Donation receipt" with the receipt number and date in a small table, and a ruled table: received from, the amount in
// figures and in words, the payment method, received by, the description of the donation, and a thank-you. The words of the amount
// are written out when the field is empty. Reads data.json (next to this file). The words come from text.json (`t`), the number and
// date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 160mm, margin: (x: 9mm, y: 9mm), size: 10pt)
#set par(leading: 0.6em)
#set block(spacing: 0pt)

#let ink = rgb("#a3243b")
#let navy = rgb("#0b1f8f")
#let frame = 0.7pt + luma(110)
#let words = if some("amount_in_words") != none { some("amount_in_words") } else { amount-words(data.amount) }
#let contact = (
  if some("email") != none { t.email + ": " + some("email") },
  if some("website") != none { t.website + ": " + some("website") },
).filter(part => part != none).join("  |  ")

#align(center)[
  #picture(data, "logo", 14mm)
  #text(size: 16pt, fill: ink, data.organisation_name) \
  #if some("registration_number") != none [#text(size: 8pt, fill: muted, [(#some("registration_number"))]) \ ]
  #text(size: 8pt, lines(data.address)) \
  #if contact != "" [#text(size: 8pt, contact) \ ]
  #if some("phone") != none [#text(size: 10pt, fill: ink, [#t.phone: #some("phone")])]
]
#v(3mm)
#grid(
  columns: (1fr, 62mm),
  align(horizon, text(size: 22pt, weight: "bold", fill: navy, upper(t.donation_receipt))),
  table(
    columns: (1fr, 1.2fr),
    stroke: frame,
    inset: 2.6mm,
    t.receipt_no, data.receipt_number,
    t.date, fmt-date(data.date),
  ),
)
#v(3mm)
#block(width: 100%, stroke: frame, {
  block(width: 100%, inset: 3mm, [#text(size: 11pt, t.received_from) #h(2mm) #text(size: 11pt, weight: "bold", data.donor_name)])
  line(length: 100%, stroke: frame)
  grid(
    columns: (30mm, 1fr, 48%),
    stroke: (x, y) => (right: if x < 2 { frame }),
    inset: 3mm,
    text(size: 11pt, t.amount),
    block(width: 100%, stroke: (bottom: 0.5pt + luma(150)), inset: (bottom: 1mm), text(size: 11pt, money(data.amount))),
    grid.cell(rowspan: 2)[
      #strong(t.payment_method + ":") \
      #v(1mm)
      #text(size: 9pt, option-label("payment_mode", data.payment_mode))
    ],
    text(size: 11pt, t.sum_of_words),
    text(size: 10pt, if words != none { words } else { [] }),
  )
  line(length: 100%, stroke: frame)
  block(width: 100%, inset: 3mm, [#text(size: 11pt, t.received_by) #h(2mm) #if some("received_by") != none [#strong(some("received_by"))]])
  line(length: 100%, stroke: frame)
  block(width: 100%, inset: 3mm, height: 22mm, [#text(size: 11pt, t.description_of_donation) #h(2mm) #if some("donation_description") != none [#some("donation_description")]])
})
#v(4mm)
#align(center, text(size: 8pt, t.thanks))
