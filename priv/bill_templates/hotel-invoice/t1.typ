// Hotel bill, design t1: a plain invoice on A4: the hotel and "Invoice", the bill details and the guest, a table of the room tariff, the
// other rooms and services and the food, the totals with the tax and the advance, and the signatory. Reads data.json (next to this
// file). The words come from text.json (`t`), the number and date formats from region.json.
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
#show: base.with(paper: "a4", margin: 18mm, size: 10.5pt)

#letterhead(
  data,
  data.hotel_name,
  address: some("hotel_address"),
  gstin: some("gstin"),
  title: t.invoice_title,
)

#details(
  (
    (t.invoice_no, data.invoice_number),
    (t.invoice_date, fmt-date(data.invoice_date)),
    (t.guest, guest-line),
    (t.room, [#room-label#if some("room_number") != none [ (#t.no #some("room_number"))]]),
    (t.check_in, stamp("check_in", "check_in_time")),
    (t.check_out, stamp("check_out", "check_out_time")),
    (t.reservation_no, some("reservation_number")),
    (t.nationality, some("nationality")),
  ),
  columns: 3,
)

#if some("guest_address") != none [
  #v(3mm)
  #details(((t.guest_address, lines(some("guest_address"))),), columns: 1)
]

#v(8mm)
#bill-table(
  (t.description, t.nights, t.rate_per_night, t.amount),
  (
    ([#t.room_tariff, #room-label#if some("room_description") != none [ — #some("room_description")]], [#nights], [#money(data.tariff_per_night)], [#money(room)]),
    ..more.map(row => ([#row.name], [#fmt-number(row.qty)], [#money(row.rate)], [#money(row.amount)])),
    ..if extras > 0 { (([#t.extra], [], [], [#money(extras)]),) } else { () },
  ),
)

#v(3mm)
#totals(((t.subtotal, shown-subtotal), ((if india { "GST" } else { tax-name }) + " (" + fmt-number(rate) + "%)", tax), (t.less_advance, advance)), due, label: if advance > 0 { t.balance_due } else { t.total })

#v(14mm)
#signature-block(data, t.authorised, name: data.hotel_name)

#footnote(t.thanks_stay)
