// Daily helper receipt, design t2: the certificate of the employee, and below it the payment receipt and
// acknowledgement that the helper signs.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(width: 150mm, margin: (x: 13mm, y: 12mm), size: 10pt)
// On an A5 sheet the two parts do not fit one page: the acknowledgement starts the next one.
#let small-sheet = data.at("paper_size", default: none) == "a5"
#set par(leading: 0.75em)

// What the helper is paid in a month, and the revenue stamp (stuck on a receipt in India only).
#let net = data.salary
#let stamp(width: 24mm, height: 28mm) = if region.country == "in" {
  revenue-stamp(data, t.revenue_stamp, width: width, height: height)
}
#let role = data.working_as
#let declaration = opt(data, "declaration")
#let employee = data.employer_name
// A receipt for each month chosen, or one for the quarter, half-year or year (see `salary-periods` of the helpers), one on
// each page of the PDF.
#let receipts = salary-periods(data)
#for (i, receipt) in receipts.enumerate() [
#if i > 0 { pagebreak() }
#let month = receipt.label
#let when = receipt.date
#let memo = receipt.number
#let net = net * receipt.months
#let heading(content) = align(center, block(width: 100%, text(size: 12pt, weight: "bold", content) + v(0.6mm) + line(length: 100%, stroke: 0.7pt)))
#let period = receipt.months > 1
#let address = opt(data, "employer_address")

#v(1mm)
#align(center, box(width: 60mm, heading(t.title)))
#v(3mm)
#say(if period { t.ack_certify_period } else { t.ack_certify }, (amount: money(net), helper: data.helper_name, role: role, month: month))
#if declaration != none [ #v(1mm) #lines(declaration)]
#v(1mm)
#t.ack_reimburse
#v(1mm)
#t.ack_further
#v(3mm)
*#t.employer_name:* #data.employer_name

#if address != none [ \ *#t.employer_address:* #lines(address)]
#v(1mm)
#grid(
  columns: (1fr, auto),
  [],
  align(bottom, signature-block(data, t.employer_signature, name: employee)),
)

#if small-sheet { pagebreak() } else [
  #v(2mm)
  #line(length: 100%, stroke: (paint: luma(120), thickness: 0.7pt, dash: "dashed"))
  #v(3mm)
]
#heading(t.ack_heading)
#v(2mm)
#if memo != none [*#t.memo_number:* #memo \ ]
#if when != none [*#t.receipt_date:* #fmt-date(when) \ ]
*#t.salary_month:* #month \
*#t.helper_name:* #data.helper_name#v(2mm)
#let words = amount-words(net)
#let received = if period { t.ack_received_period } else { t.ack_received }
#let received = if words == none { received.replace(" ({words})", "").replace("（{words}）", "") } else { received }
#say(received, (amount: money(net), words: if words == none { "" } else { words }, month: month, employer: data.employer_name))
#v(2mm)
#grid(
  columns: (1fr, auto),
  stamp(),
  align(bottom, signature-block(data, t.ack_thumb, key: "driver_signature")),
)
#align(right)[*#t.helper_name:* #data.helper_name]
]
