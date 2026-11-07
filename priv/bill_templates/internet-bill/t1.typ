// Internet bill, design t1: a plain bill on A4: the provider and "Internet bill", the bill details, "Billed to", the plan and its
// charges, the totals and the due date. Reads data.json (next to this file). The words come from text.json (`t`), the number and
// date formats from region.json.
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
#show: base.with(paper: "a4", margin: 18mm, size: 10.5pt)

#letterhead(
  data,
  data.provider_name,
  address: some("provider_address"),
  gstin: some("gstin"),
  title: t.title,
)

#details(
  (
    (t.bill_no, data.bill_number),
    (t.bill_date, fmt-date(data.bill_date)),
    (t.due_date, if some("due_date") != none { fmt-date(data.due_date) }),
    (t.account_no, data.account_number),
    (t.billing_period, cycle),
  ),
  columns: 3,
)

#v(5mm)
#details(
  (
    (
      t.billed_to,
      [*#data.customer_name*#if some("customer_address") != none [ \ #lines(some("customer_address"))]],
    ),
  ),
  columns: 1,
)

#v(8mm)
#bill-table(
  (t.description, t.amount),
  (
    ([#data.plan_name], [#money(plan)]),
    ..if other > 0 { (([#t.installation], [#money(other)]),) } else { () },
    ..if discount > 0 { (([#t.discount], [-#money(discount)]),) } else { () },
  ),
)

#v(3mm)
#totals(((t.subtotal, taxable), ((if india { "GST" } else { tax-name }) + " (" + fmt-number(rate) + "%)", tax)), total, label: t.amount_due)

#if some("due_date") != none [
  #v(6mm)
  #say(t.pay_by, (date: fmt-date(data.due_date)))
]

#footnote(t.computer_generated)
