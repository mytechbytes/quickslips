// Child education allowance bill, design t1: the proforma for the reimbursement of a children education allowance or hostel subsidy, 120 mm
// wide: the title, the academic year, the application sentence, the date, the numbered details of the claimant and the spouse in a ruled
// table, the details of the children (sequence, name, date of birth, standard, school) and the reimbursement of expenditure (sequence,
// period, rate, amount claimed, remarks) with the total claimed. Reads data.json (next to this file). The words come from text.json (`t`),
// the number and date formats from region.json.
#import "_shared/helpers.typ": *
#let data = json("data.json")
#let some(key) = opt(data, key)
#show: base.with(width: 120mm, margin: (x: 8mm, y: 8mm), size: 8.5pt)
#set par(leading: 0.55em)
#set block(spacing: 0pt)

#let rows = item-rows(data)
#let total = sum-of(rows.map(row => row.amount))
#let frame = 0.7pt + luma(40)
#let batch-of(index) = data.items.at(index, default: (:)).at("batch", default: "")
#let children = ((1, "child1"), (2, "child2")).filter(((n, key)) => some(key + "_name") != none)
#let small(body) = text(size: 7.5pt, body)

#align(center, text(size: 11pt, weight: "bold", underline(upper(t.title))))
#v(3mm)
#text(weight: "bold", underline([#upper(t.claim_for): #data.academic_year]))
#v(2mm)
#t.intro
#v(2mm)
#t.date: #fmt-date(data.claim_date)
#v(2mm)
#table(
  columns: (auto, 1fr, auto, 1.1fr),
  stroke: frame,
  inset: 2mm,
  align: (center + horizon, left + horizon, center + horizon, left + horizon),
  [1.], t.q1, [:], some("name_rank"),
  [2.], t.q2, [:], data.personal_number,
  [3.], t.q3, [:], data.designation,
  [4.], t.q4, [:], data.unit,
  [5.], t.q5, [:], data.spouse_employed,
  [6.], t.q6, [:], some("spouse_office"),
)
#v(0mm)
#block(width: 100%, stroke: (left: frame, right: frame), inset: 2mm, text(weight: "bold", [7. #t.children_title]))
#table(
  columns: (auto, 1fr, auto, auto, 1.2fr),
  stroke: frame,
  inset: 2mm,
  align: (center, left, center, center, left),
  ..(t.sequence, t.child_name, t.dob, [#t.standard (#t.ay #data.academic_year)], t.school).map(head => text(size: 7pt, weight: "bold", head)),
  ..children.map(((n, key)) => ([#n], some(key + "_name"), if some(key + "_dob") != none { fmt-date(some(key + "_dob")) } else { [] }, some(key + "_standard"), some(key + "_school"))).flatten(),
)
#v(3mm)
#text(weight: "bold", [8. #t.expenditure_title])
#v(1mm)
#table(
  columns: (auto, 2fr, auto, auto, 1fr),
  stroke: frame,
  inset: 2mm,
  align: (center, left, right, right, left),
  ..(t.sequence, t.period, [#t.rate_cea (#region.currency.symbol)], t.amount_claimed, t.remarks).map(head => text(size: 7pt, weight: "bold", head)),
  ..rows.enumerate().map(((i, row)) => (if row.code != "" { row.code } else { [#(i + 1)] }, [#row.name#if row.qty != 1 and row.qty != 0 [ (#fmt-number(row.qty) #t.months)]], money(row.rate), money(row.amount), batch-of(i))).flatten(),
  table.cell(colspan: 3, align: right, strong(t.total_claimed + " " + region.currency.symbol)), strong(money(total)), [],
)
