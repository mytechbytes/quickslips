// Rent receipt, design t3: a receipt for each month, quarter, half-year or year of a period (up to 12 months), one on
// each page of the PDF. Without a period it is one receipt for the month.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 160mm, margin: (x: 14mm, y: 13mm), size: 10.5pt)
#set par(leading: 0.75em)

#let rent = data.monthly_rent
// A receipt for each month, quarter, half-year or year of the period (see `receipt-periods` of the helpers).
#let periods = receipt-periods(data)
#let count = periods.len()
#let stamp = if region.country == "in" {
  box(width: 24mm, height: 28mm, stroke: (paint: luma(120), thickness: 0.7pt, dash: "dashed"), inset: 2mm, align(center + horizon, text(size: 7.5pt, fill: muted, t.revenue_stamp)))
}

#for (i, receipt) in periods.enumerate() {
  if i > 0 { pagebreak() }
  let period = receipt.label
  let amount = rent * receipt.months

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
