// Recharge bill, design t1: the tax invoice of a mobile, phone or DTH connection, 120 mm wide, in one of four colour themes (red, blue,
// yellow, green): the invoice and the account on two sides, a banner, the account summary in six rounded cards, the charge of the month,
// an offer, a note about the tax, the ways to pay and the provider, and an acknowledgement slip to detach. The tax is added to the
// charge, or is part of it where the country says so. Reads data.json (next to this file). The words come from text.json (`t`),
// the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 120mm, margin: (x: 7mm, y: 7mm), size: 8.5pt)
#set par(leading: 0.55em)
#set block(spacing: 0pt)

// The colours of the themes; yellow takes dark letters on its bars.
#let themes = (
  Red: (rgb("#e03a2c"), white, rgb("#e03a2c")),
  Blue: (rgb("#1e5fbf"), white, rgb("#1e5fbf")),
  Yellow: (rgb("#f2b400"), luma(30), rgb("#9a6b00")),
  Green: (rgb("#2b9a4d"), white, rgb("#2b9a4d")),
)
#let theme = themes.at(data.at("theme", default: "Red"), default: themes.Red)
#let accent = theme.at(0)
#let on-accent = theme.at(1)
#let ink = theme.at(2)

#let charge = data.amount
#let rate = some("tax_percent")
#let split = if rate != none { tax-split(charge, rate) } else { (base: charge, tax: 0, total: charge) }
#let taxable = split.base
#let tax = calc.round(split.tax, digits: 2)
#let this-month = if tax-mode == "included" { charge } else { charge + tax }
#let previous = num(data, "previous_balance")
#let adjustment = num(data, "adjustment")
#let total = calc.max(0, previous + this-month - adjustment)
#let bar(body) = block(width: 100%, fill: accent, radius: 1mm, inset: (x: 3mm, y: 2.2mm), text(fill: on-accent, body))
#let section(label) = text(size: 10pt, weight: "bold", fill: ink, label)
#let kv(label, value) = if value != none { grid(columns: (auto, 1fr), column-gutter: 2mm, label, align(right, strong(value))) ; v(1.6mm) }
#let card(label, value) = box(width: 100%, fill: luma(244), radius: 3mm, inset: (x: 1.5mm, y: 2.4mm), align(center)[
  #text(size: 6.5pt, fill: muted, label) \
  #v(1mm)
  #text(weight: "bold", value)
])
#let rows-of(key) = if some(key) != none { some(key).split("\n").filter(line => line != "") } else { () }
#let stamp-time = if some("time") != none { fmt-time(some("time")) }

#align(right, text(size: 9pt, weight: "bold", fill: ink, t.original_copy))
#v(1mm)
#line(length: 100%, stroke: 0.5pt + hairline)
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 6mm,
  [
    #picture(data, "logo", 10mm)
    #strong([#t.invoice_no: #data.invoice_number]) \
    #option-label("service", data.service)
    #v(2mm)
    #text(size: 7pt, fill: muted, upper(t.billed_to)) \
    #strong(data.customer_name)
    #if some("customer_address") != none [ \ #lines(some("customer_address"))]
    #if some("landmark") != none [ \ #text(fill: muted, some("landmark"))]
  ],
  [
    #kv(t.customer_id, data.customer_id)
    #kv(t.mobile_no, data.mobile_number)
    #kv(t.bill_no, data.invoice_number)
    #kv(t.bill_date, fmt-date(data.bill_date))
    #kv(t.bill_cycle, option-label("bill_cycle", data.bill_cycle))
    #kv(t.bill_period, text(size: 7.3pt, [#fmt-date(data.period_start) #t.to #fmt-date(data.period_end)]))
    #kv(t.pay_by, option-label("payment_in", data.payment_in))
    #kv(t.alt_no, some("alternative_number"))
    #kv(t.email, some("email"))
  ],
)
#v(2mm)
#if some("email_banner") != none { bar(some("email_banner")); v(3mm) }
#section(t.account_summary)
#v(2.5mm)
#grid(
  columns: (1fr,) * 3,
  column-gutter: 2mm,
  row-gutter: 2mm,
  card(t.previous_bill, money(previous)),
  card(t.adjustment, money(adjustment)),
  card(t.this_month, money(this-month)),
  card(t.service, option-label("service", data.service)),
  card(t.after_due, if some("amount_after_due") != none { money(some("amount_after_due")) } else { "-" }),
  card(t.payment_method, option-label("payment_mode", data.payment_mode)),
)
#v(3mm)
#section(t.month_charge)
#v(2.5mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 6mm,
  {
    kv(t.monthly_charges, money(charge))
    if rate != none { kv(t.tax + ":", [#fmt-number(rate)%]) }
    kv(t.taxable_amount, money(taxable))
    kv(t.bill_cycle, option-label("bill_cycle", data.bill_cycle))
    kv(t.bill_from, fmt-date(data.period_start))
    line(length: 100%, stroke: 0.5pt + hairline)
    v(1mm)
    grid(columns: (1fr, auto), strong(t.total_amount), strong(money(total)))
  },
  align(center + horizon)[
    #if some("offer_title") != none [#text(size: 12pt, weight: "bold", fill: ink, some("offer_title")) \ ]
    #if some("offer_text") != none [#text(size: 8pt, fill: ink, some("offer_text"))]
  ],
)
#if rate != none [
  #v(2mm)
  #text(size: 7.5pt, say(t.tax_note, (rate: fmt-number(rate), tax: tax-name)))
]
#v(3mm)
#line(length: 100%, stroke: (paint: luma(160), thickness: 0.6pt, dash: "dashed"))
#v(0.5mm)
#align(center, text(size: 7pt, fill: muted, "— — — — " + t.detach + " — — — —"))
#v(0.5mm)
#line(length: 100%, stroke: (paint: luma(160), thickness: 0.6pt, dash: "dashed"))
#v(2.5mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 4mm,
  block(width: 100%, stroke: 1.2pt + accent, radius: 2.5mm, inset: 3mm)[
    #text(weight: "bold", fill: ink, t.pay_on_go)
    #for line in rows-of("pay_options") [ \ #v(0.6mm) #line]
  ],
  block(width: 100%, stroke: 1.2pt + accent, radius: 2.5mm, inset: 3mm)[
    #text(weight: "bold", fill: ink, t.provider_details) \
    #v(0.6mm)
    #strong(data.provider_name)
    #if some("provider_address") != none [ \ #lines(some("provider_address"))]
    #if some("seller_tax_id") != none [ \ #tax-id-label: #some("seller_tax_id")]
    \ #option-label("service", data.service)
  ],
)
#v(3mm)
#align(center, bar(strong(t.acknowledgement)))
#v(2mm)
#grid(
  columns: (auto, auto, auto),
  column-gutter: 5mm,
  row-gutter: 1.5mm,
  [#strong(t.customer_id + ":") #data.customer_id],
  [#strong(t.customer_name + ":") #data.customer_name],
  [#strong(t.amount + ":") #money(total)],
  [#strong(t.invoice_no + ":") #data.invoice_number],
  [#strong(t.service + ":") #option-label("service", data.service)],
)
#v(2mm)
#text(size: 6.5pt, fill: muted, if stamp-time != none { say(t.computer_generated, (date: fmt-date(data.bill_date), time: stamp-time)) } else { say(t.computer_generated_date, (date: fmt-date(data.bill_date))) })
