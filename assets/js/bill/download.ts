import type { BillData } from "./form"

export type DownloadResult =
  | { ok: true }
  | { ok: false; status: number; errors?: Record<string, string[]>; message?: string }

export async function downloadPdf(
  slug: string,
  template: string,
  data: BillData,
  turnstileToken?: string,
  businessId?: number | null,
  locale?: string,
): Promise<DownloadResult> {
  const csrf = document.querySelector<HTMLMetaElement>("meta[name='csrf-token']")?.content ?? ""

  const response = await fetch("/api/generate", {
    method: "POST",
    headers: { "content-type": "application/json", "x-csrf-token": csrf },
    body: JSON.stringify({ slug, template, data, locale, turnstile_token: turnstileToken, business_id: businessId }),
  })

  if (!response.ok) {
    const body = await response.json().catch(() => ({}))
    return { ok: false, status: response.status, errors: body.errors, message: body.error }
  }

  const blob = await response.blob()
  const url = URL.createObjectURL(blob)
  const link = document.createElement("a")
  link.href = url
  link.download = `${slug}.pdf`
  document.body.append(link)
  link.click()
  link.remove()
  URL.revokeObjectURL(url)
  return { ok: true }
}
