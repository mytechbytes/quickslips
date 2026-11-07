// Electronics bill, design t1: a tax invoice in a ruled frame: the seller with its registration numbers and the title on top, the
// place of supply and the invoice number, the "bill to" and "ship to" parties, a table of the items (serial number, HSN code,
// quantity, rate, taxable value and tax; CGST and SGST in India, or IGST for a supply to another state), the totals and the
// amount in words, the payment and the balance, the tax summary, the remarks, the bank, the helplines and the signatory. The
// rate includes the tax where the country says so. Reads data.json (next to this file). The words come from text.json (`t`),
// the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 120mm, margin: 5mm, size: 7.5pt)
#set par(leading: 0.5em)
#set block(spacing: 0pt)

#let india = region.country == "in"
#let igst = india and data.at("supply", default: "Same state") == "Other state"
#let frame = 0.8pt + luma(40)
#let thin = 0.5pt + luma(90)

#let lines-of = item-rows(data).map(row => {
  let amount = row.qty * row.rate
  let split = tax-split(amount, row.tax)
  (..row, amount: amount, taxable: split.base, tax-amount: split.tax, total: split.total)
})
#let sum(key) = sum-of(lines-of.map(line => line.at(key)))
#let total = sum("total")
#let taxable-total = sum("taxable")
#let tax-total = sum("tax-amount")
#let paid = if data.at("amount_paid", default: none) != none { data.amount_paid } else { total }
#let balance = total - paid
#let half(amount) = calc.round(amount / 2, digits: 2)

// A label and its value, with a colon between: nothing for a value that is not there.
#let kv(label, value) = if value != none [#label #h(1fr) : #h(1.5mm) #value \ ]
#let plain(label, value) = if value != none [#label: #value \ ]
// The ship-to party is the bill-to party where nothing else is said.
#let ship(key, fallback) = if some(key) != none { some(key) } else { some(fallback) }
#let small(body) = text(size: 6.6pt, body)
#let head-cell(body) = text(size: 6.6pt, weight: "bold", body)

// The tax of a line as a rate over an amount.
#let rate-amount(rate, amount) = align(right)[#fmt-number(rate)% \ #text(size: 0.9em, fill: muted, money(amount))]
#let tax-heads = if igst { ("IGST",) } else if india { ("SGST", "CGST") } else { (tax-name,) }
#let tax-cells(line) = if igst { (rate-amount(line.tax, line.tax-amount),) } else if india {
  (rate-amount(line.tax / 2, half(line.tax-amount)), rate-amount(line.tax / 2, line.tax-amount - half(line.tax-amount)))
} else { (rate-amount(line.tax, line.tax-amount),) }
#let tax-count = tax-heads.len()

