// Hotel bill, design t2: a tax invoice in frames: the tax id on top, "Tax invoice", a box with the bill, the guest and the room details, a
// grey-headed table of the rooms (type, description, rate, nights, subtotal), the subtotal and the tax, a line with the receipt, the
// total, the advance and what is received, the receptionist and the guest signature. Reads data.json (next to this file). The words
// come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#let india = region.country == "in"

// The money: the nights at the tariff, the other rooms or services, and the food and other charges make the subtotal; the tax is
// added to it, or is part of it where the country says so; the advance is taken off the total.
#let nights = days-between(data.check_in, data.check_out)
#let room = nights * data.tariff_per_night
#let more = item-rows(data)
#let more-total = sum-of(more.map(row => row.amount))
#let extras = num(data, "extra_charges")
#let subtotal = room + more-total + extras
#let rate = num(data, "gst_percent")
#let split = tax-split(subtotal, rate)
#let tax = calc.round(split.tax, digits: 2)
#let shown-subtotal = split.base
#let total = if tax-mode == "included" { subtotal } else { subtotal + tax }
#let advance = num(data, "advance_amount")
#let due = total - advance
#let room-label = option-label("room_type", data.room_type)
#let stamp(date-key, time-key) = [#fmt-date(data.at(date-key))#if some(time-key) != none [ #fmt-time(some(time-key))]]
#let guest-line = {
  let parts = ()
  if some("guest_gender") != none { parts.push(option-label("guest_gender", some("guest_gender"))) }
  if some("guest_age") != none { parts.push(some("guest_age")) }
  if parts.len() == 0 { data.guest_name } else { [#data.guest_name (#parts.join(", "))] }
}
#show: base.with(width: 140mm, margin: (x: 8mm, y: 8mm), size: 8.5pt)
#set par(leading: 0.55em)
#set block(spacing: 0pt)
#let frame = 0.8pt + luma(190)
#let kv(label, value) = if value != none [#strong(label) #h(2mm) #value \ ]
#let pair(label, value) = if value != none { grid(columns: (1fr, auto), column-gutter: 3mm, strong(label), align(right, value)); v(1.6mm) }

#block(width: 100%, stroke: frame, radius: 1.5mm, inset: 3mm, align(right, [
  #if some("gstin") != none [#strong(tax-id-label + ":") #some("gstin")] else [#strong(data.hotel_name)]
]))
#v(2mm)
#align(center, text(size: 11pt, weight: "bold", upper(t.tax_invoice)))
#v(1mm)
#line(length: 100%, stroke: 1.4pt + luma(40))
#v(2mm)
#block(width: 100%, stroke: frame, radius: 1.5mm, inset: 3mm, grid(
  columns: (1fr, 1fr),
  column-gutter: 6mm,
  [
    #picture(data, "logo", 9mm)
    #strong(t.bill_no + ":") #data.invoice_number \
    #v(1mm)
    #strong(t.guest_name + ":") #guest-line \
    #v(1mm)
    #if some("guest_address") != none [#strong(t.address + ":") #lines(some("guest_address"))]
  ],
  [
    #pair(t.res_no, if some("reservation_number") != none { some("reservation_number") } else { data.invoice_number })
    #pair(t.room_no, some("room_number"))
    #pair(t.room_type, room-label)
    #pair(t.check_in, stamp("check_in", "check_in_time"))
    #pair(t.check_out, stamp("check_out", "check_out_time"))
    #pair(t.pay_type, option-label("payment_mode", data.payment_mode))
    #pair(t.nationality, some("nationality"))
  ],
))
#v(3mm)
#table(
  columns: (auto, 1fr, auto, auto, auto),
  align: (left, left, right, right, right),
  stroke: 0.6pt + luma(190),
  fill: (_, y) => if y == 0 { luma(205) },
  inset: 2mm,
  ..(t.room_type, t.room_description, t.rate, t.days_nights, t.subtotal).map(head => text(size: 7pt, weight: "bold", upper(head))),
  room-label, if some("room_description") != none { some("room_description") } else { t.room_tariff }, money(data.tariff_per_night), [#nights], money(room),
  ..more.map(row => ([], row.name, money(row.rate), [#fmt-number(row.qty)], money(row.amount))).flatten(),
  ..if extras > 0 { ([], t.extra, [], [], money(extras)) } else { () },
)
#block(width: 100%, stroke: (left: frame, right: frame, bottom: frame), inset: 2.5mm, {
  pair(t.subtotal, strong(money(shown-subtotal)))
  for (name, percentage, amount) in tax-parts(if rate == 0 { none } else { rate }, tax) { pair([#name #fmt-number(percentage)%], money(amount)) }
})
#v(3mm)
#grid(
  columns: (1fr, 30mm),
  column-gutter: 4mm,
  [
    #table(
      columns: (auto, auto, auto, auto),
      stroke: (x, y) => (bottom: if y == 0 { (paint: luma(120), thickness: 0.5pt, dash: "dashed") }),
      inset: 1.6mm,
      ..(t.receipt_no, t.check_in_date, t.total_amount, t.payment_type).map(head => text(size: 6.8pt, weight: "bold", head)),
      text(size: 7.5pt, data.invoice_number), text(size: 7.5pt, fmt-date(data.check_in)), text(size: 7.5pt, money(total)), text(size: 7.5pt, option-label("payment_mode", data.payment_mode)),
    )
    #v(3mm)
    #strong(t.total_amount + ":") #h(8mm) #strong(money(total))
  ],
  block(width: 100%, stroke: frame, radius: 1.5mm, inset: 2.5mm)[
    #text(size: 7pt, strong(t.less_advance + ":")) \ #money(advance) \ #v(1.5mm)
    #text(size: 7pt, strong(t.receive + ":")) \ #money(calc.max(due, 0)) \ #v(1.5mm)
    #text(size: 7pt, strong(t.payment_received + ":")) \ #strong(money(calc.max(due, 0)))
  ],
)
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  [
    #picture(data, "signature", 11mm)
    #line(length: 32mm, stroke: 0.6pt)
    #v(1mm)
    #text(size: 7.5pt, strong(t.receptionist))
  ],
  align(right)[
    #v(11mm)
    #box(width: 32mm, stroke: (top: 0.6pt), inset: (top: 1mm), text(size: 7.5pt, strong(t.guest_signature)))
  ],
)
#v(2mm)
#text(size: 9pt, weight: "bold", t.thank_visit)
