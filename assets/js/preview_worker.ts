import { $typst, loadFonts } from "@myriaddreamin/typst.ts"

// `images` are the logo and signature of the chosen business, by the name the template uses ("logo.png").
// `text` and `region` are the contents of text.json and region.json, which every template reads.
type Job = {
  id: number
  source: string
  helpers: string
  data: unknown
  images: Record<string, Uint8Array>
  text: string
  region: string
}

// Tell typst.ts where to fetch its two WASM modules from (our own server), and which fonts to draw with:
// the two the server draws the PDF with (they cover Latin, Spanish accents and Devanagari), and nothing else,
// so the preview looks like the PDF. `assets: false` keeps typst.ts from fetching its own fonts from a CDN.
$typst.setCompilerInitOptions({
  beforeBuild: [loadFonts(["/fonts/NotoSans-Regular.ttf", "/fonts/NotoSans-Bold.ttf"], { assets: false })],
  getModule: () => "/wasm/typst_ts_web_compiler_bg.wasm",
})
$typst.setRendererInitOptions({
  getModule: () => "/wasm/typst_ts_renderer_bg.wasm",
})

self.onmessage = async (event: MessageEvent<Job>) => {
  const { id, source, helpers, data, images, text, region } = event.data
  try {
    // Same layout as on the server: main.typ with data.json, text.json and region.json next to it.
    const encode = (value: string) => new TextEncoder().encode(value)
    await $typst.mapShadow("/data.json", encode(JSON.stringify(data)))
    await $typst.mapShadow("/text.json", encode(text))
    await $typst.mapShadow("/region.json", encode(region))
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
