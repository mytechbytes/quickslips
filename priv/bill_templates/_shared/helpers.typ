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
  set text(font: text-data.at("fonts", default: ("Noto Sans",)), size: size, lang: text-data.at("lang", default: "en"))
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

/// Amount in words

// "One thousand two hundred fifty rupees and fifty paise only", in the language of the document. The names of
// the currencies, the label and the small words ("and", "only") are in `text.json` under `in_words`; the way a
// number is spoken is one function per language here. Numbers go up to 999,999,999,999. A bigger one, a negative
// one and a currency the language has no name for have no words (`none`).
#let in-words = text-data.at("in_words", default: none)

// "twenty" -> "Twenty". A script without capitals is left as it is.
#let ucfirst(word) = if word == "" { word } else { upper(word.first()) + word.slice(word.first().len()) }

#let million = 1000000
#let billion = 1000000000

// English: "one hundred and twenty-three". The Indian grouping counts in lakhs and crores.
#let en-ones = ("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen")
#let en-tens = ("", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety")
#let en-under-100(n) = {
  if n < 20 { return en-ones.at(n) }
  let unit = calc.rem(n, 10)
  if unit == 0 { en-tens.at(calc.quo(n, 10)) } else { en-tens.at(calc.quo(n, 10)) + "-" + en-ones.at(unit) }
}
#let en-under-1000(n, joiner) = {
  let hundreds = calc.quo(n, 100)
  let rest = calc.rem(n, 100)
  let parts = ()
  if hundreds > 0 { parts.push(en-ones.at(hundreds) + " hundred") }
  if rest > 0 {
    if hundreds > 0 and joiner != "" { parts.push(joiner) }
    parts.push(en-under-100(rest))
  }
  parts.join(" ")
}
#let en-say(n, scales, joiner) = {
  if n == 0 { return "zero" }
  if n < 1000 { return en-under-1000(n, joiner) }
  for (size, name) in scales {
    if n >= size {
      let head = en-say(calc.quo(n, size), scales, joiner) + " " + name
      let rest = calc.rem(n, size)
      if rest == 0 { return head }
      let joint = if rest < 100 and joiner != "" { " " + joiner + " " } else { " " }
      return head + joint + en-say(rest, scales, joiner)
    }
  }
}
#let en-scales = ((billion, "billion"), (million, "million"), (1000, "thousand"))
#let en-indian-scales = ((10000000, "crore"), (100000, "lakh"), (1000, "thousand"))

// Hindi: every number up to 99 has a word of its own; above that lakh and crore, two digits at a time.
#let hi-words = (
  "शून्य", "एक", "दो", "तीन", "चार", "पाँच", "छह", "सात", "आठ", "नौ", "दस",
  "ग्यारह", "बारह", "तेरह", "चौदह", "पंद्रह", "सोलह", "सत्रह", "अठारह", "उन्नीस", "बीस",
  "इक्कीस", "बाईस", "तेईस", "चौबीस", "पच्चीस", "छब्बीस", "सत्ताईस", "अट्ठाईस", "उनतीस", "तीस",
  "इकतीस", "बत्तीस", "तैंतीस", "चौंतीस", "पैंतीस", "छत्तीस", "सैंतीस", "अड़तीस", "उनतालीस", "चालीस",
  "इकतालीस", "बयालीस", "तैंतालीस", "चौंतालीस", "पैंतालीस", "छियालीस", "सैंतालीस", "अड़तालीस", "उनचास", "पचास",
  "इक्यावन", "बावन", "तिरेपन", "चौवन", "पचपन", "छप्पन", "सत्तावन", "अट्ठावन", "उनसठ", "साठ",
  "इकसठ", "बासठ", "तिरसठ", "चौंसठ", "पैंसठ", "छियासठ", "सड़सठ", "अड़सठ", "उनहत्तर", "सत्तर",
  "इकहत्तर", "बहत्तर", "तिहत्तर", "चौहत्तर", "पचहत्तर", "छिहत्तर", "सतहत्तर", "अठहत्तर", "उन्यासी", "अस्सी",
  "इक्यासी", "बयासी", "तिरासी", "चौरासी", "पचासी", "छियासी", "सत्तासी", "अट्ठासी", "नवासी", "नब्बे",
  "इक्यानवे", "बानवे", "तिरानवे", "चौरानवे", "पंचानवे", "छियानवे", "सत्तानवे", "अट्ठानवे", "निन्यानवे",
)
#let hi-scales = ((100000000000, "खरब"), (1000000000, "अरब"), (10000000, "करोड़"), (100000, "लाख"), (1000, "हज़ार"), (100, "सौ"))
#let hi-say(n) = {
  if n == 0 { return hi-words.at(0) }
  let parts = ()
  let rest = n
  for (size, name) in hi-scales {
    let count = calc.quo(rest, size)
    rest = calc.rem(rest, size)
    if count > 0 { parts.push(hi-words.at(count) + " " + name) }
  }
  if rest > 0 { parts.push(hi-words.at(rest)) }
  parts.join(" ")
}

