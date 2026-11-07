// Internet bill, design t2: an internet invoice: the title, "Receipt details" (number, date), "Billed to" with the account number,
// the provider and the billing cycle, the payment method, a framed table of the plan (speed, package, validity, amount) with
// the charges and the total, and the payee line. Reads data.json (next to this file). The words come from text.json (`t`), the number
// and date formats from region.json.
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
#show: base.with(width: 165mm, margin: (x: 14mm, y: 12mm), size: 10pt)
#set par(leading: 0.6em)
#let heading-size = 12pt

#text(size: 15pt, weight: "bold", t.invoice_title)
#v(1mm)
#line(length: 100%, stroke: 0.5pt + hairline)
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  row-gutter: 6mm,
  [
    #text(size: heading-size, weight: "bold", t.billed_to + ",") \
    #v(1mm)
    #kv(t.customer_name, data.customer_name)
    #kv(t.customer_address, if some("customer_address") != none { lines(some("customer_address")) })
    #kv(t.bill_account, data.account_number)
  ],
  align(right)[
    #picture(data, "logo", 11mm)
    #text(size: heading-size, weight: "bold", t.receipt_details) \
    #v(1mm)
    #kv(t.receipt_no, data.bill_number)
    #kv(t.date, fmt-date(data.bill_date))
  ],
  [
    #text(size: heading-size, weight: "bold", t.payment_method) \
    #v(1mm)
    #if some("payment_mode") != none { option-label("payment_mode", some("payment_mode")) } else [-]
    #if some("due_date") != none [ \ #v(2mm) #text(size: heading-size, weight: "bold", t.due_date) \ #fmt-date(data.due_date)]
  ],
  align(right)[
    #text(size: heading-size, weight: "bold", t.provider_details) \
    #v(1mm)
    #strong(data.provider_name)
    #if some("provider_address") != none [ \ #lines(some("provider_address"))]
    #if some("gstin") != none [ \ #tax-id-label: #some("gstin")]
    \ #t.billing_cycle: #cycle
  ],
)
#v(4mm)
#block(width: 100%, stroke: 0.6pt + luma(190), radius: 1mm, clip: true, {
  set block(spacing: 0pt)
  block(width: 100%, fill: luma(245), inset: (x: 3mm, y: 2.2mm), text(weight: "bold", t.plan_summary))
  line(length: 100%, stroke: 0.6pt + luma(190))
  table(
    columns: (..(1fr,) * plan-columns.len(), auto),
    align: (..(left,) * plan-columns.len(), right),
    stroke: (x, y) => (bottom: 0.6pt + luma(210), left: if x > 0 { 0.6pt + luma(210) }),
    inset: (x: 3mm, y: 2.4mm),
    ..(..plan-columns.map(column => column.at(0)), t.plan_amount).map(head => text(weight: "bold", head)),
    ..plan-columns.map(column => column.at(1)), money(plan),
    ..if other > 0 { (table.cell(colspan: plan-columns.len(), t.installation), money(other)) } else { () },
    ..if discount > 0 { (table.cell(colspan: plan-columns.len(), t.discount), [-#money(discount)]) } else { () },
    ..for (name, percentage, amount) in tax-parts(rate, tax) { (table.cell(colspan: plan-columns.len(), [#name #fmt-number(percentage)%]), money(amount)) },
    table.cell(colspan: plan-columns.len(), align: right, strong(t.total)), strong(money(total)),
  )
})
#v(1mm)
#amount-words-line(total)
#v(6mm)
#align(center)[
  #text(size: 9pt, weight: "bold", upper(t.payable_to + " " + data.provider_name)) \
  #v(1mm)
  #text(size: 8.5pt, upper(t.no_signature))
]
