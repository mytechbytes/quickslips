// Rent receipt, design t3: a receipt for each month, quarter, half-year or year of a period (up to 12 months), one on
// each page of the PDF. Without a period it is one receipt for the month.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 160mm, margin: (x: 14mm, y: 13mm), size: 10.5pt)
#set par(leading: 0.75em)

#let rent = data.monthly_rent
// A month as a whole number of months (year times twelve), and back to "2026-10".
#let ym-int(ym) = {
  let (y, m) = ym.split("-").map(int)
  y * 12 + m - 1
}
#let ym-str(n) = {
  let m = calc.rem(n, 12) + 1
  str(calc.quo(n, 12)) + "-" + (if m < 10 { "0" } else { "" }) + str(m)
}
#let first = if opt(data, "from_date") != none { opt(data, "from_date").slice(0, 7) } else { data.month }
#let last = if opt(data, "to_date") != none { opt(data, "to_date").slice(0, 7) } else { first }
#let step = (Monthly: 1, Quarterly: 3, "Half-yearly": 6, Yearly: 12).at(data.at("bill_by", default: "Monthly"), default: 1)
// The months of the period, at most a year of them, and how many receipts that makes.
#let months = calc.min(calc.max(ym-int(last) - ym-int(first) + 1, 1), 12)
#let count = calc.ceil(months / step)
#let stamp = if region.country == "in" {
  box(width: 24mm, height: 28mm, stroke: (paint: luma(120), thickness: 0.7pt, dash: "dashed"), inset: 2mm, align(center + horizon, text(size: 7.5pt, fill: muted, t.revenue_stamp)))
}

#for i in range(count) {
  if i > 0 { pagebreak() }
  let start = ym-int(first) + i * step
  let length = calc.min(step, months - i * step)
  let period = if length == 1 { month-label(ym-str(start)) } else { month-label(ym-str(start)) + " – " + month-label(ym-str(start + length - 1)) }
  let amount = rent * length

  align(right)[#t.date: #fmt-date(data.receipt_date)]
  v(1mm)
  align(center, text(size: 15pt, weight: "bold", t.title))
  if count > 1 { align(center, text(size: 8.5pt, fill: muted, t.receipt_of.replace("{number}", str(i + 1)).replace("{total}", str(count)))) }
  v(2mm)
  rule()
  v(4mm)
  say(t.certify_period, (tenant: data.tenant_name, amount: money(amount), landlord: data.landlord_name, period: period))
  parbreak()
  [#t.reimburse]
  v(2mm)
  grid(
    columns: (1fr, auto),
    column-gutter: 8mm,
    row-gutter: 5mm,
    [*#t.address:* #lines(data.property_address)], align(right)[*#t.payment_method:* #option-label("payment_mode", data.payment_mode)],
    [*#t.landlord_name:* #data.landlord_name#if opt(data, "landlord_pan") != none [ (PAN: #opt(data, "landlord_pan"))]], align(right)[*#t.tenant_name:* #data.tenant_name],
  )
  v(4mm)
  grid(
    columns: (1fr, auto),
    [*#t.period:* #period #if stamp != none [ \ \ #stamp]],
    align(bottom, signature-block(data, t.landlord_signature, name: data.landlord_name)),
  )
}