// Spanish: "ciento veintitrés". A one before a noun is "un" ("veintiún"), or "una" before a feminine one.
#let es-ones = ("cero", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez", "once", "doce", "trece", "catorce", "quince", "dieciséis", "diecisiete", "dieciocho", "diecinueve", "veinte", "veintiuno", "veintidós", "veintitrés", "veinticuatro", "veinticinco", "veintiséis", "veintisiete", "veintiocho", "veintinueve")
#let es-tens = ("", "", "", "treinta", "cuarenta", "cincuenta", "sesenta", "setenta", "ochenta", "noventa")
#let es-hundreds = ("", "ciento", "doscientos", "trescientos", "cuatrocientos", "quinientos", "seiscientos", "setecientos", "ochocientos", "novecientos")
#let es-noun-one(word, fem) = {
  if word.ends-with("veintiuno") {
    let ending = if fem { "veintiuna" } else { "veintiún" }
    word.slice(0, word.len() - 9) + ending
  } else if word.ends-with("uno") {
    let ending = if fem { "una" } else { "un" }
    word.slice(0, word.len() - 3) + ending
  } else {
    word
  }
}
#let es-under-100(n, fem) = {
  let word = if n < 30 {
    es-ones.at(n)
  } else if calc.rem(n, 10) == 0 {
    es-tens.at(calc.quo(n, 10))
  } else {
    es-tens.at(calc.quo(n, 10)) + " y " + es-ones.at(calc.rem(n, 10))
  }
  es-noun-one(word, fem)
}
#let es-under-1000(n, fem) = {
  if n == 100 { return "cien" }
  let hundreds = calc.quo(n, 100)
  let rest = calc.rem(n, 100)
  let parts = ()
  if hundreds > 0 {
    let word = es-hundreds.at(hundreds)
    parts.push(if fem and hundreds > 1 { word.slice(0, word.len() - 5) + "entas" } else { word })
  }
  if rest > 0 { parts.push(es-under-100(rest, fem)) }
  parts.join(" ")
}
#let es-say(n, fem) = {
  if n == 0 { return "cero" }
  let parts = ()
  let rest = n
  if rest >= million {
    let count = calc.quo(rest, million)
    rest = calc.rem(rest, million)
    parts.push(if count == 1 { "un millón" } else { es-say(count, false) + " millones" })
  }
  if rest >= 1000 {
    let count = calc.quo(rest, 1000)
    rest = calc.rem(rest, 1000)
    parts.push(if count == 1 { "mil" } else { es-under-1000(count, fem) + " mil" })
  }
  if rest > 0 { parts.push(es-under-1000(rest, fem)) }
  parts.join(" ")
}

