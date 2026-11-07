// School fee receipt, design t1: a plain receipt on A5: the school and "Fee receipt", the student, the class and the fee period, a breakup of
// the fees and the total received, and the accounts office. Reads data.json (next to this file). The words come from text.json (`t`),
// the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)

#let tuition = data.tuition_fee
#let transport = num(data, "transport_fee")
#let other = num(data, "other_fee")
#let late = num(data, "late_fee")
#let total = tuition + transport + other + late
#show: base.with(paper: "a5")

#letterhead(data, data.school_name, address: some("school_address"), title: t.fee_receipt)

#details((
  (t.receipt_no, data.receipt_number),
  (t.date, fmt-date(data.date)),
  (t.student, data.student_name),
  (t.class, data.class_name),
  (t.admission_no, some("admission_number")),
  (t.parent, some("parent_name")),
  (t.fee_for, data.fee_period),
  (t.paid_by, option-label("payment_mode", data.payment_mode)),
))

#v(5mm)
#totals(
  (
    (t.tuition_fee, tuition),
    (t.transport_fee, transport),
    (t.other_fee, other),
    (t.late_fee, late),
  ),
  total,
  label: t.total_received,
)

#v(8mm)
#signature-block(data, t.accounts_office)

#footnote(t.keep_receipt)
