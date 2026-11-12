import { buildForm, type Business, type BillData, type Design, type SaveSeller, type SavedSections, type Schema } from "./form"
import { createPreview } from "./preview"
import { downloadPdf } from "./download"
import { saveSection, saveSeller } from "./saved"
import { createDriverSignaturePicker, createExtraSignaturePickers, createSignaturePicker } from "./signatures"
import { createStampPicker } from "./stamps"
import { createTurnstile } from "../turnstile"
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
  // The signature of the bill: one of the saved ones or none, chosen apart from the business.
  const signature = createSignaturePicker(root, (url) => preview.setSignature(url))
  // The driver's signature, the second one, on a design that has a place for it.
  const driverSignature = createDriverSignaturePicker(root, (url) => preview.setDriverSignature(url))
  // The further signatures (prepared, checked, approved...), one select each, on a design that has places for them.
  const extraSignatures = createExtraSignaturePickers(root, (slot, url) => preview.setExtraSignature(slot, url))
  // The revenue stamp of the bill: the empty box, the default stamp of the site, or a saved one.
  const stamp = createStampPicker(root, (url) => preview.setStamp(url))
  // The saved business the user picked, if any: its logo goes on the preview and the PDF, and its default signature
  // is chosen for the bill (the visitor can choose another).
  let business: Business | null = null
  function useBusiness(picked: Business | null) {
    const changed = picked?.id !== business?.id
    business = picked
    preview.setBusiness(picked)
    if (changed && picked?.signature_id) signature.use(picked.signature_id)
  }

  // Saves the seller details of the form as a business of the user (the sentences are in the language of the page).
  const saveSellerDetails: SaveSeller | null =
    root.dataset.signedIn === "true"
      ? async (details, id) => {
          if (!details.name) return { error: t("seller_error_name_blank") }
          const result = await saveSeller(details, region.country, id)
          if (!result.ok) {
            if (result.code === "name_taken") return { error: t("saved_error_name_taken") }
            if (result.code === "tax_id_invalid") return { error: t("seller_error_tax_id_invalid", { label: region.tax?.id?.label ?? "" }) }
            return { error: result.code === "name_blank" ? t("seller_error_name_blank") : t("error") }
          }
          const at = businesses.findIndex((b) => b.id === result.business.id)
          if (at >= 0) businesses[at] = result.business
          else businesses.push(result.business)
          businesses.sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: "base" }))
          return { business: result.business, message: t(result.created ? "seller_created" : "seller_updated") }
        }
      : null
  // The country and the currency are chosen in the switch of the site (language, country and currency:
  // `UI.locale_dialog/1`), for every page. The country is the page's; the currency is the visitor's choice, or the
  // country's own (see `followChoice` below).

  // The employees or drivers a user keeps for this bill, and how to save the ones typed in a section.
  const savedSections: SavedSections = {
    entries: JSON.parse(root.dataset.savedEntries ?? "{}"),
    save:
      root.dataset.signedIn === "true"
        ? async (group, data, id) => {
            const result = await saveSection(schema.slug, group, data, id)
            if (!result.ok) {
              if (result.code === "limit_reached") return { error: t("saved_error_limit_reached") }
              if (result.code === "name_taken") return { error: t("saved_error_name_taken") }
              return { error: result.code === "name_blank" ? t("saved_error_name_blank") : t("error") }
            }
            return { entry: result.entry, message: t(result.created ? "saved_created" : "saved_updated") }
          }
        : null,
  }

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
      saveSellerDetails,
      savedSections,
    )
    return built
  }
  let ui = mountForm(sample)

  // The design of the bill: its own layout, drawn again in the preview, and sent with the download.
  let template = root.dataset.template!
  const designPicker = root.querySelector<HTMLElement>("#design-picker")!
  const paperSelect = root.querySelector<HTMLSelectElement>("#paper-select")!
  const marginSelect = root.querySelector<HTMLSelectElement>("#margin-select")!
  const paperThermal = root.querySelector<HTMLElement>("#paper-thermal")!
  // A design made for a thermal roll has no paper to choose; the others do.
  const showPaper = (design: Design | undefined) => {
    const roll = design?.thermal === true
    paperSelect.classList.toggle("hidden", roll)
    marginSelect.classList.toggle("hidden", roll)
    paperThermal.classList.toggle("hidden", !roll)
  }
  designPicker.addEventListener("change", (event) => {
    template = (event.target as HTMLInputElement).value
    const design = schema.templates?.find((d) => d.id === template)
    preview.setTemplate(template)
    signature.showFor(design)
    driverSignature.showFor(design)
    for (const picker of Object.values(extraSignatures)) picker.showFor(design)
    stamp.showFor(design, region.country)
    showPaper(design)
  })
  paperSelect.addEventListener("change", () => preview.setPaper(paperSelect.value))
  marginSelect.addEventListener("change", () => preview.setMargin(marginSelect.value))
  // "Edit and regenerate": the margins the document was made with.
  if (root.dataset.margin) {
    marginSelect.value = root.dataset.margin
    preview.setMargin(root.dataset.margin)
  }
  // "Edit and regenerate": the sheet the document was made on.
  if (root.dataset.paper) preview.setPaper(root.dataset.paper)

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
    if (business) ui.chooseBusiness(business.id)
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
    ui.chooseBusiness(earlier.id)
    useBusiness(earlier)
  }
  // ... and with the signature it had (or none), which is not always the default of its business.
  if (root.dataset.edit === "true") {
    signature.use(root.dataset.signatureId ? Number(root.dataset.signatureId) : null)
    driverSignature.use(root.dataset.driverSignatureId ? Number(root.dataset.driverSignatureId) : null)
    const earlierExtras: Record<string, number> = JSON.parse(root.dataset.extraSignatureIds ?? "{}")
    for (const [slot, picker] of Object.entries(extraSignatures)) picker.use(earlierExtras[slot] ?? null)
  }
  // ... and with the revenue stamp it had.
  if (root.dataset.edit === "true") stamp.use(root.dataset.stampChoice ?? "")
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

  // The saved signatures chosen for the further places to sign of the design that is chosen.
  const chosenExtras = (id: string) => {
    const design = schema.templates?.find((d) => d.id === id)
    const ids: Record<string, number> = {}
    for (const [slot, picker] of Object.entries(extraSignatures)) {
      if (design?.extra_signatures?.includes(slot) && picker.id !== null) ids[slot] = picker.id
    }
    return ids
  }

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
    }, signature.id, stamp.choice, paperSelect.value, marginSelect.value, driverSignature.id, chosenExtras(template))
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