// Portuguese: "cento e vinte e três", with an "e" in front of the last part.
#let pt-ones = ("zero", "um", "dois", "três", "quatro", "cinco", "seis", "sete", "oito", "nove", "dez", "onze", "doze", "treze", "catorze", "quinze", "dezesseis", "dezessete", "dezoito", "dezenove")
#let pt-tens = ("", "", "vinte", "trinta", "quarenta", "cinquenta", "sessenta", "setenta", "oitenta", "noventa")
#let pt-hundreds = ("", "cento", "duzentos", "trezentos", "quatrocentos", "quinhentos", "seiscentos", "setecentos", "oitocentos", "novecentos")
#let pt-one-two(n, fem) = if fem and n == 1 { "uma" } else if fem and n == 2 { "duas" } else { pt-ones.at(n) }
#let pt-under-100(n, fem) = {
  if n < 20 { return pt-one-two(n, fem) }
  let unit = calc.rem(n, 10)
  if unit == 0 { pt-tens.at(calc.quo(n, 10)) } else { pt-tens.at(calc.quo(n, 10)) + " e " + pt-one-two(unit, fem) }
}
#let pt-under-1000(n, fem) = {
  if n == 100 { return "cem" }
  let hundreds = calc.quo(n, 100)
  let rest = calc.rem(n, 100)
  if hundreds == 0 { return pt-under-100(rest, fem) }
  let word = pt-hundreds.at(hundreds)
  if fem and hundreds > 1 { word = word.slice(0, word.len() - 2) + "as" }
  if rest == 0 { word } else { word + " e " + pt-under-100(rest, fem) }
}
// What follows "mil" or "milhão" takes an "e" when it is one thing to say ("mil e cem", "um milhão e quinhentos
// mil") and none when it is several ("mil duzentos e trinta").
#let pt-links(rest) = {
  if rest < 100 { return true }
  if rest < 1000 { return calc.rem(rest, 100) == 0 }
  for size in (million, 1000) {
    if rest >= size {
      let count = calc.quo(rest, size)
      return calc.rem(rest, size) == 0 and count < 1000 and (count < 100 or calc.rem(count, 100) == 0)
    }
  }
  false
}
#let pt-say(n, fem) = {
  if n == 0 { return "zero" }
  for (size, one, many) in ((billion, "um bilhão", "bilhões"), (million, "um milhão", "milhões"), (1000, "mil", "mil")) {
    if n >= size {
      let count = calc.quo(n, size)
      let rest = calc.rem(n, size)
      let head = if count == 1 {
        one
      } else if size == 1000 {
        pt-under-1000(count, fem) + " mil"
      } else {
        pt-under-1000(count, false) + " " + many
      }
      if rest == 0 { return head }
      let joint = if pt-links(rest) { " e " } else { " " }
      return head + joint + pt-say(rest, fem)
    }
  }
  pt-under-1000(n, fem)
}

// Italian: written as one word up to a million ("milleduecentotrentaquattro"), with spaces above.
#let it-ones = ("zero", "uno", "due", "tre", "quattro", "cinque", "sei", "sette", "otto", "nove", "dieci", "undici", "dodici", "tredici", "quattordici", "quindici", "sedici", "diciassette", "diciotto", "diciannove")
#let it-tens = ("", "", "venti", "trenta", "quaranta", "cinquanta", "sessanta", "settanta", "ottanta", "novanta")
#let it-under-100(n) = {
  if n < 20 { return it-ones.at(n) }
  let unit = calc.rem(n, 10)
  let tens = it-tens.at(calc.quo(n, 10))
  if unit == 0 { return tens }
  // ventuno, ventotto: the tens lose their last vowel in front of "uno" and "otto".
  let stem = if unit == 1 or unit == 8 { tens.slice(0, tens.len() - 1) } else { tens }
  stem + it-ones.at(unit)
}
#let it-under-1000(n) = {
  let hundreds = calc.quo(n, 100)
  let rest = calc.rem(n, 100)
  if hundreds == 0 { return it-under-100(rest) }
  let word = if hundreds == 1 { "cento" } else { it-ones.at(hundreds) + "cento" }
  if rest == 0 { return word }
  let tail = it-under-100(rest)
  // centottanta, centotto.
  (if tail.starts-with("otto") { word.slice(0, word.len() - 1) } else { word }) + tail
}
// A number before a noun: "un euro", "una sterlina", "ventun euro" ("centouno" and "milleuno" keep their uno); "tré" is
// accented at the end of a longer number. `value` is the number the word says.
#let it-fix(word, fem, value) = {
  if word.ends-with("uno") and (value == 1 or calc.rem(value, 100) != 1) {
    let ending = if fem { "una" } else { "un" }
    word.slice(0, word.len() - 3) + ending
  } else if word.ends-with("tre") and word.len() > 3 {
    word.slice(0, word.len() - 3) + "tré"
  } else {
    word
  }
}
#let it-under-million(n) = {
  if n < 1000 { return it-under-1000(n) }
  let thousands = calc.quo(n, 1000)
  let rest = calc.rem(n, 1000)
  let head = if thousands == 1 { "mille" } else { it-under-1000(thousands) + "mila" }
  if rest == 0 { head } else { head + it-under-1000(rest) }
}
#let it-say(n, fem) = {
  if n == 0 { return "zero" }
  let parts = ()
  let rest = n
  for (size, one, many) in ((billion, "un miliardo", "miliardi"), (million, "un milione", "milioni")) {
    if rest >= size {
      let count = calc.quo(rest, size)
      rest = calc.rem(rest, size)
      parts.push(if count == 1 { one } else { it-fix(it-under-1000(count), false, count) + " " + many })
    }
  }
  if rest > 0 { parts.push(it-fix(it-under-million(rest), fem, rest)) }
  parts.join(" ")
}

