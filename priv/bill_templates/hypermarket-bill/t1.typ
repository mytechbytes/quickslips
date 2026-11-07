// Hypermarket bill, design t1: the tax invoice of a hypermarket's order, an 80 mm slip: the brand and the company with its registration
// numbers, "Tax invoice", the items (each with its HSN code and tax rate, the prices hold the tax where the country says so),
// the count and the total, the savings, the breakup of the tax by rate, the order, the customer and delivery, the payment
// instruction and the footer. Reads data.json (next to this file). The words come from text.json (`t`), the number and date
// formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 80mm, margin: (x: 4.5mm, y: 6mm), size: 7.5pt)
#set par(leading: 0.55em)
#show grid: set block(spacing: 1.2mm)
#show table: set block(spacing: 1.6mm)

#let india = region.country == "in"

// The lines: the price times the quantity, and what the tax makes of it (taken out of the price, or added to it).
#let lines-of = item-rows(data).map(row => {
  let amount = row.qty * row.rate
  let split = tax-split(amount, row.tax)
  (..row, amount: amount, taxable: split.base, tax-amount: split.tax, total: split.total)
})
#let total = sum-of(lines-of.map(line => line.total))
#let quantity = sum-of(lines-of.map(line => line.qty))
#let savings = num(data, "savings")

// The tax of a line as the till prints it: "CGST@ 2.5% SGST@ 2.5%" in India, "VAT@ 20%" elsewhere.
#let tax-text(line) = if line.tax == 0 { t.exempt } else {
  tax-parts(line.tax, line.tax-amount).map(part => part.at(0) + "@ " + fmt-number(part.at(1)) + "%").join(" ")
}

// A line that separates the parts, and the heading of a part.
#let part(label) = {
  v(1.2mm)
  dashed()
  v(0.8mm)
  align(center, text(weight: "bold", upper(label)))
  v(0.8mm)
  dashed()
  v(0.6mm)
}
// A label and its value on one line: nothing for a value that is not there.
#let kv(label, value) = if value != none {
  grid(columns: (auto, 1fr), column-gutter: 2mm, [#label], align(right, strong(value)))
}
#let day(key) = if some(key) != none { fmt-date(some(key)) }

#align(center)[
  #picture(data, "logo", 10mm)
  #text(size: 10.5pt, weight: "bold", data.brand_name) \
  #text(weight: "bold", data.company_name)
]
#v(0.5mm)
#align(center)[
  #if some("cin") != none [CIN: #some("cin") \ ]
  #if some("seller_tax_id") != none [#tax-id-label: #some("seller_tax_id")]
]
#part(t.tax_invoice)
#kv(t.invoice_no, data.invoice_number)
#kv(t.invoice_date, fmt-date(data.date))
#dashed()
#v(0.6mm)

#let has-hsn = lines-of.any(line => line.hsn != "")
#table(
  columns: (1fr, auto, auto, auto),
  align: (left + top, right + top, right + top, right + top),
  column-gutter: 1.2mm,
  stroke: none,
  inset: (x: 0.6mm, y: 1.1mm),
  ..(
    if has-hsn [#t.hsn #h(3mm) #t.particulars] else { t.particulars },
    t.qty, t.rate, t.value,
  ).map(head => text(weight: "bold", head)),
  table.hline(stroke: (paint: luma(60), thickness: 0.6pt, dash: "dashed")),
  ..lines-of.map(line => (
    [#if line.hsn != "" [#line.hsn #h(2mm)]#line.name \ #text(size: 6.5pt, fill: muted, tax-text(line))],
    [#fmt-number(line.qty)],
    [#money(line.rate)],
    [#money(line.amount)],
  )).flatten(),
  table.hline(stroke: (paint: luma(60), thickness: 0.6pt, dash: "dashed")),
)
#v(0.6mm)
#grid(
  columns: (1fr, 1fr, 1fr),
  align: (left, center, right),
  text(weight: "bold", [#t.items: #lines-of.len()]),
  text(weight: "bold", [#t.qty: #fmt-number(quantity)]),
  text(weight: "bold", [#t.amt: #money(total)]),
)
#v(0.6mm)
#dashed()
#v(1mm)
#align(center, text(size: 9pt, weight: "bold", [#upper(t.your_savings): #money(savings) #text(size: 7pt, [(#t.on_list)])]))
#v(1mm)
#dashed()

#align(center, text(size: 6.8pt, "<--- " + t.breakup + " --->  (" + t.amount_in + " " + region.currency.symbol + ")"))
#v(0.4mm)
#let slabs = lines-of.map(line => line.tax).dedup().sorted()
#let slab-cells(rate) = {
  let group = lines-of.filter(line => line.tax == rate)
  let base = sum-of(group.map(line => line.taxable))
  let tax = sum-of(group.map(line => line.tax-amount))
  let half = calc.round(tax / 2, digits: 2)
  (
    [#fmt-number(rate)%], money(base),
    ..if india { (money(half), money(tax - half)) } else { (money(tax),) },
    money(sum-of(group.map(line => line.total))),
  )
}
#let breakup-heads = (t.rate_col, t.taxable, ..if india { ("CGST", "SGST") } else { (tax-name,) }, t.total)
#table(
  columns: (auto, 1fr, ..(auto,) * (breakup-heads.len() - 2)),
  align: (left, ..(right,) * (breakup-heads.len() - 1)),
  column-gutter: 1mm,
  stroke: none,
  inset: (x: 0.6mm, y: 0.9mm),
  ..breakup-heads.map(head => text(size: 6.5pt, weight: "bold", head)),
  table.hline(stroke: (paint: luma(60), thickness: 0.5pt, dash: "dashed")),
  ..slabs.map(slab-cells).flatten().map(cell => text(size: 6.5pt, cell)),
)

#part(t.order_details)
#kv(t.order_number, some("order_number"))
#kv(t.order_date, day("order_date"))
#kv(t.delivery_date, day("delivery_date"))
#kv(t.delivery_time, some("delivery_time"))
#kv(t.payment_mode, option-label("payment_mode", data.payment_mode))

#part(t.customer_delivery)
#kv(t.customer_name, some("customer_name"))
#kv(t.mobile, some("customer_phone"))
#kv(t.delivery_mode, option-label("delivery_mode", data.delivery_mode))
#if some("delivery_address") != none [
  #text(weight: "bold", t.address): #lines(some("delivery_address"))
]

#if some("payment_note") != none {
  part(upper(some("payment_note")))
  align(center, say(t.collect, (amount: money(total))))
  v(1mm)
}
#dashed()
#v(1mm)
#align(center, text(size: 6.8pt)[
  #if some("website") != none [#some("website") \ ]
  #if some("email") != none [#some("email") \ ]
  #if some("phone") != none [#some("phone") \ ]
  #t.computer_generated
])
#v(1mm)
#line(length: 100%, stroke: 0.8pt + luma(60))
#v(1mm)
#align(center, text(size: 6.5pt, fill: muted)[
  #if some("company_address") != none [#data.company_name, #some("company_address") \ ]
  #if some("fssai") != none [FSSAI NO: #some("fssai")]
])
