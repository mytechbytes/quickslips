// Hotel bill, design t3: a form in a ruled frame: the registration number on top, a table of the bill number, guest, check-in and
// departure with times, room number and type and nationality, the particulars (days, rate, amount) and the total, the advance, the
// payment method, what is refunded or received, the total in a box, the customer and manager signatures and "E. & O.E". Reads data.json
// (next to this file). The words come from text.json (`t`), the number and date formats from region.json.
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
#show: base.with(width: 129mm, margin: (x: 8mm, y: 8mm), size: 8.5pt)
#set par(leading: 0.55em)
#set block(spacing: 0pt)
#let line-color = luma(40)
#let outline = 0.7pt + line-color
#let reg = if some("registration_number") != none { some("registration_number") } else { some("gstin") }
#let field(label, value, width: 1fr) = [#strong(label) #h(2mm) #if value != none [#value] else [#box(width: 1fr, stroke: (bottom: (paint: luma(100), thickness: 0.5pt, dash: "dotted")), [ ])]]
#let rule-line() = line(length: 100%, stroke: 0.7pt + line-color)

#if reg != none [#align(right, text(size: 7.5pt, [#t.reg_no #reg]))]
#v(2mm)
#block(width: 100%, stroke: outline, {
  block(width: 100%, inset: 2.4mm, field(t.bill_no, data.invoice_number))
  rule-line()
  grid(columns: (1fr, 1fr), stroke: (x, y) => if x > 0 { (left: outline) }, inset: 2.4mm, field(t.guest_name, guest-line), field(t.guest_address, if some("guest_address") != none { lines(some("guest_address")) }))
  rule-line()
  grid(columns: (1fr, 1fr), stroke: (x, y) => if x > 0 { (left: outline) }, inset: 2.4mm, field(t.check_in_date, fmt-date(data.check_in)), field(t.departure_date, fmt-date(data.check_out)))
  rule-line()
  grid(columns: (1fr, 1fr), stroke: (x, y) => if x > 0 { (left: outline) }, inset: 2.4mm, field(t.check_in_time, if some("check_in_time") != none { fmt-time(some("check_in_time")) }), field(t.check_out_time, if some("check_out_time") != none { fmt-time(some("check_out_time")) }))
  rule-line()
  grid(columns: (1fr, 1fr), stroke: (x, y) => if x > 0 { (left: outline) }, inset: 2.4mm, field(t.room_no, some("room_number")), field(t.room_type, room-label))
  rule-line()
  block(width: 100%, inset: 2.4mm, field(t.nationality, some("nationality")))
})
#v(3mm)
#block(width: 100%, stroke: outline, clip: true, {
  table(
    columns: (1fr, auto, auto, auto),
    align: (left, right, right, right),
    stroke: (x, y) => (bottom: if y < 1 { outline }, left: if x > 0 { 0.5pt + line-color }),
    inset: 2.4mm,
    ..(t.particular, t.days, t.rate, t.amount).map(head => text(weight: "bold", head)),
    [#t.room_tariff, #room-label#if some("room_description") != none [ — #some("room_description")]], [#nights], money(data.tariff_per_night), money(room),
    ..more.map(row => (row.name, [#fmt-number(row.qty)], money(row.rate), money(row.amount))).flatten(),
    ..if extras > 0 { (t.extra, [], [], money(extras)) } else { () },
    ..for (name, percentage, amount) in tax-parts(if rate == 0 { none } else { rate }, tax) { ([#name #fmt-number(percentage)%], [], [], money(amount)) },
  )
  line(length: 100%, stroke: 1.4pt + line-color)
  grid(columns: (1fr, auto), inset: 2.4mm, t.total, strong(money(total)))
})
#v(3mm)
#grid(columns: (1fr, auto), inset: (y: 2mm), upper(t.less_advance), money(advance))
#line(length: 100%, stroke: 0.7pt + line-color)
#grid(columns: (1fr, auto), inset: (y: 2mm), t.payment_method, option-label("payment_mode", data.payment_mode))
#line(length: 100%, stroke: 0.7pt + line-color)
#grid(columns: (1fr, auto), inset: (y: 2mm), upper(t.refunded_received), money(due))
#line(length: 100%, stroke: 0.7pt + line-color)
#v(3mm)
#block(width: 100%, stroke: outline, inset: 3.5mm, grid(columns: (1fr, auto), strong(t.total_amount + ":"), strong(money(total))))
#v(5mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  [
    #v(11mm)
    #line(length: 32mm, stroke: 0.6pt)
    #v(1mm)
    #text(size: 7.5pt, t.customer_signature)
  ],
  align(right)[
    #picture(data, "signature", 11mm) \
    #box(width: 40mm, stroke: (top: 0.6pt), inset: (top: 1mm), text(size: 7.5pt, t.manager_signature))
  ],
)
#v(3mm)
#grid(columns: (1fr, auto), t.thanks, t.eoe)