// French: "cent vingt-trois", "quatre-vingt-dix-neuf". Cent and vingt take an s at the end of a number
// ("deux cents euros") and none when more follows ("deux cent mille euros").
#let fr-ones = ("zéro", "un", "deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix", "onze", "douze", "treize", "quatorze", "quinze", "seize", "dix-sept", "dix-huit", "dix-neuf")
#let fr-tens = ("", "", "vingt", "trente", "quarante", "cinquante", "soixante")
#let fr-under-100(n, closing) = {
  if n < 20 { return fr-ones.at(n) }
  let unit = calc.rem(n, 10)
  if n < 70 {
    let tens = fr-tens.at(calc.quo(n, 10))
    if unit == 0 { tens } else if unit == 1 { tens + " et un" } else { tens + "-" + fr-ones.at(unit) }
  } else if n < 80 {
    if unit == 1 { "soixante et onze" } else { "soixante-" + fr-ones.at(10 + unit) }
  } else if n == 80 {
    if closing { "quatre-vingts" } else { "quatre-vingt" }
  } else {
    "quatre-vingt-" + fr-ones.at(n - 80)
  }
}
#let fr-under-1000(n, closing) = {
  let hundreds = calc.quo(n, 100)
  let rest = calc.rem(n, 100)
  if hundreds == 0 { return fr-under-100(rest, closing) }
  let word = if hundreds == 1 {
    "cent"
  } else if rest == 0 and closing {
    fr-ones.at(hundreds) + " cents"
  } else {
    fr-ones.at(hundreds) + " cent"
  }
  if rest == 0 { word } else { word + " " + fr-under-100(rest, closing) }
}
#let fr-say(n, fem) = {
  if n == 0 { return "zéro" }
  let parts = ()
  let rest = n
  for (size, one, many) in ((billion, "un milliard", "milliards"), (million, "un million", "millions")) {
    if rest >= size {
      let count = calc.quo(rest, size)
      rest = calc.rem(rest, size)
      parts.push(if count == 1 { one } else { fr-under-1000(count, true) + " " + many })
    }
  }
  if rest >= 1000 {
    let count = calc.quo(rest, 1000)
    rest = calc.rem(rest, 1000)
    parts.push(if count == 1 { "mille" } else { fr-under-1000(count, false) + " mille" })
  }
  if rest > 0 { parts.push(fr-under-1000(rest, true)) }
  let out = parts.join(" ")
  if fem and out.ends-with("un") { out.slice(0, out.len() - 2) + "une" } else { out }
}

