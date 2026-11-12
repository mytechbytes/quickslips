// Rent receipt, design t1: the receipt a tenant hands to the employer to be reimbursed (HRA): a certificate with the
// amount, the month, the property and the landlord. Reads data.json (next to this file). The words come from text.json
// (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 160mm, margin: (x: 14mm, y: 13mm), size: 10.5pt)
#set par(leading: 0.75em)

// The revenue stamp is stuck on a receipt in India only.
#let stamp = if region.country == "in" {
  revenue-stamp(data, t.revenue_stamp, width: 24mm, height: 28mm)
}

#let receipts = salary-periods(data)
#for (i, receipt) in receipts.enumerate() [
#if i > 0 { pagebreak() }
#let month = receipt.label
#let when = receipt.date
#let rent = data.monthly_rent * receipt.months
#let period = receipt.months > 1
#v(1mm)
#align(center, text(size: 15pt, weight: "bold", t.title))
#v(2mm)
#rule()
#v(4mm)

#say(if period { t.certify_period } else { t.certify }, (tenant: data.tenant_name, amount: money(rent), landlord: data.landlord_name, month: month, period: month))

#t.reimburse

#v(2mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 8mm,
  row-gutter: 5mm,
  [*#t.address:* #lines(data.property_address)], align(right)[*#t.payment_method:* #option-label("payment_mode", data.payment_mode)],
  [*#t.landlord_name:* #data.landlord_name#if opt(data, "landlord_pan") != none [ (PAN: #opt(data, "landlord_pan"))]], align(right)[*#t.tenant_name:* #data.tenant_name],
)
#v(4mm)
#grid(
  columns: (1fr, auto),
  [#if when != none [*#t.date:* #fmt-date(when)]#if stamp != none [ \ \ #stamp]],
  [],
)
#v(2mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  align(left, signature-block(data, t.second_signature, name: data.tenant_name, key: "driver_signature")),
  signature-block(data, t.landlord_signature, name: data.landlord_name),
)
]
