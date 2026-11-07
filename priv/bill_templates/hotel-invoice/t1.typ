// Hotel invoice, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a4", margin: 18mm, size: 10.5pt)

#let nights = days-between(data.check_in, data.check_out)
#let room = nights * data.tariff_per_night
#let extras = num(data, "extra_charges")
#let tax-rate = num(data, "gst_percent")
#let tax = percent(room + extras, tax-rate)
#let total = room + extras + tax

#letterhead(
  data,
  data.hotel_name,
  address: opt(data, "hotel_address"),
  gstin: opt(data, "gstin"),
  title: "Invoice",
)

#details(
  (
    ([Invoice no.], data.invoice_number),
    ([Invoice date], fmt-date(data.invoice_date)),
    ([Guest], data.guest_name),
    ([Room], [#data.room_type#if opt(data, "room_number") != none [ (no. #opt(data, "room_number"))]]),
    ([Check-in], fmt-date(data.check_in)),
    ([Check-out], fmt-date(data.check_out)),
  ),
  columns: 3,
)

#if opt(data, "guest_address") != none [
  #v(3mm)
  #details((([Guest address], lines(opt(data, "guest_address"))),), columns: 1)
]

#v(8mm)
#bill-table(
  ([Description], [Nights], [Rate per night], [Amount]),
  (
    ([Room tariff, #data.room_type], [#nights], [#money(data.tariff_per_night)], [#money(room)]),
    ..if extras > 0 { (([Food and other charges], [], [], [#money(extras)]),) } else { () },
  ),
)

#v(3mm)
#totals((([Subtotal], room + extras), ([#tax-name (#tax-rate%)], tax)), total)

#v(14mm)
#signature-block(data, [Authorised signatory], name: data.hotel_name)

#footnote[Thank you for staying with us. This is a computer generated invoice.]