// German: written as one word up to a million ("dreihundertvierundfünfzigtausend"), with spaces above.
#let de-ones = ("null", "ein", "zwei", "drei", "vier", "fünf", "sechs", "sieben", "acht", "neun", "zehn", "elf", "zwölf", "dreizehn", "vierzehn", "fünfzehn", "sechzehn", "siebzehn", "achtzehn", "neunzehn")
#let de-tens = ("", "", "zwanzig", "dreißig", "vierzig", "fünfzig", "sechzig", "siebzig", "achtzig", "neunzig")
#let de-under-100(n) = {
  if n < 20 { return de-ones.at(n) }
  let unit = calc.rem(n, 10)
  let tens = de-tens.at(calc.quo(n, 10))
  if unit == 0 { tens } else { de-ones.at(unit) + "und" + tens }
}
#let de-under-1000(n) = {
  let hundreds = calc.quo(n, 100)
  let rest = calc.rem(n, 100)
  (if hundreds > 0 { de-ones.at(hundreds) + "hundert" } else { "" }) + (if rest > 0 { de-under-100(rest) } else { "" })
}
// The last "ein" of a number that ends in one is "eins" ("einhunderteins"); alone, before a noun, it is "ein"/"eine".
#let de-end(word) = if word.ends-with("ein") { word + "s" } else { word }
#let de-under-million(n) = {
  if n < 1000 { return de-under-1000(n) }
  let thousands = calc.quo(n, 1000)
  let rest = calc.rem(n, 1000)
  de-under-1000(thousands) + "tausend" + de-under-1000(rest)
}
#let de-say(n, fem) = {
  if n == 0 { return "null" }
  if n == 1 { return if fem { "eine" } else { "ein" } }
  let parts = ()
  let rest = n
  for (size, one, many) in ((billion, "eine Milliarde", "Milliarden"), (million, "eine Million", "Millionen")) {
    if rest >= size {
      let count = calc.quo(rest, size)
      rest = calc.rem(rest, size)
      parts.push(if count == 1 { one } else { de-end(de-under-1000(count)) + " " + many })
    }
  }
  if rest > 0 { parts.push(de-end(de-under-million(rest))) }
  parts.join(" ")
}

// Chinese and Japanese: groups of four digits (万, 亿), a unit for each place. Chinese puts a 零 where a place is
// skipped (一万零五); Japanese does not.
#let cjk-group(n, digits, units, fill-zero) = {
  let out = ""
  let skipped = false
  for place in (3, 2, 1, 0) {
    let digit = calc.rem(calc.quo(n, int(calc.pow(10, place))), 10)
    if digit == 0 {
      if out != "" { skipped = true }
    } else {
      if skipped and fill-zero { out += digits.at(0) }
      skipped = false
      out += digits.at(digit) + units.at(place)
    }
  }
  out
}
#let cjk-say(n, digits, units, marks, fill-zero) = {
  if n == 0 { return digits.at(0) }
  let out = ""
  let skipped = false
  let groups = (
    (calc.quo(n, 100000000), marks.at(0)),
    (calc.quo(calc.rem(n, 100000000), 10000), marks.at(1)),
    (calc.rem(n, 10000), ""),
  )
  for (group, mark) in groups {
    if group == 0 {
      if out != "" { skipped = true }
      continue
    }
    if out != "" and fill-zero and (skipped or group < 1000) { out += digits.at(0) }
    skipped = false
    out += cjk-group(group, digits, units, fill-zero) + mark
  }
  out
}
#let zh-say(n) = cjk-say(n, ("零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖"), ("", "拾", "佰", "仟"), ("亿", "万"), true)
#let ja-say(n) = cjk-say(n, ("零", "壱", "弐", "参", "四", "五", "六", "七", "八", "九"), ("", "拾", "百", "千"), ("億", "万"), false)

// The number of the language, for a noun of the gender `fem`.
#let say-number(language, n, fem) = {
  if language == "hi" {
    hi-say(n)
  } else if language == "es" {
    es-say(n, fem)
  } else if language == "pt" {
    pt-say(n, fem)
  } else if language == "it" {
    it-say(n, fem)
  } else if language == "fr" {
    fr-say(n, fem)
  } else if language == "de" {
    de-say(n, fem)
  } else if language == "zh" {
    zh-say(n)
  } else if language == "ja" {
    ja-say(n)
  } else {
    let indian = region.number.grouping == "indian"
    en-say(n, if indian { en-indian-scales } else { en-scales }, in-words.at("joiner", default: ""))
  }
}

