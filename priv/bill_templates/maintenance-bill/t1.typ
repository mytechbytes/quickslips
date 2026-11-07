// Maintenance bill, design t1: the estimate, invoice or job card of a car or bike workshop, with a table of parts and a
// table of labour (each line with a billing type and a discount) and a summary with the tax. Reads data.json (next to
// this file). The words come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 160mm, margin: (x: 9mm, y: 9mm), size: 8.5pt)

#let parts = item-rows(data, key: "parts")
#let jobs = item-rows(data, key: "labour", quantity: false)
#let parts-total = sum-of(parts.map(row => row.amount))
#let jobs-total = sum-of(jobs.map(row => row.amount))
#let base-total = parts-total + jobs-total
#let rate = opt(data, "tax_percent")
#let split = if rate != none { tax-split(base-total, rate) } else { (base: base-total, tax: 0, total: base-total) }
#let total = split.total

// "Label: value", or nothing where the field was left empty.
#let kv(label, value) = if value != none [#strong(label + ":") #value]
#let stack-of(..rows) = rows.pos().filter(row => row != none).join(linebreak())

// The tax of the invoice: half and half where India splits it (CGST and SGST), else one line with the name of the tax.
#let tax-rows() = {
  if rate == none { return () }
  if region.country == "in" {
    let first = calc.round(split.tax / 2, digits: 2)
    (("CGST", rate / 2, first), ("SGST", rate / 2, split.tax - first))
  } else {
    ((tax-name, rate, split.tax),)
  }
}

// A table of lines: number, code, description, billing type, [quantity], rate, discount, net amount.
#let lines-table(rows, with-qty) = {
  let head = ([\#], t.code, t.description, t.billing, ..if with-qty { (t.qty,) } else { () }, t.rate, t.discount, t.net)
  let align-of = (left, left, left, left, ..if with-qty { (right,) } else { () }, right, right, right)
  table(
    columns: (6mm, 23mm, 1fr, 22mm, ..if with-qty { (11mm,) } else { () }, 19mm, 12mm, 21mm),
    align: align-of,
    stroke: none,
    inset: (x: 1.4mm, y: 1.8mm),
    table.hline(stroke: 0.7pt),
    ..head.map(cell => text(size: 7.5pt, weight: "bold", cell)),
    table.hline(stroke: 0.7pt),
    ..rows.enumerate().map(((index, row)) => (
      [#(index + 1)],
      row.code,
      row.name,
      if row.billing != none { option-label(if with-qty { "parts" } else { "labour" }, row.billing) },
      ..if with-qty { (fmt-number(row.qty),) } else { () },
      money(row.rate),
      if row.discount == 0 { [–] } else { [#fmt-number(row.discount)%] },
      money(row.amount),
    )).flatten(),
    table.hline(stroke: (paint: luma(90), thickness: 0.6pt, dash: "dashed")),
  )
}

#grid(
  columns: (1fr, auto),
  column-gutter: 6mm,
  {
    picture(data, "logo", 13mm)
    v(1mm)
    text(size: 12pt, weight: "bold", data.workshop_name)
    linebreak()
    text(size: 8pt, fill: muted, stack-of(
      lines(data.workshop_address),
      kv(t.contact, opt(data, "workshop_phone")),
      kv(t.dealer, opt(data, "dealer_name")),
      kv(tax-id-label, opt(data, "seller_tax_id")),
    ))
  },
  align(right + top, text(size: 11pt, weight: "bold", fill: muted, upper(option-label("document_type", data.document_type)))),
)
#v(2mm)
#rule()
#v(3mm)

#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  row-gutter: 2mm,
  stack-of(
    kv(option-label("document_type", data.document_type) + " " + t.no, data.document_number),
    kv(t.customer, data.customer_name),
    kv(t.vin, opt(data, "vin")),
    kv(t.insurance, opt(data, "insurance_company")),
    kv(t.reference, opt(data, "reference_number")),
  ),
  stack-of(
    kv(t.date, fmt-date(data.date)),
    kv(t.contact, opt(data, "customer_phone")),
    kv(t.model, data.vehicle_model),
    kv(t.reg_no, data.registration_number),
    kv(t.section, if opt(data, "workshop_section") != none { option-label("workshop_section", data.workshop_section) }),
  ),
)

#if parts.len() > 0 [
  #v(4mm)
  #text(size: 10pt, weight: "bold", t.parts)
  #v(1mm)
  #lines-table(parts, true)
  #align(right, [#strong(t.parts_total): #h(3mm) #strong(money(parts-total))])
]
#if jobs.len() > 0 [
  #v(4mm)
  #text(size: 10pt, weight: "bold", t.labour)
  #v(1mm)
  #lines-table(jobs, false)
  #align(right, [#strong(t.jobs_total): #h(3mm) #strong(money(jobs-total))])
]

#v(5mm)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  {
    text(size: 10pt, weight: "bold", upper(t.tax_details))
    v(1.5mm)
    if rate == none { text(fill: muted)[–] } else {
      grid(
        columns: (1fr, auto, auto),
        column-gutter: 4mm,
        row-gutter: 1.6mm,
        align: (left, right, right),
        text(fill: muted, t.taxable), [], money(split.base),
        ..for (name, percentage, amount) in tax-rows() {
          (text(fill: muted, name), [#fmt-number(percentage)%], money(amount))
        },
      )
    }
  },
  {
    text(size: 10pt, weight: "bold", upper(t.summary))
    v(1.5mm)
    grid(
      columns: (1fr, auto),
      column-gutter: 4mm,
      row-gutter: 1.6mm,
      text(fill: muted, t.parts_total), align(right, money(parts-total)),
      text(fill: muted, t.jobs_total), align(right, money(jobs-total)),
      ..if rate != none and tax-mode == "added" { (text(fill: muted, tax-name), align(right, money(split.tax))) } else { () },
    )
    v(1.5mm)
    line(length: 100%, stroke: 0.7pt)
    v(1.5mm)
    grid(columns: (1fr, auto), align: horizon, strong(t.total), text(size: 12pt, weight: "bold", money(total)))
  },
)
#let words = amount-words-line(total)
#if words != none [#v(2mm) #align(left, words)]

#v(6mm)
#signature-block(data, t.signatory)

#if opt(data, "terms") != none [
  #v(3mm)
  #text(size: 7.5pt, fill: muted)[
    #opt(data, "terms").split("\n").filter(line => line.trim() != "").enumerate().map(((index, line)) => [#(index + 1). #line]).join(linebreak())
  ]
]
