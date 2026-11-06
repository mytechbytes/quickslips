// Medical bill, design t1.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#show: base.with(paper: "a5")

#let consultation = num(data, "consultation_fee")
#let medicines = num(data, "medicines_cost")
#let tests = num(data, "tests_cost")
#let other = num(data, "other_charges")
#let discount = num(data, "discount")
#let total = consultation + medicines + tests + other - discount

#letterhead(data, data.clinic_name, address: opt(data, "clinic_address"), title: "Medical bill")

#details((
  ([Bill no.], data.bill_number),
  ([Date], fmt-date(data.date)),
  ([Registration no.], opt(data, "registration_number")),
  ([Patient], data.patient_name),
  ([Age and sex], opt(data, "patient_details")),
  ([Doctor], opt(data, "doctor_name")),
))

#v(6mm)
#totals(
  (
    ([Consultation], consultation),
    ([Medicines], medicines),
    ([Tests and procedures], tests),
    ([Other charges], other),
    ([Discount], -discount),
  ),
  total,
)

#v(2mm)
#align(right)[#text(size: 9pt, fill: muted)[Paid by #data.payment_mode]]

#v(6mm)
#signature-block(data, [Doctor or authorised signatory])

#footnote[Get well soon.]
