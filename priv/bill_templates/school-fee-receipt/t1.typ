// School fee receipt, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5")

#let tuition = data.tuition_fee
#let transport = num(data, "transport_fee")
#let other = num(data, "other_fee")
#let late = num(data, "late_fee")
#let total = tuition + transport + other + late

#letterhead(data, data.school_name, address: opt(data, "school_address"), title: "Fee receipt")

#details((
  ([Receipt no.], data.receipt_number),
  ([Date], fmt-date(data.date)),
  ([Student], data.student_name),
  ([Class], data.class_name),
  ([Admission no.], opt(data, "admission_number")),
  ([Parent or guardian], opt(data, "parent_name")),
  ([Fee for], data.fee_period),
  ([Paid by], data.payment_mode),
))

#v(5mm)
#totals(
  (
    ([Tuition fee], tuition),
    ([Transport fee], transport),
    ([Exam, activity and other fees], other),
    ([Late fee], late),
  ),
  total,
  label: "Total received",
)

#v(8mm)
#signature-block(data, [Accounts office])

#footnote[Please keep this receipt for your records.]
