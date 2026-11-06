import { buildForm, type Business, type BillData, type Schema } from "./form"
import { createPreview } from "./preview"
import { downloadPdf } from "./download"
import { createTurnstile } from "./turnstile"
import { loadStrings, t } from "./i18n"

type Quota = { remaining: number; limit: number; tier: string }

function init() {
  const root = document.getElementById("bill-app")
  if (!root) return // not on a template page

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
  // The language and country of the page ("hi-in"), and the sign of its currency for the labels.
  const locale = root.dataset.locale!
  const currencySign: string = JSON.parse(root.dataset.region!).currency.symbol
  const preview = createPreview({
    workerUrl: root.dataset.worker!,
    slug: schema.slug,
    template: root.dataset.template!,
    container: root.querySelector<HTMLElement>("#bill-preview")!,
    status: root.querySelector<HTMLElement>("#bill-status")!,
    text: root.dataset.text!,
    region: root.dataset.region!,
  })
  preview.renderNow(sample)
  // The saved business the user picked, if any: its logo and signature go on the preview and the PDF.
  let business: Business | null = null
  function useBusiness(picked: Business | null) {
    business = picked
    preview.setBusiness(picked)
  }
  const ui = buildForm(form, schema, sample, (data) => preview.schedule(data), businesses, useBusiness, currencySign)

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
    const result = await downloadPdf(schema.slug, root.dataset.template!, ui.read(), turnstileToken, business?.id, locale)
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
}

document.addEventListener("DOMContentLoaded", init)
