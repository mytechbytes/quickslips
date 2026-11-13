// LTA bill, design t1: a bus e-ticket for a leave travel allowance claim: a yellow banner about rescheduling, the e-ticket with the
// operator's help numbers, the ticket number, the date, time and passengers, the boarding and dropping points in two boxes, the
// passenger, the seat, the note about the mobile ticket, the fare with the tax, the terms and the cancellation charges. Reads
// data.json (next to this file). The words come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let on-sheet = data.at("paper_size", default: none) != none
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

#block(width: 100%, fill: rgb("#fff176"), inset: 2.5mm, text(weight: "bold", say(t.t1_banner, (when: [#cutoff]))))
#v(3mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 4mm,
  [
    #picture(data, "logo", 10mm)
    #text(size: 13pt, weight: "bold", t.eticket) \
    #text(fill: muted, [#t.type: #option-label("travel_type", data.travel_type)]) \
    #text(size: 8pt, fill: muted, data.travel_name)
  ],
  align(right)[
    #strong(t.need_help) \
    #strong(t.boarding_phone + ":") #data.boarding_phone \
    #strong(t.customer_care + ":") #data.customer_care
    #if some("seller_tax_id") != none [ \ #tax-id-label: #some("seller_tax_id")]
  ],
)
#v(2mm)
#line(length: 100%, stroke: 0.6pt + hairline)
#v(2mm)
#grid(
  columns: (1fr, auto),
  text(fill: muted, [→ #h(3mm) #reporting]),
  align(right)[#strong(t.ticket_no + ":") #data.ticket_number #if some("pnr_number") != none [ \ #strong(t.pnr_no + ":") #some("pnr_number")]#if some("order_number") != none [ \ #strong(t.order_number + ":") #some("order_number")]],
)
#v(2mm)
#line(length: 100%, stroke: 0.6pt + rgb("#e7c93a"))
#v(3mm)
#grid(
  columns: (1fr, 1fr, 1fr),
  align: center,
  [#text(weight: "bold", size: 10pt, reporting) \ #text(size: 7.5pt, fill: muted, t.reporting_date)],
  [#text(weight: "bold", size: 10pt, dep-time) \ #text(size: 7.5pt, fill: muted, t.departure_time)],
  [#text(weight: "bold", size: 10pt, data.passenger_count) \ #text(size: 7.5pt, fill: muted, t.no_passengers)],
)
#v(3mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 4mm,
  block(width: 100%, stroke: box-frame, radius: 1.5mm, inset: 3mm)[
    #text(weight: "bold", upper(t.boarding_point)) \
    #v(1mm)
    #kv(t.location, lines(data.location))
    #kv(t.landmark, lines(data.landmark))
    #kv(t.address, lines(data.boarding_address))
  ],
  block(width: 100%, stroke: box-frame, radius: 1.5mm, inset: 3mm)[
    #text(weight: "bold", upper(t.dropping_point)) \
    #v(1mm)
    #kv(t.time, drop-time)
    #kv(t.date, dropping)
    #kv(t.address, lines(data.dropping_address))
  ],
)
#v(4mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 4mm,
  [#strong(t.passenger_details) \ #data.passenger_details],
  [#strong(t.seat_number + ":") #data.seat_number],
)
#v(2mm)
#line(length: 100%, stroke: 0.5pt + hairline)
#v(1.5mm)
#text(size: 7.5pt, fill: muted, t.mticket_note)
#v(1.5mm)
#line(length: 100%, stroke: 0.5pt + hairline)
#v(3mm)
#text(size: 11pt, weight: "bold", [#t.total_fare: #money(total-fare)]) \
#text(size: 7.5pt, fill: muted, say(t.gst_note, (rate: fmt-number(rate), tax: tax-name)))
#v(1.5mm)
#kv(t.net_amount, money(base-fare))
#kv(t.taxable_amount, money(base-fare))
// In the browser preview the next part is a page of its own.
#if preview and not on-sheet { pagebreak(weak: true) }
#v(3mm)
#align(center, text(size: 10pt, weight: "bold", t.terms))
#v(2mm)
#grid(
  columns: (1.3fr, 1fr),
  column-gutter: 4mm,
  text(size: 7pt)[
    #t.t1_term_0 \ #v(1mm)
    #t.t1_term_1 \ #v(1mm)
    #t.t1_term_2 \ #v(1mm)
    #t.t1_term_3 \ #v(1mm)
    #t.t1_term_4
  ],
  table(
    columns: (1fr, 1fr),
    stroke: box-frame,
    inset: 2mm,
    ..(t.cancel_time, t.cancel_charges).map(head => text(size: 7pt, weight: "bold", head)),
    text(size: 7pt)[#t.after #dep-time #t.on #dropping], text(size: 7pt, money(total-fare)),
    text(size: 7pt)[#t.before #dep-time #t.on #dropping], text(size: 7pt)[#say(t.cut_as_charges, (amount: money(cancel)))],
  ),
)
