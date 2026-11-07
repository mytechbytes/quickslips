import type { Business } from "./form"

// What a logged-in user can save from a bill's page without leaving it: a signature and the seller details.

export type Signature = { id: number; name: string; url: string }

/** A save that did not happen: the `code` the server gave (`name_taken`, `tax_id_invalid`), or `null` when there is none (offline). */
export type Refused = { ok: false; code: string | null }

const csrfToken = () => document.querySelector<HTMLMetaElement>("meta[name='csrf-token']")?.content ?? ""

async function post(url: string, body: BodyInit, headers: Record<string, string> = {}) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "x-csrf-token": csrfToken(), accept: "application/json", ...headers },
    body,
  }).catch(() => null)
  if (!response) return { ok: false as const, code: null }

  const data = await response.json().catch(() => ({}))
  return response.ok ? { ok: true as const, data } : { ok: false as const, code: (data.code as string | undefined) ?? null }
}

/** Saves the picture as a signature called `name`. */
export async function saveSignature(name: string, file: File): Promise<{ ok: true; signature: Signature } | Refused> {
  const body = new FormData()
  body.set("name", name)
  body.set("file", file)
  // No content type: the browser writes it, with the boundary of the form data.
  const result = await post("/api/signatures", body)
  return result.ok ? { ok: true, signature: result.data.signature as Signature } : result
}

export type SellerDetails = { name: string; address: string; gstin: string }

/** Saves the seller details of the form for the country of the bill: a name that is already saved is updated. */
export async function saveSeller(
  details: SellerDetails,
  country: string,
): Promise<{ ok: true; business: Business; created: boolean } | Refused> {
  const result = await post("/api/businesses", JSON.stringify({ ...details, country }), { "content-type": "application/json" })
  return result.ok
    ? { ok: true, business: result.data.business as Business, created: result.data.outcome === "created" }
    : result
}