#block(width: 100%, stroke: frame, {
  // The seller and the title.
  grid(
    columns: (1fr, auto),
    column-gutter: 3mm,
    inset: 2.5mm,
    [
      #picture(data, "logo", 9mm)
      #text(size: 10pt, weight: "bold", data.company_name) \
      #if some("branch") != none [#text(fill: muted, some("branch")) \ ]
      #if some("seller_address") != none [#lines(some("seller_address")) \ ]
      #plain(t.state, some("seller_state"))
      #plain(t.tel_no, some("seller_phone"))
      #plain(tax-id-label, some("seller_tax_id"))
      #plain(t.email, some("seller_email"))
      #plain("PAN", some("seller_pan"))
      #plain("CIN", some("cin"))
    ],
    align(right)[
      #text(size: 11pt, weight: "bold", upper(t.tax_invoice)) \
      #if some("copy_label") != none [#text(size: 6.6pt, some("copy_label"))]
    ],
  )
  line(length: 100%, stroke: frame)
  // The place of supply and the invoice.
  let invoice-box = [
    #kv(t.invoice_number, data.invoice_number)
    #kv(t.invoice_date, fmt-date(data.date))
    #kv(t.do_number, some("do_number"))
  ]
  let supply-box = text(fill: rgb("#2a4d9b"))[
    #plain(t.place_of_supply, some("place_of_supply"))
    #if some("reverse_charge") != none [#some("reverse_charge")]
  ]
  if some("place_of_supply") != none or some("reverse_charge") != none {
    grid(
      columns: (1fr, 1.1fr),
      stroke: (x, y) => if x > 0 { (left: frame) },
      inset: 2.5mm,
      supply-box, invoice-box,
    )
  } else {
    block(inset: 2.5mm, invoice-box)
  }
  line(length: 100%, stroke: frame)
  // The parties.
  grid(
    columns: (1fr, 1fr),
    stroke: (x, y) => (left: if x > 0 { frame }, bottom: if y == 0 { frame }),
    inset: 2mm,
    align(center, text(weight: "bold", t.bill_to_party)), align(center, text(weight: "bold", t.ship_to_party)),
    small[
      #plain(t.financier, some("financier"))
      #plain(t.name, data.bill_name)
      #plain(t.care_of, some("bill_care_of"))
      #plain(t.address, if some("bill_address") != none { lines(some("bill_address")) })
      #plain(t.state, some("bill_state"))
      #plain(t.pin, some("bill_pin"))
      #plain(t.contact, some("bill_phone"))
      #plain(tax-id-label, some("bill_tax_id"))
    ],
    small[
      #plain(t.code, some("ship_code"))
      #plain(t.auth_code, some("ship_auth_code"))
      #plain(t.address, if ship("ship_address", "bill_address") != none { lines(ship("ship_address", "bill_address")) })
      #plain(t.state, ship("ship_state", "bill_state"))
      #plain(t.contact, ship("ship_phone", "bill_phone"))
      #plain(tax-id-label, ship("ship_tax_id", "bill_tax_id"))
    ],
  )
  line(length: 100%, stroke: frame)
  // The items.
  table(
    columns: (1fr, auto, auto, auto, ..(auto,) * tax-count, auto),
    align: (left, right, right, right, ..(right,) * tax-count, right),
    stroke: (x, y) => (bottom: thin, left: if x > 0 { thin }),
    inset: (x: 1.2mm, y: 1.4mm),
    ..(t.item_name, t.qty, t.rate, t.taxable_value, ..tax-heads, t.amount).map(head-cell),
    ..lines-of.map(line => (
      [
        #small(line.name)
        #if line.code != "" or line.hsn != "" [ \ #text(size: 5.8pt, fill: muted, (if line.code != "" { t.serial_no + ": " + line.code }, if line.hsn != "" { t.hsn + ": " + line.hsn }).filter(part => part != none).join(" · "))]
      ],
      small[#fmt-number(line.qty)], small(money(line.rate)), small(money(line.taxable)),
      ..tax-cells(line).map(small),
      small(money(line.total)),
    )).flatten(),
    table.cell(inset: (x: 1.2mm, y: 1.4mm), head-cell(t.totals)),
    head-cell[#fmt-number(sum("qty"))], [], head-cell(money(taxable-total)),
    ..if igst or not india { (head-cell(money(tax-total)),) } else { (head-cell(money(half(tax-total))), head-cell(money(tax-total - half(tax-total)))) },
    head-cell(money(total)),
  )
  line(length: 100%, stroke: frame)
  block(inset: 2mm, {
    let words = amount-words(total)
    text(weight: "bold", t.amount_in_words + ": ")
    if words != none { words } else { [] }
  })
  line(length: 100%, stroke: frame)
  // The payment and the totals.
  grid(
    columns: (1fr, auto),
    stroke: (x, y) => if x > 0 { (left: frame) },
    inset: 2mm,
    table(
      columns: (auto, auto, auto, 1fr),
      stroke: thin,
      inset: 1.3mm,
      ..(t.payment_mode, t.reference, t.date, t.amount).map(head-cell),
      small(option-label("payment_mode", data.payment_mode)),
      small(if some("payment_reference") != none { some("payment_reference") } else { "-" }),
      small(if some("payment_date") != none { fmt-date(some("payment_date")) } else { "-" }),
      align(right, small(money(paid))),
    ),
    grid(
      columns: (auto, auto, auto),
      column-gutter: 1.5mm,
      row-gutter: 1.6mm,
      strong(t.total), ":", align(right, strong(money(total))),
      t.payments, ":", align(right, money(paid)),
      t.balance, ":", align(right, money(balance)),
    ),
  )
  line(length: 100%, stroke: frame)
  // The tax summary.
  block(inset: 2mm, table(
    columns: (auto,) * (if india { 4 } else { 2 }),
    align: center,
    stroke: thin,
    inset: 1.4mm,
    ..(if india { ("CGST " + t.amt, "SGST " + t.amt, "IGST " + t.amt, tax-name + " " + t.total) } else { (tax-name + " " + t.amt, t.total) }).map(head-cell),
    ..if india {
      (
        if igst { "-" } else { small(money(half(tax-total))) }, if igst { "-" } else { small(money(tax-total - half(tax-total))) },
        if igst { small(money(tax-total)) } else { "-" }, small(money(tax-total)),
      )
    } else { (small(money(tax-total)), small(money(total))) },
  ))
  line(length: 100%, stroke: frame)
  block(inset: 2mm, small[
    #plain(t.remarks, if some("remarks") != none { lines(some("remarks")) })
  ])
  line(length: 100%, stroke: frame)
  grid(
    columns: (1fr, 1fr),
    stroke: (x, y) => if x > 0 { (left: frame) },
    inset: 2mm,
    small[
      #text(fill: rgb("#2a4d9b"), weight: "bold")[#plain(t.bank_details, some("bank_details"))]
      #plain(t.bank_account, some("bank_account"))
      #plain(t.ifsc, some("bank_ifsc"))
      #v(1mm)
      #plain(t.customer_care, some("customer_care"))
      #plain(t.delivery_helpline, some("delivery_helpline"))
      #v(1mm)
      #if some("thank_you") != none { text(weight: "bold", some("thank_you")) }
    ],
    align(right + bottom)[
      #picture(data, "signature", 11mm) \
      #if some("signatory_for") != none [#small[#t.for #some("signatory_for")] \ ]
      #small(strong(t.authorised))
    ],
  )
})
