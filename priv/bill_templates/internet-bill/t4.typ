// Internet bill, design t4: a statement with an orange line: the invoice number, date and billing cycle on the right, a greeting, the
// invoice total, the currency, the payment method and the account number, a row of the amount, the tax and the payments received, the
// plan summary, the provider's mailing address and the terms and conditions in an orange box. Reads data.json (next to this file). The
// words come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#let india = region.country == "in"

// The money: the plan, the other charges and the discount make the subtotal; the tax is added to it, or is part of it where the
// country says so.
#let plan = data.plan_charge
#let other = num(data, "other_charges")
#let discount = num(data, "discount")
#let rate = num(data, "gst_percent")
#let subtotal = plan + other - discount
#let included = tax-mode == "included"
#let split = tax-split(subtotal, rate)
#let taxable = split.base
#let tax = calc.round(split.tax, digits: 2)
#let total = if included { subtotal } else { subtotal + tax }
#let paid = num(data, "payments_received")
#let cycle = [#fmt-date(data.period_start) – #fmt-date(data.period_end)]
#let half(amount) = calc.round(amount / 2, digits: 2)
#let tax-heads = if india { (("CGST " + t.rate_pct, "CGST " + t.amount), ("SGST " + t.rate_pct, "SGST " + t.amount)) } else { ((tax-name + " " + t.rate_pct, tax-name + " " + t.amount),) }
#let tax-values = if india { (fmt-number(rate / 2) + "%", money(half(tax)), fmt-number(rate / 2) + "%", money(tax - half(tax))) } else { (fmt-number(rate) + "%", money(tax)) }
#let tax-head-cells = tax-heads.map(pair => pair).flatten()

// The plan as columns: the plan, and its speed, package and validity where they are given.
#let plan-columns = {
  let columns = ((t.plan, data.plan_name),)
  if some("plan_speed") != none { columns.push((t.plan_speed, some("plan_speed"))) }
  if some("plan_package") != none { columns.push((t.plan_package, option-label("plan_package", some("plan_package")))) }
  if some("plan_validity") != none { columns.push((t.plan_validity, option-label("plan_validity", some("plan_validity")))) }
  columns
}
#let kv(label, value) = if value != none [#strong(label + ":") #value \ ]
#let terms-list = if some("terms") != none { some("terms").split("\n").filter(line => line != "") } else { () }
#show: base.with(width: 150mm, margin: (x: 12mm, y: 10mm), size: 9pt)
#set par(leading: 0.55em)
#let accent = rgb("#f0922b")
#let label(body) = text(size: 8pt, fill: muted, body)

#align(right)[
  #picture(data, "logo", 10mm)
  #text(size: 8.5pt)[
    #t.invoice_no: #strong(data.bill_number) \
    #t.date: #fmt-date(data.bill_date) \
    #t.billing_cycle: #cycle
  ]
]
#v(2mm)
#line(length: 100%, stroke: 1.6pt + accent)
#v(3mm)
#text(size: 10.5pt, [#t.hello, #data.customer_name,])
#v(3mm)
#grid(
  columns: (1fr, 1fr),
  row-gutter: 3mm,
  column-gutter: 6mm,
  [#label(t.invoice_total + ":") #strong(money(total))],
  [#label(t.currency + ":") #region.currency.symbol],
  [#label(t.payment_method + ":") #strong(if some("payment_mode") != none { option-label("payment_mode", some("payment_mode")) } else [-])],
  [#label(t.bill_account + ":") #data.account_number],
)
#v(4mm)
#table(
  columns: (1fr,) * (2 + tax-values.len()),
  align: left,
  stroke: (x, y) => (bottom: 0.5pt + luma(200)),
  inset: (x: 1.5mm, y: 2.2mm),
  ..(t.invoice_amount, ..tax-head-cells, t.payments_received).map(head => text(size: 8pt, weight: "bold", head)),
  money(taxable), ..tax-values, money(paid),
)
#v(4mm)
#text(size: 11pt, weight: "bold", t.plan_summary)
#v(1mm)
#table(
  columns: (..(1fr,) * plan-columns.len(), auto),
  align: (..(left,) * plan-columns.len(), right),
  stroke: (x, y) => (bottom: if y <= 1 { 0.5pt + luma(200) }),
  inset: (x: 1.5mm, y: 2.2mm),
  ..(..plan-columns.map(column => column.at(0)), t.plan_amount).map(head => text(size: 8pt, fill: muted, head)),
  ..plan-columns.map(column => column.at(1)), money(plan + other - discount),
)
#v(1mm)
#align(right, amount-words-line(total))
#v(5mm)
#align(right, text(size: 8.5pt)[
  #t.mailing_address:
  #if some("provider_email") != none [#text(fill: accent, some("provider_email"))] else [#data.provider_name]
])
#v(3mm)
#if terms-list.len() > 0 {
  block(width: 100%, radius: 2.5mm, fill: luma(250), stroke: 0.5pt + luma(225), clip: true, {
    block(width: 100%, fill: accent, inset: (x: 3mm, y: 2.4mm), text(size: 11pt, weight: "bold", fill: white, t.terms_title))
    block(inset: (x: 4mm, y: 3mm), text(size: 8pt, terms-list.map(line => [#line]).join(v(1.6mm))))
  })
}
