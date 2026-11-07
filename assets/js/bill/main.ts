import { buildForm, type Business, type BillData, type Schema } from "./form"
import { createPreview } from "./preview"
import { downloadPdf } from "./download"
import { createTurnstile } from "./turnstile"
import { loadStrings, t } from "./i18n"
import { chosenCurrency } from "../locale"

type Quota = { remaining: number; limit: number; tier: string }

/**
 * Starts the form, the preview and the download on the element `#bill-app` of a bill's page, and returns what to
 * call when the page goes away (a live navigation takes the element with it, but not the preview's worker).
 */
export function mountBillApp(root: HTMLElement): () => void {
  loadStrings(root.dataset.i18n)

  const siteKey = root.dataset.turnstileSiteKey
  const turnstile = siteKey
    ? createTurnstile(root.querySelector<HTMLElement>("#turnstile-box")!, siteKey).catch(() => null)
    : null

  const badge = root.querySelector<HTMLElement>("#quota-badge")!
  const loginPrompt = root.querySelector<HTMLElement>("#login-prompt")!
  const button = root.querySelector<HTMLButtonElement>("#download-button")!
  const status = root.querySelector<HTMLElement>("#bill-status")!
  const schema: Schema = JSON.parse(root.dataset.schema!)
  const businesses: Business[] = JSON.parse(root.dataset.businesses ?? "[]")
  const sample: BillData = JSON.parse(root.dataset.sample!)
  const form = root.querySelector<HTMLFormElement>("#bill-form")!
  // The language and country of the page ("hi-in"). The document may be made for another country (an edited one)
  // and the currency may be the visitor's own, so what depends on them is kept in `region` and changes with it.
  const locale = root.dataset.locale!
  const language = locale.split("-")[0]
  let region = JSON.parse(root.dataset.region!)
  // Amounts as the country writes them: ₹1,23,456.00 in India, 1.234,56 € in Spain.
  const makeMoney = (r: typeof region) =>
    new Intl.NumberFormat(`${language}-${String(r.country).toUpperCase()}`, {
      style: "currency",
      currency: r.currency.code,
      minimumFractionDigits: r.currency.decimals,
      maximumFractionDigits: r.currency.decimals,
    })
  let money = makeMoney(region)
  const preview = createPreview({
    workerUrl: root.dataset.worker!,
    slug: schema.slug,
    template: root.dataset.template!,
    container: root.querySelector<HTMLElement>("#bill-preview")!,
    status: root.querySelector<HTMLElement>("#bill-status")!,
    text: root.dataset.text!,
    region: root.dataset.region!,
    fonts: JSON.parse(root.dataset.fonts ?? "[]"),
  })
  preview.renderNow(sample)
  // The saved business the user picked, if any: its logo and signature go on the preview and the PDF.
  let business: Business | null = null
  function useBusiness(picked: Business | null) {
    business = picked
    preview.setBusiness(picked)
  }
  // The country and the currency are chosen in the switch of the site (language, country and currency:
  // `UI.locale_dialog/1`), for every page. The country is the page's; the currency is the visitor's choice, or the
  // country's own (see `followChoice` below).

  const mountForm = (initial: BillData) => {
    const built = buildForm(
      form,
      schema,
      initial,
      (data) => preview.schedule(data),
      businesses,
      useBusiness,
      { currency: region.currency.symbol, tax: region.tax?.name, tax_id: region.tax?.id?.label },
      (amount) => money.format(amount),
    )
    return built
  }
  let ui = mountForm(sample)

  // The design of the bill: its own layout, drawn again in the preview, and sent with the download.
  let template = root.dataset.template!
  const templateSelect = root.querySelector<HTMLSelectElement>("#template-select")!
  templateSelect.addEventListener("change", () => {
    template = templateSelect.value
    preview.setTemplate(template)
  })

  // Another currency: the money of the form, the preview and the PDF is written in it. The server says what the
  // region is (and the words the layout prints); the values typed so far stay.
  async function changeCurrency(code: string) {
    const params = new URLSearchParams({ locale, country: region.country, currency: code })
    const response = await fetch(`/api/bill/${schema.slug}/view?${params}`).catch(() => null)
    if (!response?.ok) return
    const view = await response.json()
    const data = ui.read()
    ui.destroy()
    form.replaceChildren()
    schema.fields = view.fields
    region = view.region
    money = makeMoney(region)
    ui = mountForm(data)
    if (business) form.querySelector<HTMLSelectElement>("#business-select")!.value = String(business.id)
    preview.setRegion(JSON.stringify(view.text), JSON.stringify(view.region))
  }

  // The currency chosen in the switch of the site, or the country's own. A document that is being edited keeps its own
  // until the visitor chooses another.
  const ownCurrency = root.dataset.ownCurrency!
  const followChoice = () => {
    const wanted = chosenCurrency() ?? ownCurrency
    if (wanted !== region.currency.code) changeCurrency(wanted)
  }
  window.addEventListener("qs:currency", followChoice)
  if (root.dataset.edit !== "true") followChoice()

  // "Edit and regenerate": the document was made with this business, so it is selected again. Its fields
  // already hold what the document had, so nothing is filled in.
  const earlier = businesses.find((b) => b.id === Number(root.dataset.businessId))
  if (earlier) {
    form.querySelector<HTMLSelectElement>("#business-select")!.value = String(earlier.id)
    useBusiness(earlier)
  }
  // const ui = buildForm(form, schema, sample, (data) => console.log("changed", data))
  // console.log("initial", ui.read())

  function showQuota(q: Quota) {
    badge.textContent = t(q.tier === "anonymous" ? "quota_anonymous" : "quota_user", {
      remaining: q.remaining,
      limit: q.limit,
    })
    loginPrompt.classList.toggle("hidden", !(q.tier === "anonymous" && q.remaining === 0))
  }

  function refreshQuota() {
    fetch("/api/quota")
      .then((r) => r.json())
      .then(showQuota)
      .catch(() => {}) // the badge is a courtesy: if this fails, leave it empty
  }
  refreshQuota()

  button.addEventListener("click", async () => {
    button.disabled = true
    status.textContent = t("creating")
    ui.showErrors({})
    let turnstileToken: string | undefined
    if (turnstile) {
      const widget = await turnstile
      if (!widget) {
        button.disabled = false
        status.textContent = t("verify_failed")
        return
      }
      turnstileToken = await widget.token()
    }
    const result = await downloadPdf(schema.slug, template, ui.read(), turnstileToken, business?.id, locale, {
      country: region.country,
      currency: region.currency.code,
    })
    button.disabled = false

    if (result.ok) {
      status.textContent = t("downloaded")
      refreshQuota()
    } else if (result.status === 422) {
      ui.showErrors(result.errors ?? {})
      status.textContent = t("fix_fields")
    } else if (result.status === 429) {
      status.textContent = t("limit_reached")
      refreshQuota()
    } else {
      // The server's own message is English; the page says it in its language.
      status.textContent = result.status === 403 ? t("verify_failed") : t("error")
    }
  })

  return () => {
    window.removeEventListener("qs:currency", followChoice)
    preview.destroy()
  }
}
