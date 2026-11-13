// Internet bill, design t3: a detailed invoice with an orange head: the provider and, in a box, the receipt for the recipient with the
// name, account and invoice number, a row of the taxable amount, the tax and the payments received, the plan summary, the receipt
// details, the registered office, the terms and conditions and an acknowledgement slip to cut off. Reads data.json (next to this
// file). The words come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let on-sheet = data.at("paper_size", default: none) != none
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
#show: base.with(width: 165mm, margin: (x: 12mm, y: 12mm), size: 9pt)
#set par(leading: 0.55em)
#let accent = rgb("#f0922b")
#let head-cell(body) = text(size: 8pt, weight: "bold", fill: white, body)
#let orange-table(heads, row, columns: none) = table(
  columns: if columns == none { (1fr,) * heads.len() } else { columns },
  align: left,
  stroke: (x, y) => (bottom: if y == 1 { 0.6pt + accent }, left: if x > 0 and y == 1 { 0.4pt + luma(220) }),
  fill: (_, y) => if y == 0 { accent },
  inset: 2.4mm,
  ..heads.map(head-cell),
  ..row,
)

#grid(
  columns: (1fr, auto),
  column-gutter: 8mm,
  [
    #picture(data, "logo", 12mm)
    #text(size: 14pt, weight: "bold", data.provider_name)
    #if some("provider_address") != none [ \ #text(fill: muted, lines(some("provider_address")))]
    #if some("gstin") != none [ \ #text(fill: muted)[#tax-id-label: #some("gstin")]]
  ],
  block(width: 62mm, fill: luma(246), inset: 3mm, radius: 1.5mm, align(right)[
    #text(size: 8pt, fill: muted, t.receipt_for_recipient) \
    #v(1mm)
    #strong(t.name + ":") #data.customer_name \
    #strong(t.account_no + ":") #data.account_number \
    #v(2mm)
    #strong(t.invoice_no + ":") #data.bill_number \
    #strong(t.bill_date + ":") #fmt-date(data.bill_date)
  ]),
)
#v(3mm)
#line(length: 100%, stroke: 0.5pt + hairline)
#v(3mm)
#orange-table(
  (t.taxable_amount, ..tax-head-cells, t.payments_received),
  (money(taxable), ..tax-values, money(paid)),
)
#v(3mm)
#block(width: 100%, stroke: 0.6pt + accent, radius: 1mm, inset: (x: 3mm, y: 2mm), grid(
  columns: (1fr, auto),
  strong(t.plan_summary),
  [#t.account_no: #data.account_number #h(3mm) #if some("user_name") != none [#t.user_name: #some("user_name")]],
))
#orange-table(
  (..plan-columns.map(column => column.at(0)), ..if discount > 0 { (t.discount,) } else { () }, t.plan_amount),
  (..plan-columns.map(column => column.at(1)), ..if discount > 0 { (money(discount),) } else { () }, money(plan + other)),
)
#v(3mm)
#block(width: 100%, stroke: 0.6pt + accent, radius: 1mm, inset: (x: 3mm, y: 2mm), grid(
  columns: (1fr, auto),
  strong(t.receipt_details),
  [#t.account_no: #data.account_number #h(3mm) #if some("user_name") != none [#t.user_name: #some("user_name")]],
))
#orange-table(
  (t.invoice_no, t.service_description, t.amount_incl_tax),
  (data.bill_number, if some("service_description") != none { some("service_description") } else { data.plan_name }, money(total)),
  columns: (auto, 1fr, auto),
)
#v(1mm)
#align(right, amount-words-line(total))
#v(2mm)
#if some("registered_office") != none {
  block(width: 100%, fill: luma(246), inset: 2.5mm, align(center, [#t.registered_office: #some("registered_office")]))
  v(3mm)
}
// In the browser preview the next part is a page of its own.
#if preview and not on-sheet { pagebreak(weak: true) }
#if terms-list.len() > 0 {
  block(width: 100%, stroke: 0.6pt + luma(220), radius: 2mm, clip: true, {
    block(width: 100%, fill: accent, inset: (x: 3mm, y: 2.4mm), text(size: 11pt, weight: "bold", fill: white, t.terms_title))
    block(inset: (x: 4mm, y: 2.5mm), text(size: 8pt, fill: luma(80), enum(..terms-list.map(line => [#line]), spacing: 1.6mm)))
  })
}
#v(4mm)
#line(length: 100%, stroke: (paint: luma(150), thickness: 0.8pt, dash: "dashed"))
#v(1.5mm)
#align(center, text(size: 11pt, weight: "bold", t.acknowledgement))
#v(1mm)
#grid(
  columns: (1fr, 1fr, 1fr),
  column-gutter: 3mm,
  [#strong(t.account_no + ":") #data.account_number],
  [#strong(t.subscriber_name + ":") #data.customer_name],
  [#strong(t.payment_method + ":") #if some("payment_mode") != none { option-label("payment_mode", some("payment_mode")) } else [-]],
)
#v(1mm)
#strong(t.invoice_no + ":") #data.bill_number