// The amount in words, or `none`. `1234.5` in India, in English: "One thousand two hundred and thirty-four rupees
// and fifty paise only".
#let amount-words(amount) = {
  if in-words == none or amount < 0 { return none }
  let currency = in-words.currencies.at(region.currency.code, default: none)
  if currency == none { return none }
  let scale = int(calc.pow(10, region.currency.decimals))
  let minor = int(calc.round(amount * scale))
  let whole = calc.quo(minor, scale)
  let cents = calc.rem(minor, scale)
  if whole >= 1000000 * million { return none }

  let language = text-data.at("lang", default: "en")
  let fem = currency.at("gender", default: "m") == "f"
  let minor-fem = currency.at("minor_gender", default: "m") == "f"
  let name(count, forms) = {
    // Most languages use the singular for exactly one; French for anything under two.
    let singular = if language == "fr" { count < 2 } else { count == 1 }
    if singular { forms.at(0) } else { forms.at(1) }
  }
  let unit = name(whole, (currency.one, currency.other))
  let minor-unit = name(cents, (currency.minor_one, currency.minor_other))
  let only = in-words.at("only", default: "")
  let whole-only = in-words.at("whole_only", default: "")
  let prefix = currency.at("prefix", default: in-words.at("prefix", default: ""))

  let result = if language == "zh" or language == "ja" {
    // 壹佰贰拾叁元肆角伍分, 金壱万弐千円也: no spaces, and a closing mark when there is no small change.
    let out = ""
    if whole > 0 or cents == 0 { out += say-number(language, whole, false) + unit }
    if cents > 0 {
      let tenth = currency.at("minor_tenth", default: none)
      if tenth != none {
        let digits = ("零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖")
        let jiao = calc.quo(cents, 10)
        let fen = calc.rem(cents, 10)
        if jiao > 0 { out += digits.at(jiao) + tenth }
        if fen > 0 { out += (if jiao == 0 and whole > 0 { digits.at(0) } else { "" }) + digits.at(fen) + currency.minor_one }
      } else {
        out += say-number(language, cents, false) + minor-unit
      }
    } else {
      out += whole-only
    }
    prefix + out + only
  } else {
    // "un millón de euros", "un million d'euros", "un milione di euro": exact millions are joined to the noun with "de".
    let linked = whole >= million and calc.rem(whole, million) == 0
    let joint = if not linked or language in ("en", "hi", "de") {
      " "
    } else if language == "fr" and unit.first() in ("a", "e", "i", "o", "u", "é", "è", "h") {
      " d'"
    } else if language == "it" {
      " di "
    } else {
      " de "
    }
    let parts = (say-number(language, whole, fem) + joint + unit,)
    if cents > 0 {
      let join = in-words.at("and", default: "")
      if join != "" { parts.push(join) }
      parts.push(say-number(language, cents, minor-fem) + " " + minor-unit)
    }
    if only != "" { parts.push(only) }
    // The d' is attached to the noun: no space after it.
    ucfirst(parts.join(" ").replace(" d' ", " d'"))
  }
  result
}

// The line for under a total: "Amount in words: Two hundred rupees only". Nothing where there are no words.
#let amount-words-line(amount) = {
  let words = amount-words(amount)
  if words == none { return none }
  align(right, text(size: 8.5pt)[#text(fill: muted)[#in-words.label:] #words])
}

/// Pieces of a page

#let rule() = line(length: 100%, stroke: 0.5pt + hairline)

// The picture of a saved business: the server (and the browser preview) put the file name in the data
// under `key`, "logo" or "signature". Nothing is drawn when there is none.
#let picture(data, key, height) = {
  let name = data.at(key, default: none)
  if name != none { image("/" + name, height: height) }
}

// What the bill does with tax: "none", "added" (the rate is added to the amount) or "included" (the amount holds it).
#let tax-mode = text-data.at("tax_mode", default: "none")

// The three amounts of a bill with tax, whichever way the country does it: `(base, tax, total)`.
#let tax-split(amount, rate) = {
  if tax-mode == "included" {
    let base = amount / (1 + rate / 100)
    (base: base, tax: amount - base, total: amount)
  } else {
    let tax = amount * rate / 100
    (base: amount, tax: tax, total: amount + tax)
  }
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

// The sums under a table: `rows` is an array of (label, amount), then the total in bold and the total in words.
// A row whose amount is 0 is left out, so a bill without a toll or a tax doesn't print empty lines.
#let totals(rows, total, label: "Total") = {
  align(right, block(width: 86mm, {
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
  let words = amount-words-line(total)
  if words != none { v(1.5mm); words }
}

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
