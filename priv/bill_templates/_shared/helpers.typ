// Helpers shared by every template (Task 8.4). A template starts with
//
//   #import "_shared/helpers.typ": *
//   #let data = json("data.json")
//   #show: base.with(paper: "a5")
//
// The helpers get `data` as an argument. `json("data.json")` is read from the folder of the file that
// calls it, which for a helper would be `_shared/`, not the template's folder. For the same reason a
// picture is named with a leading "/" (the root of the project): `image("/logo.png")` finds the logo
// wherever the call is made.
//
// Two more files sit at the root of the project, next to `data.json`. The server and the browser preview
// both write them, so every template can read them:
//
//   text.json    the words of the document's language: `lang`, `months`, `print` (what the template prints)
//                and `options` (the names of the options of its select fields)
//   region.json  what the country and the currency of the document decide: the currency sign, how numbers
//                are grouped and which way round a date is written

#let preview = sys.inputs.at("mode", default: "final") == "preview"
#let muted = luma(110)
#let hairline = luma(180)

#let text-data = json("/text.json")
#let region = json("/region.json")

// The words a template prints, like `t.total`. A template that has none prints its own English.
#let t = text-data.at("print", default: (:))

// The name of an option of a select field in the language of the document: the data holds the option itself
// ("Petrol"), the page shows its name ("पेट्रोल"). An option without a name shows as it is.
#let option-label(field, value) = {
  let names = text-data.at("options", default: (:)).at(field, default: (:))
  names.at(value, default: value)
}

// The page: size, margins, font, and the watermark of the preview. Use it with `#show: base.with(...)`.
#let base(paper: "a5", margin: 14mm, size: 10pt, body) = {
  set page(
    paper: paper,
    margin: margin,
    background: if preview {
      rotate(-30deg, text(size: 54pt, weight: "bold", fill: luma(225))[QUICK SLIPS])
    },
  )
  set text(font: "Noto Sans", size: size, lang: text-data.at("lang", default: "en"))
  body
}

/// Data

// An optional field may be missing or empty: `none` then.
#let opt(data, key) = {
  let value = data.at(key, default: none)
  if value == none or value == "" { none } else { value }
}

// An optional number: 0 when it is missing.
#let num(data, key) = data.at(key, default: 0)

// Text of a textarea: a new line in it is a line break on the page.
#let lines(text-with-breaks) = text-with-breaks.split("\n").join(linebreak())

/// Dates

// The names of the months in the language of the document.
#let months = text-data.months

#let to-date(iso) = {
  let (y, m, d) = iso.split("-").map(int)
  datetime(year: y, month: m, day: d)
}

// "2026-10-12" as 12/10/2026, or 10/12/2026 where the month comes first. The order and the separator
// are the country's.
#let fmt-date(iso) = {
  let sep = region.date.separator
  let parts = if region.date.order == "mdy" {
    ("[month]", "[day]", "[year]")
  } else if region.date.order == "ymd" {
    ("[year]", "[month]", "[day]")
  } else {
    ("[day]", "[month]", "[year]")
  }
  to-date(iso).display(parts.join(sep))
}

#let month-label(ym) = {
  let (y, m) = ym.split("-").map(int)
  months.at(m - 1) + " " + str(y)
}

// Whole days from one date to another, at least 1 (for nights in a hotel, days in a plan).
#let days-between(from, to) = calc.max(1, (to-date(to) - to-date(from)).days())

/// Money

// "1234567" -> "12,34,567": Indian grouping, the last three digits and then pairs.
#let group-indian(digits, sep: ",") = {
  let n = digits.len()
  if n <= 3 { return digits }
  let rest = digits.slice(0, n - 3)
  let groups = (digits.slice(n - 3),)
  while rest.len() > 2 {
    groups.insert(0, rest.slice(rest.len() - 2))
    rest = rest.slice(0, rest.len() - 2)
  }
  if rest.len() > 0 { groups.insert(0, rest) }
  groups.join(sep)
}

// "1234567" -> "1,234,567": groups of three.
#let group-standard(digits, sep: ",") = {
  let groups = ()
  let rest = digits
  while rest.len() > 3 {
    groups.insert(0, rest.slice(rest.len() - 3))
    rest = rest.slice(0, rest.len() - 3)
  }
  groups.insert(0, rest)
  groups.join(sep)
}

// The whole part of a number with the grouping of the country.
#let group-digits(digits) = if region.number.grouping == "indian" {
  group-indian(digits, sep: region.number.group)
} else {
  group-standard(digits, sep: region.number.group)
}

// 105000 -> "₹ 1,05,000.00" in India and "105.000,00 €" in Spain: the sign, the grouping, the decimal mark and
// the number of decimals follow the country and the currency. It works on the smallest unit (paise, cents), so
// there is no float noise in the decimals.
#let money(n) = {
  let decimals = region.currency.decimals
  let scale = int(calc.pow(10, decimals))
  let minor = int(calc.round(n * scale))
  let sign = if minor < 0 { "-" } else { "" }
  minor = calc.abs(minor)
  let fraction = str(calc.rem(minor, scale))
  let decimals-text = if decimals == 0 { "" } else {
    region.number.decimal + "0" * (decimals - fraction.len()) + fraction
  }
  let amount = group-digits(str(calc.quo(minor, scale))) + decimals-text
  let gap = if region.money.space { "\u{a0}" } else { "" }
  if region.money.position == "after" {
    sign + amount + gap + region.currency.symbol
  } else {
    region.currency.symbol + gap + sign + amount
  }
}

