// The logo for the header of the e-mails: the mark and the name in cream, on a transparent background, so that it
// sits on the dark green band of the e-mail. E-mail programs block SVG, so it is a PNG, at twice its size (606 x 128
// for a picture of 303 x 64) to stay sharp on phones. Made from the project root with
//
//   typst compile --root . --format png --ppi 144 priv/email/logo.typ priv/static/images/email/logo.png
#set page(width: 303pt, height: 64pt, margin: 0pt, fill: none)
#image("/priv/static/images/logo-on-dark.svg", width: 303pt, height: 64pt)
