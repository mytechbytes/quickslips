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
  // The country and currency the document is made for (the site switch).
  region?: { country: string; currency: string },
  // The saved signature to draw (none: the place to sign by hand).
  signatureId?: number | null,
  // The revenue stamp: "system:<name>", the id of a saved one (as text), or "" for the empty box.
  stamp?: string,
): Promise<DownloadResult> {
  const csrf = document.querySelector<HTMLMetaElement>("meta[name='csrf-token']")?.content ?? ""

  const response = await fetch("/api/generate", {
    method: "POST",
    headers: { "content-type": "application/json", "x-csrf-token": csrf },
    body: JSON.stringify({ slug, template, data,
      locale,
      country: region?.country,
      currency: region?.currency,
      turnstile_token: turnstileToken,
      business_id: businessId,
      signature_id: signatureId,
      stamp,
    }),
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
