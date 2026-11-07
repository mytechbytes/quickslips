// Book receipt, design t1: the receipt of a bookstore, a plain page: the title, "Bill to" with the customer and the book on the left,
// the receipt number and date on the right, the payment method, a summary table (item, description, quantity, price, total) and
// a thank-you with two lines about books. Reads data.json (next to this file). The words come from text.json (`t`), the number
// and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 159mm, margin: (x: 14mm, y: 11mm), size: 10pt)
#set par(leading: 0.6em)

#let total = data.quantity * data.book_price
#let kv(label, value) = if value != none [#strong(label + ":") #value \ ]
#let heading-size = 13pt

#align(center)[
  #picture(data, "logo", 12mm)
  #text(size: 16pt, weight: "bold", t.title) \
  #text(size: 8.5pt, fill: muted)[#data.store_name#if some("store_address") != none [, #some("store_address").replace("\n", ", ")]]
]
#v(1mm)
#rule()
#v(3mm)
#grid(
  columns: (1fr, auto),
  column-gutter: 10mm,
  [
    #text(size: heading-size, weight: "bold", t.bill_to + ",") \
    #v(1.5mm)
    #kv(t.customer_name, data.customer_name)
    #kv(t.book_name, data.book_name)
    #kv(t.author, some("author"))
    #kv(t.publisher, data.publisher)
  ],
  align(right)[
    #text(size: heading-size, weight: "bold", t.receipt_details) \
    #v(1.5mm)
    #kv(t.receipt_no, data.receipt_number)
    #kv(t.receipt_date, fmt-date(data.date))
  ],
)
#v(1mm)
#kv(t.payment_method, option-label("payment_mode", data.payment_mode))
#v(3mm)
#block(width: 100%, fill: luma(245), stroke: 0.6pt + luma(200), inset: (x: 3mm, y: 2.4mm), text(size: heading-size, weight: "bold", t.receipt_summary))
#table(
  columns: (1fr, 1.3fr, auto, auto, auto),
  align: (left, left, right, right, right),
  stroke: (x, y) => (bottom: 0.6pt + luma(200)),
  inset: (x: 3mm, y: 2.2mm),
  ..(t.item, t.description, t.qty, t.price, t.total).map(head => text(weight: "bold", head)),
  data.book_name, if some("description") != none { lines(some("description")) } else { [] }, [#fmt-number(data.quantity)], money(data.book_price), money(total),
)
#align(right, pad(right: 3mm, text(weight: "bold", [#t.total: #money(total)])))
#v(2mm)
#rule()
#v(3mm)
#align(center)[
  #text(weight: "bold", t.thanks) \
  #v(2mm)
  #t.quote_1 \
  #v(1.5mm)
  #t.quote_2
]
