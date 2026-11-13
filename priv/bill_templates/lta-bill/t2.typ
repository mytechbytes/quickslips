// LTA bill, design t2: a bus e-ticket in boxes: a pale yellow banner, the operator, the type and the LTA month, the ticket, PNR and
// journey date, the boarding and dropping points, the reporting date, departure time, passengers and seats, the passenger, the payment,
// an important note beside the fare (base, tax, total), the terms and the cancellation table. Reads data.json (next to this file).
// The words come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 120mm, margin: (x: 7mm, y: 7mm), size: 8.5pt)
#set par(leading: 0.55em)

#let rate = num(data, "tax_percent")
#let split = tax-split(data.amount, rate)
#let base-fare = split.base
#let tax = calc.round(split.tax, digits: 2)
#let total-fare = split.total
#let cancel = num(data, "cancellation_charge")
#let dep-time = if some("departure_time") != none { fmt-time(some("departure_time")) } else { "-" }
#let drop-time = if some("dropping_time") != none { fmt-time(some("dropping_time")) } else { "-" }
#let reporting = fmt-date(data.reporting_date)
#let dropping = fmt-date(data.dropping_date)
#let kv(label, value) = if value != none [#strong(label + ":") #value \ ]
#let cutoff = [#reporting #if some("departure_time") != none [#dep-time]]
#let box-frame = 0.7pt + luma(190)

#let lta-month = months.at(to-date(data.reporting_date).month() - 1)
#let cell-box(body) = block(width: 100%, stroke: box-frame, radius: 1.5mm, inset: 3mm, body)
#let labelled(label, value) = [#text(size: 7.5pt, fill: muted, label) \ #strong(value)]

#block(width: 100%, fill: rgb("#fbf3b3"), inset: 2.5mm, align(center, text(weight: "bold", say(t.t2_banner, (when: [#cutoff])))))
#v(3mm)
#grid(
  columns: (auto, 1fr, auto),
  column-gutter: 4mm,
  box(width: 16mm, height: 16mm, stroke: box-frame, radius: 1mm, picture(data, "logo", 14mm)),
  [
    #text(size: 12pt, weight: "bold", data.travel_name) \
    #text(size: 8pt, fill: muted)[#t.type: #option-label("travel_type", data.travel_type) \ #t.lta_month: #lta-month]
  ],
  align(right)[
    #text(size: 13pt, weight: "bold", upper(t.eticket)) \
    #strong(t.boarding_help + ":") #data.boarding_phone \
    #strong(t.customer_care + ":") #data.customer_care
  ],
)
#v(3mm)
#cell-box(grid(
  columns: (1fr, 1fr, 1fr),
  column-gutter: 3mm,
  labelled(t.ticket_no, data.ticket_number),
  labelled(t.pnr_no, if some("pnr_number") != none { some("pnr_number") } else { "N/A" }),
  ..if some("order_number") != none { (labelled(t.order_number, some("order_number")),) } else { () },
  labelled(t.journey_date, reporting),
))
#v(2.5mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 3mm,
  cell-box[
    #text(weight: "bold", upper(t.boarding_point)) \ #v(1mm)
    #kv(t.location, lines(data.location))
    #kv(t.landmark, lines(data.landmark))
    #kv(t.address, lines(data.boarding_address))
  ],
  cell-box[
    #text(weight: "bold", upper(t.dropping_point)) \ #v(1mm)
    #kv(t.date, dropping)
    #kv(t.time, drop-time)
    #kv(t.address, lines(data.dropping_address))
  ],
)
#v(2.5mm)
#cell-box(grid(
  columns: (1fr, 1fr, 1fr, 1fr),
  column-gutter: 3mm,
  labelled(t.reporting_date, reporting), labelled(t.departure_time, dep-time), labelled(t.passengers, data.passenger_count), labelled(t.seat_count, data.seat_number),
))
#v(2.5mm)
#cell-box[#text(weight: "bold", upper(t.passenger_details_title)) \ #v(1mm) #data.passenger_details]
#v(2.5mm)
#cell-box[#text(weight: "bold", upper(t.payment_method)) \ #v(1mm) #option-label("payment_mode", data.payment_mode)]
#v(2.5mm)
#grid(
  columns: (1fr, 1.4fr),
  column-gutter: 3mm,
  cell-box(text(size: 7.5pt)[
    #text(weight: "bold", size: 8.5pt, upper(t.important_note)) \ #v(1mm)
    #t.note_mticket \ #v(1mm)
    #t.note_id \ #v(1mm)
    #t.note_changes
  ]),
  block(width: 100%, stroke: box-frame, radius: 1.5mm, clip: true, grid(
    columns: (1fr, auto),
    stroke: (x, y) => (bottom: if y < 2 { box-frame }),
    inset: 3mm,
    row-gutter: 0mm,
    [#t.base_fare], align(right, strong(money(base-fare))),
    [#t.tax (#fmt-number(rate)%)], align(right, strong(money(tax))),
    text(size: 10pt, weight: "bold", t.total_fare), align(right, text(size: 10pt, weight: "bold", money(total-fare))),
  )),
)
#v(3mm)
#line(length: 100%, stroke: 0.6pt + hairline)
#v(2mm)
#align(center, text(size: 10pt, weight: "bold", upper(t.terms)))
#v(2mm)
#grid(
  columns: (1.3fr, 1fr),
  column-gutter: 4mm,
  text(size: 7pt)[
    #t.t2_term_1 \ #v(1mm)
    #t.t2_term_2 \ #v(1mm)
    #t.t2_term_3 \ #v(1mm)
    #t.t2_term_4
  ],
  table(
    columns: (1fr, 1fr),
    stroke: box-frame,
    inset: 2mm,
    ..(t.cancel_window, t.applicable_charge).map(head => text(size: 7pt, weight: "bold", head)),
    text(size: 7pt)[#t.after #dropping #dep-time], text(size: 7pt, weight: "bold", money(total-fare)),
    text(size: 7pt)[#t.before #dropping #dep-time], text(size: 7pt, weight: "bold", money(cancel)),
  ),
)
