// Rent receipt, design t2: the receipt, and below it an acknowledgement slip for the landlord or the manager who received
// the rent to keep.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 160mm, margin: (x: 14mm, y: 13mm), size: 10pt)
#set par(leading: 0.75em)

#let rent = data.monthly_rent
#let month = month-label(data.month)
#let receiver = opt(data, "receiver_name")
#let receiver = if receiver == none { data.landlord_name } else { receiver }
#let role = option-label("received_by", data.at("received_by", default: "Landlord"))
#let stamp = if region.country == "in" {
  revenue-stamp(data, t.revenue_stamp, width: 22mm, height: 26mm)
}
#let heading(content) = align(center, block(text(size: 12pt, weight: "bold", content) + v(0.6mm) + line(length: 100%, stroke: 0.7pt)))

#align(right)[#t.date: #fmt-date(data.receipt_date)]
#v(1mm)
#align(center, box(width: 55mm, heading(t.title)))
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  [*#t.rent_month:* \ #month],
  align(right)[*#t.rental_address:* \ #lines(data.property_address)],
)
#v(3mm)
#say(t.received_text, (tenant: data.tenant_name, amount: money(rent), month: month, role: role, receiver: receiver))
#v(3mm)
#grid(
  columns: (1fr, auto),
  [*#t.tenant_name:* #data.tenant_name],
  [*#t.date:* #fmt-date(data.receipt_date)],
)

#v(4mm)
#line(length: 100%, stroke: (paint: luma(120), thickness: 0.7pt, dash: "dashed"))
#v(4mm)
#align(center, box(width: 70mm, heading(t.ack_title)))
#v(2mm)
#grid(
  columns: (1fr, auto, auto),
  column-gutter: 8mm,
  [*#t.rent_month:* \ #month], [*#t.amount:* #money(rent)], [*#t.date:* #fmt-date(data.receipt_date)],
)
#v(3mm)
*#t.received_from:* #data.tenant_name \
*#t.landlord:* #data.landlord_name#if opt(data, "landlord_pan") != none [ (PAN: #opt(data, "landlord_pan"))]
#v(3mm)
#grid(
  columns: (1fr, 1fr, 1fr),
  column-gutter: 6mm,
  align: (left + top, center + top, right + top),
  stamp,
  [*#t.receivers_name:* \ #receiver],
  [*#t.received_by:* \ #role],
)
#v(2mm)
#signature-block(data, t.landlord_signature, name: receiver)
