// Pharmacy bill, design t1: the invoice of a medical store, in a ruled frame: the bill, the customer and the payment on the left,
// the pharmacy in the middle, the branch and its licences on the right; a table of the medicines (manufacturer, batch,
// expiry, schedule, MRP, tax, taxable value and total), the totals with the discount, and the registered offices. The MRP
// includes the tax where the country says so (India), else the tax is added. Reads data.json (next to this file). The words
// come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 190mm, margin: 6mm, size: 7.5pt)
#set par(leading: 0.5em)

#let some(key) = opt(data, key)
#let india = region.country == "in"
#let included = tax-mode == "included"
#let frame = 0.7pt + luma(60)

// The lines: the MRP times the quantity, and what the tax makes of it (taken out of the MRP, or added to it).
#let lines-of = item-rows(data).map(row => {
  let amount = row.qty * row.rate
  let split = tax-split(amount, row.tax)
  (
    ..row,
    amount: amount,
    taxable: split.base,
    tax-amount: calc.round(split.tax, digits: 2),
    total: split.total,
  )
})
#let sum(key) = sum-of(lines-of.map(line => line.at(key)))
#let total = sum("total")
#let discount = calc.min(num(data, "discount"), total)
#let net = total - discount
// The discount is spread over the whole bill: the taxable value and the tax follow it.
#let ratio = if total == 0 { 1 } else { net / total }
#let taxable-net = sum("taxable") * ratio
#let tax-net = sum("tax-amount") * ratio
#let cgst = calc.round(tax-net / 2, digits: 2)

// A small capital label and its value: nothing for a value that is not there.
#let slot(label, value) = if value != none [
  #text(size: 6.5pt, fill: muted, tracking: 0.3pt, upper(label)) \
  #text(weight: "bold", value) \
]
#let stamp-time = (fmt-date(data.date), if some("time") != none { fmt-time(some("time")) }).filter(part => part != none).join(" ")

// The columns: a text column that no line has is left out.
#let has(key) = lines-of.any(line => line.at(key) != "")
#let text-cols = (("hsn", t.hsn), ("mfr", t.mfr), ("batch", t.batch), ("expiry", t.expiry), ("schedule", t.sch)).filter(((key, label)) => has(key))
#let head-cells = (t.qty, t.item, ..text-cols.map(col => col.at(1)), t.mrp, ..if india { ("CGST %", "SGST %") } else { (t.tax_rate,) }, t.taxable, t.total_amount)
#let body-cells(line) = (
  [#fmt-number(line.qty)], line.name, ..text-cols.map(col => line.at(col.at(0))), money(line.rate),
  ..if india { ([#fmt-number(line.tax / 2)], [#fmt-number(line.tax / 2)]) } else { ([#fmt-number(line.tax)],) },
  money(line.taxable), money(line.total),
)

#block(width: 100%, stroke: frame, {
  grid(
    columns: (1fr, 1.2fr, 1fr),
    stroke: (x, y) => if x > 0 { (left: frame) },
    inset: 3mm,
    {
      slot(t.bill_no, data.bill_number)
      slot(t.date_time, stamp-time)
      slot(t.terminal, some("terminal_number"))
      slot(t.name, data.customer_name)
      slot(t.ref_no, some("ref_number"))
      slot(t.doctor, some("doctor_name"))
      slot(t.payment, option-label("payment_mode", data.payment_mode))
    },
    align(center)[
      #picture(data, "logo", 12mm)
      #text(size: 18pt, weight: "bold", fill: luma(110), tracking: 1.5pt, upper(t.invoice)) \
      #v(1mm)
      #text(size: 11pt, weight: "bold", data.brand_name)
      #if some("brand_subtitle") != none [ \ #text(fill: muted, some("brand_subtitle"))]
      #if some("website") != none [ \ #some("website")]
    ],
    align(right)[
      #if some("branch_name") != none { text(weight: "bold", some("branch_name")); linebreak() }
      #if some("branch_address") != none { lines(some("branch_address")); linebreak() }
      #if some("toll_free") != none [#t.tel: #some("toll_free") \ ]
      #if some("dl_number") != none [#t.dl_no: #some("dl_number") \ ]
      #if some("seller_tax_id") != none [#tax-id-label: #some("seller_tax_id") \ ]
      #if some("fssai") != none [FSSAI: #some("fssai")]
    ],
  )
  table(
    columns: (auto, 1fr, ..(auto,) * (head-cells.len() - 2)),
    align: (right, left, ..(left,) * text-cols.len(), ..(right,) * (head-cells.len() - 2 - text-cols.len())),
    stroke: (x, y) => (top: frame, bottom: frame, left: if x > 0 { 0.4pt + luma(120) }),
    inset: (x: 1.6mm, y: 1.6mm),
    fill: (_, row) => if row == 0 { luma(70) },
    table.header(..head-cells.map(cell => text(size: 6.5pt, weight: "bold", fill: white, upper(cell)))),
    ..lines-of.map(line => body-cells(line)).flatten(),
  )
  grid(
    columns: (1fr, 62mm),
    column-gutter: 4mm,
    inset: 3mm,
    {
      let signature = picture(data, "signature", 11mm)
      if signature != none { signature; linebreak() }
      if some("signatory_name") != none { strong(some("signatory_name")); linebreak() }
      text(size: 6.5pt, fill: muted, if some("signatory_line") != none { some("signatory_line") } else { t.authorised })
      v(1.5mm)
      text(size: 6.5pt, fill: muted, {
        if some("registered_office") != none [#t.registered: #some("registered_office") \ ]
        if some("admin_office") != none [#t.admin: #some("admin_office")]
      })
    },
    {
      align(center, text(size: 6.5pt, fill: muted, region.currency.code))
      v(1mm)
      block(width: 100%, stroke: frame, inset: 2.4mm, grid(
        columns: (1fr, auto),
        row-gutter: 2mm,
        strong(upper(t.total)), align(right, strong(money(total))),
        strong(upper(t.discount)), align(right, strong(money(discount))),
        strong(upper(t.net_total)), align(right, text(size: 9.5pt, weight: "bold", money(net))),
      ))
      v(1.5mm)
      text(size: 6.5pt, fill: muted, grid(
        columns: (1fr, auto),
        row-gutter: 1mm,
        [#t.taxable_value], align(right, money(taxable-net)),
        ..if india { ("CGST", align(right, money(cgst)), "SGST", align(right, money(tax-net - cgst))) } else { (tax-name, align(right, money(tax-net))) },
      ))
    },
  )
})