// A plain number (a quantity, a distance) with the decimal mark of the country: 28.5 -> "28,5" in Spain.
#let fmt-number(n, digits: 3) = str(calc.round(n, digits: digits)).replace(".", region.number.decimal)

// A percentage of an amount, rounded to paise.
#let percent(amount, rate) = calc.round(amount * rate / 100, digits: 2)

// The rows of a table of items (a field of type `items`): each is a dictionary with `name`, `qty`, `rate` and
// `amount` (quantity times rate). A cell that is missing counts as empty, so a row that is half typed in the
// browser preview still draws.
#let item-rows(data, key: "items") = {
  let rows = data.at(key, default: ())
  rows.map(row => {
    let qty = row.at("qty", default: 0)
    let rate = row.at("rate", default: 0)
    (name: row.at("name", default: ""), qty: qty, rate: rate, amount: qty * rate)
  })
}

#let sum-of(values) = values.sum(default: 0)

/// Pieces of a page

#let rule() = line(length: 100%, stroke: 0.5pt + hairline)

// The picture of a saved business: the server (and the browser preview) put the file name in the data
// under `key`, "logo" or "signature". Nothing is drawn when there is none.
#let picture(data, key, height) = {
  let name = data.at(key, default: none)
  if name != none { image("/" + name, height: height) }
}

// How the tax of the country is called ("GST", "IVA") and what its registration number is called ("GSTIN", "NIF").
#let tax-data = region.at("tax", default: (:))
#let tax-name = tax-data.at("name", default: "")
#let tax-id-label = tax-data.at("id", default: (:)).at("label", default: "GSTIN")

// The top of a document: the logo, the seller and the kind of document, then a line. `gstin` is the tax-registration
// number, `ids` other registration numbers to print under it (an array of content, like `([FSSAI Lic. No.: 1234],)`).
#let letterhead(data, seller, address: none, gstin: none, ids: (), title: none) = {
  grid(
    columns: (1fr, auto),
    column-gutter: 6mm,
    {
      let logo = picture(data, "logo", 14mm)
      if logo != none { logo; v(1.5mm) }
      text(size: 14pt, weight: "bold", seller)
      if address != none { linebreak(); text(size: 9pt, fill: muted, lines(address)) }
      if gstin != none { linebreak(); text(size: 9pt, fill: muted)[#tax-id-label: #gstin] }
      for id in ids { linebreak(); text(size: 9pt, fill: muted, id) }
    },
    if title != none { align(right + top, text(size: 12pt, weight: "bold", fill: muted, upper(title))) },
  )
  v(2mm)
  rule()
  v(3mm)
}

// Small labels over values, in `columns` columns. `items` is an array of (label, value); an item whose
// value is `none` is left out.
#let details(items, columns: 2) = {
  let shown = items.filter(item => item.at(1) != none)
  grid(
    columns: (1fr,) * columns,
    row-gutter: 4.5mm,
    column-gutter: 6mm,
    ..shown.map(((label, value)) => [#text(size: 7.5pt, fill: muted)[#upper(label)] \ #value]),
  )
}

// A table with a head row. `rows` is an array of arrays of content; `align` has one entry per column.
#let bill-table(head, rows, columns: none, align: none) = {
  let columns = if columns == none { (1fr,) + (auto,) * (head.len() - 1) } else { columns }
  let align = if align == none { (left,) + (right,) * (head.len() - 1) } else { align }
  // The head is repeated on the next page when a long table runs over.
  table(
    columns: columns,
    align: align,
    stroke: none,
    inset: (x: 2mm, y: 2.6mm),
    table.header(table.hline(stroke: 0.5pt), ..head.map(cell => strong(cell)), table.hline(stroke: 0.5pt)),
    ..rows.flatten(),
    table.hline(stroke: 0.5pt),
  )
}

// The sums under a table: `rows` is an array of (label, amount), then the total in bold. A row whose
// amount is 0 is left out, so a bill without a toll or a tax doesn't print empty lines.
#let totals(rows, total, label: "Total") = align(right, block(width: 86mm, {
  set align(left)
  grid(
    columns: (1fr, auto),
    row-gutter: 2.2mm,
    column-gutter: 6mm,
    ..rows
      .filter(row => row.at(1) != 0)
      .map(((name, amount)) => (text(fill: muted)[#name], align(right)[#money(amount)]))
      .flatten(),
  )
  v(1.5mm)
  line(length: 100%, stroke: 0.5pt)
  v(1.5mm)
  grid(
    columns: (1fr, auto),
    column-gutter: 6mm,
    text(weight: "bold")[#label],
    align(right, text(size: 12pt, weight: "bold")[#money(total)]),
  )
}))

// The signature of a saved business above a line, with who it is. With no picture the space is left to
// sign by hand.
#let signature-block(data, label, name: none) = align(right, block(width: 52mm, {
  let signature = picture(data, "signature", 13mm)
  if signature != none { signature } else { v(13mm) }
  line(length: 100%, stroke: 0.5pt)
  v(-1mm)
  if name != none { strong(name); linebreak() }
  text(size: 9pt, fill: muted, label)
}))

// A line of small print at the bottom of the page.
#let footnote(content) = place(bottom + center, text(size: 8pt, fill: muted, content))
