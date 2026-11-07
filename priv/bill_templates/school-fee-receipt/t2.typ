// School fee receipt, design t2: a short receipt voucher, 160 mm wide, in a rounded frame: the school with its branch and phone, a line, the
// number, "Receipt" and the date, the sentence "received with thanks from ... parent of ... the sum of ... towards ... by ...", the amount
// in a small box and the signature. The words of the amount are written out when the field is empty. Reads data.json (next to this file).
// The words come from text.json (`t`), the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)

#let tuition = data.tuition_fee
#let transport = num(data, "transport_fee")
#let other = num(data, "other_fee")
#let late = num(data, "late_fee")
#let total = tuition + transport + other + late
#show: base.with(width: 160mm, margin: (x: 8mm, y: 8mm), size: 10pt)
#set par(leading: 0.7em)
#set block(spacing: 0pt)
#let slate = rgb("#5a5470")
#let payer = if some("parent_name") != none { some("parent_name") } else { data.student_name }
#let words = if some("amount_in_words") != none { some("amount_in_words") } else { amount-words(total) }
#let mode = lower(option-label("payment_mode", data.payment_mode))
#let blank(body) = underline(offset: 2pt, stroke: (paint: luma(90), thickness: 0.5pt, dash: "dotted"), body)

#block(width: 100%, stroke: 1.8pt + slate, radius: 4mm, inset: (x: 7mm, y: 6mm), {
  align(center)[
    #picture(data, "logo", 11mm)
    #text(size: 14pt, weight: "bold", fill: slate, upper(data.school_name)) \
    #v(1.5mm)
    #if some("school_address") != none [#text(size: 8.5pt, [#t.branches: #some("school_address").replace("\n", ", ")]) \ ]
    #v(1mm)
    #if some("school_phone") != none [#text(size: 8.5pt, [#t.cell: #some("school_phone")])]
  ]
  v(2mm)
  line(length: 100%, stroke: 0.8pt + luma(60))
  v(4mm)
  grid(
    columns: (1fr, auto, 1fr),
    [#t.no : #strong(text(size: 12pt, data.receipt_number))],
    align(center, underline(text(size: 11pt, upper(t.receipt)))),
    align(right, [#t.date : #fmt-date(data.date)]),
  )
  v(4mm)
  set par(leading: 0.95em, justify: false)
  text(size: 10.5pt, say(t.received, (payer: payer, pupil: data.student_name, words: if words != none { words } else { money(total) }, purpose: data.fee_period, mode: mode)))
  v(8mm)
  grid(
    columns: (1fr, 42mm),
    align(bottom, box(stroke: 0.8pt + luma(60), inset: (x: 3mm, y: 2.4mm), text(size: 12pt, money(total)))),
    align(right + bottom)[
      #picture(data, "signature", 10mm)
      #line(length: 100%, stroke: 0.5pt + luma(90))
      #v(0.5mm)
      #text(size: 10pt, t.signature)
    ],
  )
})
