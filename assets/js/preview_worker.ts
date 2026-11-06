import { $typst } from "@myriaddreamin/typst.ts"

// `images` are the logo and signature of the chosen business, by the name the template uses ("logo.png").
type Job = {
  id: number
  source: string
  helpers: string
  data: unknown
  images: Record<string, Uint8Array>
}

// Tell typst.ts where to fetch its two WASM modules from (our own server).
$typst.setCompilerInitOptions({
  getModule: () => "/wasm/typst_ts_web_compiler_bg.wasm",
})
$typst.setRendererInitOptions({
  getModule: () => "/wasm/typst_ts_renderer_bg.wasm",
})

self.onmessage = async (event: MessageEvent<Job>) => {
  const { id, source, helpers, data, images } = event.data
  try {
    // Same layout as on the server: main.typ with data.json next to it.
    await $typst.mapShadow("/data.json", new TextEncoder().encode(JSON.stringify(data)))
    // The pictures sit next to main.typ too, as on the server. A picture that is no longer wanted can
    // stay mapped: the template only draws what `data` names.
    for (const [name, bytes] of Object.entries(images)) await $typst.mapShadow(`/${name}`, bytes)
    await $typst.addSource("/_shared/helpers.typ", helpers)
    await $typst.addSource("/main.typ", source)
    const svg = await $typst.svg({ mainFilePath: "/main.typ", inputs: { mode: "preview" } })
    self.postMessage({ id, svg })
  } catch (error) {
    self.postMessage({ id, error: String(error) })
  }
}
