// What the form's script says to the visitor. The server sends the texts in the language of the page
// (`data-i18n` on #bill-app, made with Gettext in `TemplateHTML`); a `{name}` in a text is filled in by `t`.
let strings: Record<string, string> = {}

export function loadStrings(json: string | undefined) {
  strings = json ? JSON.parse(json) : {}
}

/** The text for `key` in the language of the page. A text the server did not send shows as its key. */
export function t(key: string, vars: Record<string, string | number> = {}): string {
  const text = strings[key] ?? key
  return text.replace(/\{(\w+)\}/g, (match, name: string) => (name in vars ? String(vars[name]) : match))
}
