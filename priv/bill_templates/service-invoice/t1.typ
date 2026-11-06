// Service invoice, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a4", margin: 18mm, size: 10.5pt)

#let items = item-rows(data)
#let subtotal = sum-of(items.map(row => row.amount))
#let tax-rate = num(data, "gst_percent")
#let tax = percent(subtotal, tax-rate)
#let total = subtotal + tax

#letterhead(
  data,
  data.seller_name,
  address: opt(data, "seller_address"),
  gstin: opt(data, "gstin"),
  title: "Invoice",
)

#grid(
  columns: (1fr, 1fr),
  column-gutter: 8mm,
  details(
    (
      ([Invoice no.], data.invoice_number),
      ([Invoice date], fmt-date(data.invoice_date)),
      ([Due date], if opt(data, "due_date") != none { fmt-date(data.due_date) }),
    ),
    columns: 1,
  ),
  details(
    (
      (
        [Bill to],
        [*#data.client_name*#if opt(data, "client_address") != none [ \ #lines(opt(data, "client_address"))]],
      ),
      ([Client GSTIN], opt(data, "client_gstin")),
    ),
    columns: 1,
  ),
)

#v(8mm)
#bill-table(
  ([Description], [Qty], [Rate], [Amount]),
  items.map(row => ([#row.name], [#fmt-number(row.qty)], [#money(row.rate)], [#money(row.amount)])),
)

#v(3mm)
#totals((([Subtotal], subtotal), ([GST (#tax-rate%)], tax)), total)

#if opt(data, "notes") != none [
  #v(8mm)
  #details((([Notes], lines(opt(data, "notes"))),), columns: 1)
]

#v(14mm)
#signature-block(data, [Authorised signatory], name: data.seller_name)
